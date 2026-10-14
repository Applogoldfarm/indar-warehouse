import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<StockMovement> _movements = [];
  bool _isLoading = true;

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 0, 23, 59, 59);
    final data = await DatabaseHelper.instance.getMovementsBetween(start, end);
    if (!mounted) return;
    setState(() {
      _movements = data;
      _isLoading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _delete(StockMovement movement) async {
    // Deleting a stock-in takes units off the shelf, so make sure
    // that can't push the product's stock below zero
    if (movement.type == MovementType.stockIn) {
      final levels = await DatabaseHelper.instance.getStockLevels();
      final level =
          levels.where((l) => l.product.id == movement.productId).firstOrNull;
      if (level != null && level.onHand - movement.quantity < 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Can't delete: ${movement.productName} would drop below 0 in stock",
            ),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete this entry?'),
        content: Text(
          '${movement.type == MovementType.stockIn ? 'Stock in' : 'Stock out'}: '
          '${movement.quantity} x ${movement.productName}\n\nThis cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await DatabaseHelper.instance.deleteMovement(movement.id!);
    _load();
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_monthNames[_month.month - 1]} ${_month.year}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _movements.isEmpty
                    ? const Center(child: Text('No entries this month.'))
                    : ListView.separated(
                        itemCount: _movements.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final m = _movements[index];
                          final isIn = m.type == MovementType.stockIn;
                          final who = isIn ? 'Restock' : (m.partyName ?? 'Unknown');
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: isIn ? Colors.green : Colors.red,
                              child: Icon(
                                isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(m.productName ?? 'Unknown product'),
                            subtitle: Text(
                              '${_formatDate(m.date)} • $who'
                              '${m.note.isNotEmpty ? ' • ${m.note}' : ''}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${isIn ? '+' : '-'}${m.quantity}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isIn ? Colors.green : Colors.red,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: 'Delete',
                                  onPressed: () => _delete(m),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}