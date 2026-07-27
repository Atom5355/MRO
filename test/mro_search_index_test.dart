import 'package:flutter_test/flutter_test.dart';
import 'package:mro_engine/models/mro_part.dart';
import 'package:mro_engine/services/mro_search_index.dart';

void main() {
  group('MroSearchIndex', () {
    test('maps normalized identifiers to every matching row', () {
      final first = MroPart(
        itemName: 'W100001',
        legacyCode: 'LEG-1.2',
      );
      final second = MroPart(
        itemName: 'W100002',
        legacyCode: 'LEG-1.2',
      );
      final index = MroSearchIndex.build([first, second]);

      expect(index.exactIdentifierMatches('leg 12'), [first, second]);
      expect(index.exactIdentifierMatches('W-100001'), [first]);
    });

    test('derives a case-preserving manufacturer vocabulary', () {
      final index = MroSearchIndex.build([
        MroPart(itemName: 'W1', manufacturer: 'SICK'),
        MroPart(itemName: 'W2', manufacturer: '3M'),
        MroPart(itemName: 'W3', manufacturer: 'sick'),
      ]);

      expect(index.manufacturerVocabulary, containsAll(['3M', 'SICK']));
      expect(index.manufacturerVocabulary, hasLength(2));
      expect(index.normalizedManufacturers.keys, containsAll(['3m', 'sick']));
    });

    test('caches normalized fields and dimensions', () {
      final part = MroPart(
        itemName: 'W1',
        description: 'PILLOW BEARING 1-7/16 IN BORE',
      );
      final entry = MroSearchIndex.build([part]).entryFor(part);

      expect(entry.tokens, containsAll(['pillow', 'bearing', 'bore']));
      expect(entry.numbers, contains(closeTo(1.4375, 0.0001)));
    });
  });
}
