import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class MovementScreen extends StatefulWidget {
  const MovementScreen({super.key});

  @override
  State<MovementScreen> createState() => _MovementScreenState();
}

class _MovementScreenState extends State<MovementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  List<StockLevel> _levels = [];
  List<Party> _parties = [];
  bool _isLoading = true;

  MovementType _type = MovementType.stockOut;
  int? _productId;
  int? _partyId;
  DateTime _date = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    final levels = await DatabaseHelper.instance.getStockLevels();
    final parties = await DatabaseHelper.instance.getParties();
    if (!mounted) return;
    setState(() {
      _levels = levels;
      _parties = parties;
      _isLoading = false;
    });
  }

  StockLevel? get _selectedLevel =>
      _levels.where((l) => l.product.id == _productId).firstOrNull;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final level = _selectedLevel!;
    final quantity = int.parse(_quantityController.text.trim());

    // Don't allow sending out more than is on the shelf
    if (_type == MovementType.stockOut && quantity > level.onHand) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Only ${level.onHand} of ${level.product.name} in stock'),
        ),
      );
      return;
    }

    await DatabaseHelper.instance.insertMovement(
      StockMovement(
        productId: level.product.id!,
        partyId: _type == MovementType.stockOut ? _partyId : null,
        type: _type,
        quantity: quantity,
        date: _date,
        note: _noteController.text.trim(),
      ),
    );

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isOut = _type == MovementType.stockOut;
    final level = _selectedLevel;

    return Scaffold(
      appBar: AppBar(title: const Text('Stock in / out')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _levels.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Add a product first (add-box icon on the stock screen).',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        SegmentedButton<MovementType>(
                          segments: const [
                            ButtonSegment(
                              value: MovementType.stockOut,
                              label: Text('Stock out'),
                              icon: Icon(Icons.arrow_upward),
                            ),
                            ButtonSegment(
                              value: MovementType.stockIn,
                              label: Text('Stock in'),
                              icon: Icon(Icons.arrow_downward),
                            ),
                          ],
                          selected: {_type},
                          onSelectionChanged: (selection) =>
                              setState(() => _type = selection.first),
                        ),
                        const SizedBox(height: 20),

                        DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Product',
                            border: OutlineInputBorder(),
                          ),
                          initialValue: _productId,
                          items: _levels
                              .map((l) => DropdownMenuItem(
                                    value: l.product.id,
                                    child: Text(l.product.name),
                                  ))
                              .toList(),
                          onChanged: (value) => setState(() => _productId = value),
                          validator: (value) =>
                              value == null ? 'Choose a product' : null,
                        ),
                        if (level != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text('In stock now: ${level.onHand}'),
                          ),
                        const SizedBox(height: 20),

                        if (isOut) ...[
                          DropdownButtonFormField<int>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Given to',
                              border: OutlineInputBorder(),
                            ),
                            initialValue: _partyId,
                            items: _parties
                                .map((p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(
                                        '${p.name} (${p.kind == PartyKind.rep ? 'Rep' : 'Wholesaler'})',
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) => setState(() => _partyId = value),
                            validator: (value) =>
                                value == null ? 'Choose who received it' : null,
                          ),
                          if (_parties.isEmpty)
                            const Padding(
                              padding: EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                'No reps or wholesalers yet. Add one with the people icon on the stock screen.',
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],

                        TextFormField(
                          controller: _quantityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Quantity',
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            final n = int.tryParse((value ?? '').trim());
                            if (n == null || n <= 0) return 'Enter a whole number above 0';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('Date: ${_date.day}/${_date.month}/${_date.year}'),
                          trailing: const Icon(Icons.calendar_today),
                          onTap: _pickDate,
                        ),
                        const SizedBox(height: 20),

                        TextFormField(
                          controller: _noteController,
                          decoration: const InputDecoration(
                            labelText: 'Note (optional)',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 30),

                        ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.all(16),
                          ),
                          child: Text(isOut ? 'Record Stock Out' : 'Record Stock In'),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}