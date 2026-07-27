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

    for (final alias in MroDataService.legacyColumnAliases) {
      test('recognizes $alias and excludes it from additional fields', () {
        final part = MroDataService.parsePartRow({
          'Item Name': 'W100100',
          alias: 'LEG-42',
        });

        expect(part.legacyCode, 'LEG-42');
        expect(part.additionalFields.containsKey(alias), isFalse);
      });
    }
  });

  group('MroDataService.validateHeaders', () {
    test('accepts every supported legacy header alias', () {
      for (final alias in MroDataService.legacyColumnAliases) {
        expect(
          () => MroDataService.validateHeaders(['Item Name', alias]),
          returnsNormally,
        );
      }
    });

    test('reports a clear schema error for a missing item identifier', () {
      expect(
        () => MroDataService.validateHeaders(['Legacy #', 'Description']),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('Item Name'),
          ),
        ),
      );
    });

    test('reports every accepted alias when the legacy header is missing', () {
      expect(
        () => MroDataService.validateHeaders(['Item Name', 'Description']),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            allOf(contains('Legacy #'), contains('Legacy Part Number')),
          ),
        ),
      );
    });
  });
}
