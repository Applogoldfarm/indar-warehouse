import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class ProductFormScreen extends StatefulWidget {
  // When a product is passed in, the form opens in edit mode
  final Product? existing;

  const ProductFormScreen({super.key, this.existing});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _skuController;
  late final TextEditingController _openingController;
  late final TextEditingController _reorderController;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final p = widget.existing;
    _nameController = TextEditingController(text: p?.name ?? '');
    _skuController = TextEditingController(text: p?.sku ?? '');
    _openingController = TextEditingController(text: '${p?.openingStock ?? 0}');
    _reorderController = TextEditingController(text: '${p?.reorderLevel ?? 20}');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _openingController.dispose();
    _reorderController.dispose();
    super.dispose();
  }

  String? _validateWholeNumber(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter a number';
    final n = int.tryParse(value.trim());
    if (n == null || n < 0) return 'Enter a whole number, 0 or more';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final product = Product(
      id: widget.existing?.id,
      name: _nameController.text.trim(),
      sku: _skuController.text.trim(),
      openingStock: int.parse(_openingController.text.trim()),
      reorderLevel: int.parse(_reorderController.text.trim()),
    );

    if (_isEditing) {
      await DatabaseHelper.instance.updateProduct(product);
    } else {
      await DatabaseHelper.instance.insertProduct(product);
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Product' : 'Add Product')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Product name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _skuController,
                decoration: const InputDecoration(
                  labelText: 'SKU / code (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _openingController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Opening stock',
                  helperText: 'Units on the shelf before you started recording here',
                  border: OutlineInputBorder(),
                ),
                validator: _validateWholeNumber,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _reorderController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Reorder level',
                  helperText: 'Shows REORDER when stock is at or below this',
                  border: OutlineInputBorder(),
                ),
                validator: _validateWholeNumber,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
                child: Text(_isEditing ? 'Update Product' : 'Save Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}