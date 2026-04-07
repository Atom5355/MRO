import 'package:flutter_test/flutter_test.dart';
import 'package:mro_engine/services/mro_data_service.dart';

void main() {
  group('MroDataService.parsePartRow', () {
    test('uses Item Description as the card description', () {
      final part = MroDataService.parsePartRow({
        'Location': 'A-01',
        'Legacy Code': 'LG-100',
        'Item Name': 'Drive Roller',
        'Item Description': 'Primary card description',
        'Item Description 2': 'Continuation text that should stay hidden',
        'Manufacturer': 'OEM',
        'Category': 'Conveyors',
      });

      expect(part.description, 'Primary card description');
      expect(part.additionalFields.containsKey('Item Description'), isFalse);
      expect(part.additionalFields.containsKey('Item Description 2'), isFalse);
      expect(part.additionalFields['Category'], 'Conveyors');
    });

    test('falls back to Description for older workbooks', () {
      final part = MroDataService.parsePartRow({
        'Item Name': 'Legacy Part',
        'Description': 'Legacy workbook description',
      });

      expect(part.description, 'Legacy workbook description');
    });
  });
}