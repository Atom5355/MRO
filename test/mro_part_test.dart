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

  group('MroPart identity', () {
    test('uses the W/item number as stable identity', () {
      final part = MroPart(
        itemName: ' W100001 ',
        legacyCode: 'LEGACY-DUP',
        manufacturerPartNumber: 'MPN-A',
        supplierPartNumber: 'SUP-7',
      );

      expect(part.stableId, 'W100001');
      expect(part.partId, 'W100001');
      expect(
        part.searchIdentifiers,
        containsAll(['W100001', 'LEGACY-DUP', 'MPN-A', 'SUP-7']),
      );
      expect(
        part.persistenceAliases,
        containsAll(['W100001', 'W100001_MPN-A']),
      );
      expect(part.persistenceAliases, isNot(contains('LEGACY-DUP')));
    });

    test('duplicate legacy aliases do not merge stable identities', () {
      final first = MroPart(itemName: 'W100001', legacyCode: 'LEGACY-DUP');
      final second = MroPart(itemName: 'W100002', legacyCode: 'LEGACY-DUP');

      expect(first.stableId, isNot(second.stableId));
      expect(first.normalizedPartIdentifiers, contains('legacydup'));
      expect(second.normalizedPartIdentifiers, contains('legacydup'));
    });

    test('creates a deterministic composite fallback without an item number',
        () {
      final first = MroPart(
        location: 'A-1',
        legacyCode: 'LEG-9',
        manufacturerPartNumber: 'MPN-9',
      );
      final second = MroPart(
        location: 'A-1',
        legacyCode: 'LEG-9',
        manufacturerPartNumber: 'MPN-9',
      );

      expect(first.stableId, startsWith('mro:'));
      expect(first.stableId, second.stableId);
    });
  });
}
