import 'package:flutter_test/flutter_test.dart';
import 'package:mro_engine/models/mro_part.dart';
import 'package:mro_engine/services/advanced_search_service.dart';

void main() {
  final service = AdvancedSearchService();

  final motorPart = MroPart(
    legacyCode: 'MTR-200',
    itemName: 'Baldor Motor',
    description: '2 HP 1750 RPM TEFC electric motor',
    manufacturer: 'Baldor',
    manufacturerPartNumber: 'EM3710T',
  );

  final bearingPart = MroPart(
    legacyCode: 'BRG-11416',
    itemName: 'SKF Pillow Block Bearing',
    description: '1-7/16 bore sealed roller bearing',
    manufacturer: 'SKF',
    manufacturerPartNumber: 'PB-11416',
  );

  final chain50 = MroPart(
    legacyCode: 'CHN-50-SS',
    itemName: 'Roller Chain',
    description: 'ANSI #50 stainless roller chain 10ft',
    manufacturer: 'Tsubaki',
    manufacturerPartNumber: 'RS50SS',
  );

  final chain60 = MroPart(
    legacyCode: 'CHN-60',
    itemName: 'Roller Chain',
    description: 'ANSI #60 carbon steel roller chain 10ft',
    manufacturer: 'Tsubaki',
    manufacturerPartNumber: 'RS60',
  );

  final tappedBaseBearing = MroPart(
    legacyCode: 'BRG-TB-14375',
    itemName: 'Bearing Pillow Block',
    description:
        'BEARING, PILLOW BLOCK, 1.4375IN ID, 2 MOUNT, SS HOUSING, BALL, TAPPED BASE',
    manufacturer: 'Rexnord',
    manufacturerPartNumber: 'TB-11416-SS',
  );

  final insertBearing = MroPart(
    legacyCode: 'DODGE-IB-1',
    itemName: 'Dodge Insert Bearing',
    description:
        'BEARING, BALL, 1.1875IN ID, INSERT, SINGLE ROW, SEALED, 440C SS CAGE, ECCENTRIC LOCKING COLLAR, WIDE INNER RING',
    manufacturer: 'Dodge',
    manufacturerPartNumber: 'IB-1-3-16-SS',
  );

  final sprocket80 = MroPart(
    legacyCode: 'SPKT-80-27',
    itemName: 'Roller Chain Sprocket',
    description:
        'SPROCKET, ROLLER CHAIN, 27 TEETH, #80 CHAIN, 1.4375IN BORE, STEEL, SINGLE',
    manufacturer: 'Martin',
    manufacturerPartNumber: '80BS27-1-7/16',
  );

  final partW1074595 = MroPart(
    legacyCode: 'W1074595',
    itemName: 'Wheel Hub Drive',
    description: 'WHEEL, HUB DRIVE, FOR IPAK BOX FEEDER',
    manufacturer: 'OEM',
    manufacturerPartNumber: 'W1074595',
  );

  final partW1012503 = MroPart(
    legacyCode: 'W1012503',
    itemName: 'Support Belt',
    description: 'SUPPORT, BELT, FOR INPUT BELT',
    manufacturer: 'OEM',
    manufacturerPartNumber: 'W1012503',
  );

  final partN001901 = MroPart(
    legacyCode: 'N00-1901',
    itemName: 'Specialty Fastener',
    description: 'FASTENER, MACHINE, SPECIAL ORDER',
    manufacturer: 'OEM',
    manufacturerPartNumber: 'N00-1901',
  );

  final parts = [
    motorPart,
    bearingPart,
    chain50,
    chain60,
    tappedBaseBearing,
    insertBearing,
    sprocket80,
    partW1074595,
    partW1012503,
    partN001901,
  ];

  group('AdvancedSearchService', () {
    test('returns strong matches even without an explicit part type', () {
      final results = service.search(parts, 'baldor 2 hp 1750 rpm tefc');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, motorPart.legacyCode);
    });

    test('prioritizes exact part number matches', () {
      final results = service.search(parts, 'EM3710T');

      expect(results, isNotEmpty);
      expect(results.first.part.manufacturerPartNumber, 'EM3710T');
      expect(results.first.matchReasons, contains('Exact Part#'));
    });

    test('handles typo-tolerant bearing queries', () {
      final results = service.search(parts, 'skf bering 1-7/16');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, bearingPart.legacyCode);
    });

    test('prefers the correct chain size and material', () {
      final results = service.search(parts, '#50 stainless chain');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, chain50.legacyCode);
      expect(results.first.part.legacyCode, isNot(chain60.legacyCode));
    });

    test('describes interpreted query signals', () {
      final summary = service.describeQuery('dodge #50 chain 2 hp', resultCount: 3);

      expect(summary, contains('type chain'));
      expect(summary, contains('size 50'));
      expect(summary, contains('3 results'));
    });

    test('handles real search typo and tapped-base bearing query', () {
      final results = service.search(parts, '1-7/16 steainless tapped base bearing');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, tappedBaseBearing.legacyCode);
    });

    test('handles insert bearing with stainless shorthand and eccentric lock', () {
      final results =
          service.search(parts, '1-3/16 insert bearing, ss, eccentric locking');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, insertBearing.legacyCode);
    });

    test('handles real sprocket query with chain size, teeth, and shaft dimension', () {
      final results =
          service.search(parts, '27 teeth, 80 chain sprocket for a 1-7/16 shaft');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, sprocket80.legacyCode);
    });

    test('matches exact live-style part numbers', () {
      expect(service.search(parts, 'W1074595').first.part.legacyCode, 'W1074595');
      expect(service.search(parts, 'W1012503').first.part.legacyCode, 'W1012503');
      expect(service.search(parts, 'N00-1901').first.part.legacyCode, 'N00-1901');
    });

    test('handles dodge insert bearing query with inch shaft size', () {
      final results = service.search(parts, 'DODGE INSERT BEARING 1IN');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, insertBearing.legacyCode);
    });
  });
}