import '../db/database_helper.dart';
import '../models/models.dart';

// Names taken from INDAR_INTERNATIONAL_WAREHOUSE.xlsx
const List<(String, String)> _starterProducts = [
  ('SKU-01', 'FRESHGLOW B/S'),
  ('SKU-02', 'TURA B/S'),
  ('SKU-03', 'TURA S/S'),
  ('SKU-04', 'GOODKNIGHT B/S'),
  ('SKU-05', 'GOODKNIGHT S/S'),
  ('SKU-06', 'MEGAGROWTH RELAXER'),
  ('SKU-07', 'POWERSHOT'),
  ('SKU-08', 'AER POWER POCKET'),
  ('SKU-09', 'EASYVIBES'),
  ('SKU-10', 'TCB RELAXER'),
  ('SKU-11', 'TCB INDIAN HERBS'),
  ('SKU-12', 'TCB ANTIDANDRUFF'),
  ('SKU-13', 'MG KIDS'),
  ('SKU-14', 'POWER ACTIVE'),
  ('SKU-15', 'POWER STICK'),
  ('SKU-16', 'NATURAL TWIST'),
  ('SKU-17', 'MG HAIRSUPERFOOD ANTIDANDRUFF'),
  ('SKU-18', 'MG HAIRSUPERFOOD INDIAN HERBS'),
  ('SKU-19', 'DSS PROMO'),
  ('SKU-20', 'LEAVEIN CUP'),
  ('SKU-21', 'LEAVEIN SATCHET'),
  ('SKU-22', 'DARLING EASY BRAID'),
];

const List<String> _starterReps = [
  'AYODEJI SHOBOWALE',
  'DIVINE ADENIYI',
  'JOHN RAJI',
  'KEHINDE LEWU',
  'LOVETH ABUMUTAIRE',
  'MAYOWA ADEBAYO',
  'REBECCA OGUNDE',
];

const List<String> _starterWholesalers = [
  'ALABAMA',
  'ALHAJA',
  'APF',
  'CHIKASON',
  'CHIKASON MADAM',
  'ERNEST',
  'HAIR BEAUTY',
  'HAMAS',
  'HIMRA',
  'IYA BASIT',
  'IYA IBEJI',
  'IYA IKE',
  'IYA SODIRAT',
  "KINGS' POWER",
  'MANUS',
  'MUITU',
  'O BABY',
  'OGA COMPANY',
  'OMIDA',
  'ONYEKA',
  'OYINBO',
  'PRECIOUS PHARMACY',
  'PROMISE',
  'SEUN ARA',
  'SHALOM',
  'SMART EAGLE',
  'UNITY',
];

class ImportService {
  // Adds the starter list. Anything whose name already exists is skipped,
  // so running it twice never creates duplicates.
  static Future<String> importStarterList() async {
    final db = DatabaseHelper.instance;

    final productNames = (await db.getStockLevels())
        .map((l) => l.product.name.toLowerCase())
        .toSet();
    final partyNames =
        (await db.getParties()).map((p) => p.name.toLowerCase()).toSet();

    var products = 0, reps = 0, wholesalers = 0;

    for (final (sku, name) in _starterProducts) {
      if (productNames.contains(name.toLowerCase())) continue;
      await db.insertProduct(Product(name: name, sku: sku));
      products++;
    }

    for (final name in _starterReps) {
      if (partyNames.contains(name.toLowerCase())) continue;
      await db.insertParty(Party(name: name, kind: PartyKind.rep));
      reps++;
    }

    for (final name in _starterWholesalers) {
      if (partyNames.contains(name.toLowerCase())) continue;
      await db.insertParty(Party(name: name, kind: PartyKind.wholesaler));
      wholesalers++;
    }

    return 'Added $products products, $reps reps and $wholesalers wholesalers';
  }
}