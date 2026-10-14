import 'package:flutter/material.dart';
import '../db/database_helper.dart';
import '../models/models.dart';
import '../services/import_service.dart';
import 'history_screen.dart';
import 'movement_screen.dart';
import 'parties_screen.dart';
import 'product_form_screen.dart';
import 'summary_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<StockLevel> _levels = [];
  bool _isLoading = true;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await DatabaseHelper.instance.getStockLevels();
    if (!mounted) return;
    setState(() {
      _levels = data;
      _isLoading = false;
    });
  }

  // Opens a screen, then refreshes the stock list when you come back
  Future<void> _open(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    _load();
  }

  Future<void> _importStarterList() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import starter list?'),
        content: const Text(
          'Adds the 22 products, 7 sales reps and 27 wholesalers from your '
          'Excel file, with opening stock 0. Names already in the app are skipped.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final message = await ImportService.importStarterList();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _load();
  }

  List<StockLevel> get _visible {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return _levels;
    return _levels
        .where((l) =>
            l.product.name.toLowerCase().contains(q) ||
            l.product.sku.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final reorderCount = _levels.where((l) => l.needsReorder).length;
    final visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Warehouse'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Monthly summary',
            onPressed: () => _open(const SummaryScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => _open(const HistoryScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.people_alt_outlined),
            tooltip: 'Sales reps & wholesalers',
            onPressed: () => _open(const PartiesScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'Add product',
            onPressed: () => _open(const ProductFormScreen()),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'import') _importStarterList();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'import', child: Text('Import starter list')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search products',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) => setState(() => _search = value),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_levels.length} products'),
                      Text(
                        '$reorderCount need reorder',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: reorderCount > 0 ? Colors.red : Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _levels.isEmpty
                                  ? 'No products yet. Tap the add-box icon at the top to add your first product.'
                                  : 'No product matches your search.',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 90),
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final level = visible[index];
                            final product = level.product;
                            return ListTile(
                              onTap: () => _open(ProductFormScreen(existing: product)),
                              title: Text(product.name),
                              subtitle: Text(
                                product.sku.isEmpty
                                    ? 'Reorder at ${product.reorderLevel}'
                                    : '${product.sku} • Reorder at ${product.reorderLevel}',
                              ),
                              trailing: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${level.onHand}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: level.needsReorder ? Colors.red : null,
                                    ),
                                  ),
                                  if (level.needsReorder)
                                    const Text(
                                      'REORDER',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const MovementScreen()),
        icon: const Icon(Icons.swap_vert),
        label: const Text('Stock in / out'),
      ),
    );
  }
}