import 'package:flutter_test/flutter_test.dart';
import 'package:shop_quick/modules/receipt_upload/model/ParsedReceiptItemModel.dart';
import 'package:shop_quick/modules/receipt_upload/model/ParsedReceiptModel.dart';
import 'package:shop_quick/services/ReceiptParserService.dart';

void main() {
  group('ReceiptParserService', () {
    const ReceiptParserService service = ReceiptParserService();

    test('UT22 Clean raw receipt text correctly', () {
      const String rawText =
          '  Tesco  \r\n\tMilk\t2.50\r\n\r\nBread   £1.20  \r\n  ';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(
        result.rawText,
        'Tesco\nMilk 2.50\nBread 1.20',
      );
    });

    test('UT23 Extract store name from valid header line', () {
      const String rawText = '''
TESCO EXTRA
DATE 12/04/2026
MILK 2.50
TOTAL 2.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.storeName, 'TESCO EXTRA');
    });

    test('UT24 Ignore metadata lines when extracting store name', () {
      const String rawText = '''
DATE 12/04/2026
TIME 14:22
RECEIPT 12345
CARD PAYMENT
ALDI
MILK 2.50
TOTAL 2.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.storeName, 'ALDI');
    });

    test('UT25 Ignore address-like lines when extracting store name', () {
      const String rawText = '''
1234 HIGH STREET
BD1 1AA
LIDL
MILK 2.50
TOTAL 2.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.storeName, 'LIDL');
    });

    test('UT26 Return null store name when no suitable header exists', () {
      const String rawText = '''
DATE 12/04/2026
TIME 14:22
RECEIPT 12345
CARD PAYMENT
TOTAL 3.00
VAT 0.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.storeName, isNull);
    });

    test('UT27 Extract subtotal from labeled line', () {
      const String rawText = '''
TESCO
MILK 10.00
BREAD 2.50
SUBTOTAL 12.50
TOTAL 12.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.subtotal, 12.50);
    });

    test('UT28 Extract tax from labeled line', () {
      const String rawText = '''
TESCO
ITEM 10.00
VAT 1.20
TOTAL 11.20
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.tax, 1.20);
    });

    test('UT29 Extract total from labeled line', () {
      const String rawText = '''
TESCO
MILK 12.00
TOTAL 13.70
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.total, 13.70);
    });

    test('UT30 Extract labeled amount from next line when value is not on same line', () {
      const String rawText = '''
TESCO
MILK 5.00
TOTAL
13.70
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.total, 13.70);
    });

    test('UT31 Prevent subtotal from being treated as total', () {
      const String rawText = '''
TESCO
MILK 10.00
SUBTOTAL 12.50
TOTAL 13.70
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.subtotal, 12.50);
      expect(result.total, 13.70);
    });

    test('UT32 Extract inline item and price from same line', () {
      const String rawText = '''
TESCO
Milk 2.50
TOTAL 2.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.items, hasLength(1));
      expect(result.items.first.itemName, 'Milk');
      expect(result.items.first.price, 2.50);
    });

    test('UT33 Pair item line with separate price line', () {
      const String rawText = '''
TESCO
Milk
2.50
TOTAL 2.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.items, hasLength(1));
      expect(result.items.first.itemName, 'Milk');
      expect(result.items.first.price, 2.50);
    });

    test('UT34 Ignore totals lines during item extraction', () {
      const String rawText = '''
TESCO
TOTAL 15.00
SUBTOTAL 12.50
VAT 2.50
AMOUNT DUE 15.00
Milk 2.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.items, hasLength(1));
      expect(result.items.first.itemName, 'Milk');
      expect(result.items.first.price, 2.50);
    });

    test('UT35 Ignore metadata lines during item extraction', () {
      const String rawText = '''
TESCO
DATE 12/04/2026
TIME 14:22
CARD PAYMENT
WELCOME BACK
Milk 2.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.items, hasLength(1));
      expect(result.items.first.itemName, 'Milk');
      expect(result.items.first.price, 2.50);
    });

    test('UT36 Ignore store name line during item extraction', () {
      const String rawText = '''
TESCO
TESCO
Milk 2.50
TOTAL 2.50
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.storeName, 'TESCO');
      expect(result.items, hasLength(1));
      expect(result.items.first.itemName, 'Milk');
    });

    test('UT37 Remove duplicate items with same name and price', () {
      const String rawText = '''
TESCO
Milk 2.50
Milk 2.50
Bread 1.20
TOTAL 6.20
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.items, hasLength(2));
      expect(
        result.items.map((ParsedReceiptItemModel item) => item.itemName).toList(),
        <String>['Milk', 'Bread'],
      );
    });

    test('UT38 Keep different items with same name but different price as separate entries', () {
      const String rawText = '''
TESCO
Milk 2.50
Milk 2.80
TOTAL 5.30
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.items, hasLength(2));
      expect(result.items[0].itemName, 'Milk');
      expect(result.items[0].price, 2.50);
      expect(result.items[1].itemName, 'Milk');
      expect(result.items[1].price, 2.80);
    });

    test('UT39 Parse decimal values with comma separator', () {
      const String rawText = '''
TESCO
Milk 2,50
TOTAL 2,50
VAT 0,20
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.items, hasLength(1));
      expect(result.items.first.price, 2.50);
      expect(result.total, 2.50);
      expect(result.tax, 0.20);
    });

    test('UT40 Return structured result even when receipt contains incomplete data', () {
      const String rawText = '''
TESCO
Milk 2.50
Bread 1.20
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.storeName, 'TESCO');
      expect(result.items, hasLength(2));
      expect(result.subtotal, isNull);
      expect(result.tax, isNull);
      expect(result.total, isNull);
      expect(result.rawText, 'TESCO\nMilk 2.50\nBread 1.20');
    });

    test('UT41 Return empty item list when no valid items exist', () {
      const String rawText = '''
DATE 12/04/2026
TIME 14:22
RECEIPT 12345
CARD PAYMENT
SUBTOTAL 12.50
VAT 1.20
TOTAL 13.70
AMOUNT DUE 13.70
''';

      final ParsedReceiptModel result = service.parse(rawText);

      expect(result.items, isEmpty);
      expect(result.subtotal, 12.50);
      expect(result.tax, 1.20);
      expect(result.total, 13.70);
    });
  });
}
