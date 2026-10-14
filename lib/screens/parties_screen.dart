import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class PartiesScreen extends StatefulWidget {
  const PartiesScreen({super.key});

  @override
  State<PartiesScreen> createState() => _PartiesScreenState();
}

class _PartiesScreenState extends State<PartiesScreen> {
  List<Party> _parties = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getParties();
    if (!mounted) return;
    setState(() {
      _parties = data;
      _isLoading = false;
    });
  }

  // One dialog for both adding a new person and editing an existing one
  Future<void> _showPartyDialog({Party? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    PartyKind kind = existing?.kind ?? PartyKind.rep;

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add sales rep / wholesaler' : 'Edit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<PartyKind>(
                segments: const [
                  ButtonSegment(value: PartyKind.rep, label: Text('Rep')),
                  ButtonSegment(value: PartyKind.wholesaler, label: Text('Wholesaler')),
                ],
                selected: {kind},
                onSelectionChanged: (selection) =>
                    setDialogState(() => kind = selection.first),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    final name = nameController.text.trim();
    if (saved != true || name.isEmpty) return;

    final party = Party(id: existing?.id, name: name, kind: kind);
    if (existing == null) {
      await DatabaseHelper.instance.insertParty(party);
    } else {
      await DatabaseHelper.instance.updateParty(party);
    }
    _load();
  }

  List<Widget> _section(String title, PartyKind kind) {
    final items = _parties.where((p) => p.kind == kind).toList();
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          '$title (${items.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      if (items.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text('None yet'),
        ),
      for (final party in items)
        ListTile(
          title: Text(party.name),
          trailing: const Icon(Icons.edit_outlined, size: 20),
          onTap: () => _showPartyDialog(existing: party),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sales reps & wholesalers')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 90),
              children: [
                ..._section('Sales reps', PartyKind.rep),
                ..._section('Wholesalers', PartyKind.wholesaler),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPartyDialog(),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add'),
      ),
    );
  }
}