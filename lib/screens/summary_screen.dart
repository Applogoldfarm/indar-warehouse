import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../services/export_service.dart';

class _ProductTotal {
  final String name;
  int stockIn = 0;
  int stockOut = 0;

  _ProductTotal(this.name);
}

class _PartyTotal {
  final String name;
  int total = 0;
  final Map<String, int> byProduct = {};

  _PartyTotal(this.name);
}

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({super.key});

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  List<StockMovement> _movements = [];
  Map<int, PartyKind> _partyKinds = {};
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
    final movements =
        await DatabaseHelper.instance.getMovementsBetween(start, end);
    final parties = await DatabaseHelper.instance.getParties();
    if (!mounted) return;
    setState(() {
      _movements = movements;
      _partyKinds = {for (final p in parties) p.id!: p.kind};
      _isLoading = false;
    });
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    _load();
  }

  Future<void> _export(String choice) async {
    if (_movements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No entries this month to export.')),
      );
      return;
    }

    final label = '${_monthNames[_month.month - 1]}_${_month.year}';
    if (choice == 'csv') {
      await ExportService.exportEntriesCsv(_movements, label);
    } else {
      await ExportService.exportSummaryPdf(_movements, _partyKinds, label);
    }
  }

  int get _totalOut => _movements
      .where((m) => m.type == MovementType.stockOut)
      .fold(0, (sum, m) => sum + m.quantity);

  int get _totalIn => _movements
      .where((m) => m.type == MovementType.stockIn)
      .fold(0, (sum, m) => sum + m.quantity);

  // Stock in and stock out per product, biggest stock-out first
  List<_ProductTotal> get _productTotals {
    final map = <int, _ProductTotal>{};
    for (final m in _movements) {
      final total = map.putIfAbsent(
        m.productId,
        () => _ProductTotal(m.productName ?? 'Unknown'),
      );
      if (m.type == MovementType.stockIn) {
        total.stockIn += m.quantity;
      } else {
        total.stockOut += m.quantity;
      }
    }
    final list = map.values.toList();
    list.sort((a, b) => b.stockOut.compareTo(a.stockOut));
    return list;
  }

  // Total stock out per rep (or wholesaler), with a per-product breakdown
  List<_PartyTotal> _partyTotals(PartyKind kind) {
    final map = <int, _PartyTotal>{};
    for (final m in _movements) {
      if (m.type != MovementType.stockOut || m.partyId == null) continue;
      if (_partyKinds[m.partyId] != kind) continue;

      final total = map.putIfAbsent(
        m.partyId!,
        () => _PartyTotal(m.partyName ?? 'Unknown'),
      );
      total.total += m.quantity;
      final product = m.productName ?? 'Unknown';
      total.byProduct[product] = (total.byProduct[product] ?? 0) + m.quantity;
    }
    final list = map.values.toList();
    list.sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  Widget _productsTab() {
    final totals = _productTotals;
    if (totals.isEmpty) {
      return const Center(child: Text('No entries this month.'));
    }
    return ListView.separated(
      itemCount: totals.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final t = totals[index];
        return ListTile(
          title: Text(t.name),
          subtitle: Text('Stock in: ${t.stockIn}'),
          trailing: Text(
            'Out: ${t.stockOut}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
        );
      },
    );
  }

  Widget _partyTab(PartyKind kind) {
    final totals = _partyTotals(kind);
    final label = kind == PartyKind.rep ? 'sales reps' : 'wholesalers';
    if (totals.isEmpty) {
      return Center(child: Text('No stock out to $label this month.'));
    }
    return ListView(
      children: [
        for (final t in totals)
          ExpansionTile(
            title: Text(t.name),
            subtitle: Text('${t.byProduct.length} products'),
            trailing: Text(
              '${t.total}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            children: [
              for (final entry in (t.byProduct.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value))))
                ListTile(
                  dense: true,
                  title: Text(entry.key),
                  trailing: Text(
                    '${entry.value}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Monthly Summary'),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export',
              onSelected: _export,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'csv', child: Text('Entries (CSV)')),
                PopupMenuItem(value: 'pdf', child: Text('Summary (PDF)')),
              ],
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Products'),
              Tab(text: 'Sales reps'),
              Tab(text: 'Wholesalers'),
            ],
          ),
        ),
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
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text('Total out', style: TextStyle(color: Colors.red)),
                      Text(
                        '$_totalOut',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      const Text('Total in', style: TextStyle(color: Colors.green)),
                      Text(
                        '$_totalIn',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _productsTab(),
                        _partyTab(PartyKind.rep),
                        _partyTab(PartyKind.wholesaler),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}