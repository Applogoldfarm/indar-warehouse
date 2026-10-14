import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/models.dart';

class ExportService {
  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // Writes the bytes to a temporary file and opens the phone's share sheet
  static Future<void> _shareFile(String fileName, List<int> bytes, String text) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: text),
    );
  }

  // Every entry of the month, oldest first, one row each
  static Future<void> exportEntriesCsv(
      List<StockMovement> movements, String label) async {
    final sorted = [...movements]
      ..sort((a, b) {
        final byDate = a.date.compareTo(b.date);
        return byDate != 0 ? byDate : (a.id ?? 0).compareTo(b.id ?? 0);
      });

    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Product', 'Given to', 'Quantity', 'Note'],
      for (final m in sorted)
        [
          _fmtDate(m.date),
          m.type == MovementType.stockIn ? 'Stock in' : 'Stock out',
          m.productName ?? '',
          m.type == MovementType.stockOut ? (m.partyName ?? '') : '',
          m.quantity,
          m.note,
        ],
    ];

    await _shareFile(
      'warehouse_entries_$label.csv',
      utf8.encode(csv.encode(rows)),
      'Warehouse entries: $label',
    );
  }

  static int _sum(Map<String, int> values) =>
      values.values.fold(0, (a, b) => a + b);

  // Section for sales reps or wholesalers: each person with their products
  static List<pw.Widget> _partySection(
      String title, Map<String, Map<String, int>> data) {
    if (data.isEmpty) return [];

    final people = data.entries.toList()
      ..sort((a, b) => _sum(b.value).compareTo(_sum(a.value)));

    return [
      pw.SizedBox(height: 16),
      pw.Header(level: 1, text: title),
      for (final person in people) ...[
        pw.SizedBox(height: 8),
        pw.Text(
          '${person.key} - total ${_sum(person.value)}',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Table.fromTextArray(
          headers: ['Product', 'Quantity'],
          data: (person.value.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .map((e) => [e.key, e.value.toString()])
              .toList(),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
      ],
    ];
  }

  // Printable monthly report
  static Future<void> exportSummaryPdf(
    List<StockMovement> movements,
    Map<int, PartyKind> partyKinds,
    String label,
  ) async {
    final productIn = <String, int>{};
    final productOut = <String, int>{};
    final reps = <String, Map<String, int>>{};
    final wholesalers = <String, Map<String, int>>{};
    var totalIn = 0;
    var totalOut = 0;

    for (final m in movements) {
      final product = m.productName ?? 'Unknown';
      if (m.type == MovementType.stockIn) {
        productIn[product] = (productIn[product] ?? 0) + m.quantity;
        totalIn += m.quantity;
      } else {
        productOut[product] = (productOut[product] ?? 0) + m.quantity;
        totalOut += m.quantity;

        final kind = m.partyId == null ? null : partyKinds[m.partyId];
        if (kind != null) {
          final target = kind == PartyKind.rep ? reps : wholesalers;
          final person = target.putIfAbsent(m.partyName ?? 'Unknown', () => {});
          person[product] = (person[product] ?? 0) + m.quantity;
        }
      }
    }

    final productNames = {...productIn.keys, ...productOut.keys}.toList()
      ..sort((a, b) => (productOut[b] ?? 0).compareTo(productOut[a] ?? 0));

    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(level: 0, text: 'Warehouse Summary - $label'),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total stock out: $totalOut'),
              pw.Text('Total stock in: $totalIn'),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, text: 'Products'),
          pw.Table.fromTextArray(
            headers: ['Product', 'Stock in', 'Stock out'],
            data: productNames
                .map((name) => [
                      name,
                      (productIn[name] ?? 0).toString(),
                      (productOut[name] ?? 0).toString(),
                    ])
                .toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          ..._partySection('Sales reps', reps),
          ..._partySection('Wholesalers', wholesalers),
        ],
      ),
    );

    await _shareFile(
      'warehouse_summary_$label.pdf',
      await doc.save(),
      'Warehouse summary: $label',
    );
  }
}