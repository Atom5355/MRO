import 'package:flutter_test/flutter_test.dart';
import 'package:mro_engine/models/mro_part.dart';

void main() {
  group('MroPart.wPartNumber', () {
    test('returns the trimmed item name when it starts with W', () {
      final part = MroPart(itemName: '  W123456  ');

      expect(part.wPartNumber, 'W123456');
    });

    test('uses only the item name column for W part numbers', () {
      final part = MroPart(
        itemName: 'Conveyor Belt',
        manufacturerPartNumber: 'W999999',
        supplierPartNumber: 'W888888',
      );

      expect(part.wPartNumber, isEmpty);
    });

    test('matches lowercase W item names too', () {
      final part = MroPart(itemName: 'w000321');

      expect(part.wPartNumber, 'w000321');
    });
  });
}
