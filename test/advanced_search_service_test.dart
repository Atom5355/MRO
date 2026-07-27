import 'package:flutter_test/flutter_test.dart';
import 'package:mro_engine/models/mro_part.dart';
import 'package:mro_engine/services/advanced_search_service.dart';
import 'package:mro_engine/services/search_text_utils.dart';

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
      final summary =
          service.describeQuery('dodge #50 chain 2 hp', resultCount: 3);

      expect(summary, contains('type chain'));
      expect(summary, contains('size 50'));
      expect(summary, contains('3 results'));
    });

    test('handles real search typo and tapped-base bearing query', () {
      final results =
          service.search(parts, '1-7/16 steainless tapped base bearing');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, tappedBaseBearing.legacyCode);
    });

    test('handles insert bearing with stainless shorthand and eccentric lock',
        () {
      final results =
          service.search(parts, '1-3/16 insert bearing, ss, eccentric locking');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, insertBearing.legacyCode);
    });

    test(
        'handles real sprocket query with chain size, teeth, and shaft dimension',
        () {
      final results = service.search(
          parts, '27 teeth, 80 chain sprocket for a 1-7/16 shaft');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, sprocket80.legacyCode);
    });

    test('matches exact live-style part numbers', () {
      expect(
          service.search(parts, 'W1074595').first.part.legacyCode, 'W1074595');
      expect(
          service.search(parts, 'W1012503').first.part.legacyCode, 'W1012503');
      expect(
          service.search(parts, 'N00-1901').first.part.legacyCode, 'N00-1901');
    });

    test('handles dodge insert bearing query with inch shaft size', () {
      final results = service.search(parts, 'DODGE INSERT BEARING 1IN');

      expect(results, isNotEmpty);
      expect(results.first.part.legacyCode, insertBearing.legacyCode);
    });

    test('returns every duplicate exact legacy match without punctuation', () {
      final duplicates = [
        MroPart(itemName: 'W200001', legacyCode: 'LEG-00.42'),
        MroPart(itemName: 'W200002', legacyCode: 'LEG-00.42'),
      ];

      final results = service.search(duplicates, 'leg 00-42');

      expect(results.map((result) => result.part.stableId), [
        'W200001',
        'W200002',
      ]);
      expect(results.every((result) => result.kind == SearchResultKind.exact),
          isTrue);
      expect(results.every((result) => result.displayLabel == 'EXACT'), isTrue);
    });

    test('recognizes short part identifiers in compound queries', () {
      final shortId = MroPart(
        itemName: 'W300001',
        description: 'Pillow block bearing',
        manufacturerPartNumber: 'A49',
      );
      final other = MroPart(
        itemName: 'W300002',
        description: 'Pillow block bearing',
        manufacturerPartNumber: 'A50',
      );

      final results = service.search([other, shortId], 'A49 bearing');

      expect(results.first.part, same(shortId));
      expect(results.first.matchReasons, contains('Exact Part#'));
    });

    test('matches punctuation-heavy short supplier identifiers exactly', () {
      final shortId = MroPart(
        itemName: 'W300003',
        supplierPartNumber: '#63',
      );

      final results = service.search([shortId], '63');

      expect(results.single.part, same(shortId));
      expect(results.single.kind, SearchResultKind.exact);
    });

    test('derives short manufacturers from the supplied data', () {
      final dynamicManufacturers = [
        MroPart(itemName: 'W400001', manufacturer: '3M'),
        MroPart(itemName: 'W400002', manufacturer: 'GIRO'),
        MroPart(itemName: 'W400003', manufacturer: 'SICK'),
      ];

      for (final part in dynamicManufacturers) {
        final results = service.search(dynamicManufacturers, part.manufacturer);
        expect(results, isNotEmpty);
        expect(results.first.part, same(part));
        expect(results.first.matchReasons.first, startsWith('MFG:'));
      }
    });

    test('matches material abbreviations only on token boundaries', () {
      final brass = MroPart(
        itemName: 'W500001',
        description: 'BRASS BALL BEARING',
      );
      final stainless = MroPart(
        itemName: 'W500002',
        description: 'SS BEARING',
      );

      final results = service.search([brass, stainless], 'ss bearing');

      expect(results.first.part, same(stainless));
      final brassResult = results.where((result) => result.part == brass);
      expect(
        brassResult.every(
          (result) => !result.matchReasons.contains('STAINLESS'),
        ),
        isTrue,
      );
    });

    test('parses unit-bearing whole-number dimensions', () {
      final oneInch = MroPart(
        itemName: 'W600001',
        description: 'BEARING, 1IN BORE',
      );
      final twoInch = MroPart(
        itemName: 'W600002',
        description: 'BEARING, 2IN BORE',
      );

      final results = service.search([twoInch, oneInch], 'bearing 1IN bore');

      expect(results.first.part, same(oneInch));
      expect(results.first.matchReasons, contains('1 in'));
    });

    test('converts explicit dimensions before comparing unit systems', () {
      final oneMillimeter = MroPart(
        itemName: 'W610001',
        description: 'BEARING, 1 MM BORE',
      );
      final equivalentMillimeters = MroPart(
        itemName: 'W610002',
        description: 'BEARING, 25.4 MM BORE',
      );

      final results = service.search(
        [oneMillimeter, equivalentMillimeters],
        'bearing 1 in bore',
      );

      expect(results.first.part, same(equivalentMillimeters));
      expect(results.first.matchReasons, contains('1 in'));
      final wrongUnit =
          results.where((result) => result.part == oneMillimeter).firstOrNull;
      expect(
        wrongUnit == null || !wrongUnit.matchReasons.contains('1 in'),
        isTrue,
      );
    });

    test('does not use fraction text to bridge incompatible explicit units',
        () {
      final halfMillimeter = MroPart(
        itemName: 'W620001',
        description: 'BEARING, 1/2 MM BORE',
      );
      final halfInch = MroPart(
        itemName: 'W620002',
        description: 'BEARING, 1/2 IN BORE',
      );

      final results = service.search(
        [halfMillimeter, halfInch],
        'bearing 1/2 in bore',
      );

      expect(results.first.part, same(halfInch));
      final wrongUnit =
          results.where((result) => result.part == halfMillimeter).firstOrNull;
      expect(
        wrongUnit == null || !wrongUnit.matchReasons.contains('1/2 in'),
        isTrue,
      );
    });

    test('retains matching against legacy bare fractions and decimals', () {
      final legacyDecimal = MroPart(
        itemName: 'W630001',
        description: 'BEARING, 1.4375 BORE',
      );

      final results = service.search(
        [legacyDecimal],
        'bearing 1-7/16 in bore',
      );

      expect(results, isNotEmpty);
      expect(results.first.part, same(legacyDecimal));
      expect(results.first.matchReasons, contains('1-7/16 in'));
    });

    test('does not parse ordinary words as short specification units', () {
      const falseSpecQueries = {
        '3 valves': 'voltage',
        '2 aluminum': 'amp',
        '5 washers': 'watt',
        '27 timing': 'teeth',
        '50 pumps': 'pitch',
      };

      for (final entry in falseSpecQueries.entries) {
        expect(
          service.describeQuery(entry.key).toLowerCase(),
          isNot(contains(entry.value)),
          reason: entry.key,
        );
      }
    });

    test('still parses bounded short specification units', () {
      const validSpecQueries = {
        'motor 3 V': 'voltage',
        'motor 2 A': 'amp',
        'heater 5 W': 'watt',
        'sprocket 27 T': 'teeth',
        'chain 50 P': 'pitch',
      };

      for (final entry in validSpecQueries.entries) {
        expect(
          service.describeQuery(entry.key).toLowerCase(),
          contains(entry.value),
          reason: entry.key,
        );
      }
    });

    test('does not parse specification suffixes embedded in identifiers', () {
      const identifierQueries = [
        'A3V-X',
        'AB2A-1',
        'HEAT5W-X',
        'SPROCKET27T-X',
        'CHAIN50P-X',
      ];

      for (final query in identifierQueries) {
        final description = service.describeQuery(query).toLowerCase();
        expect(description, isNot(contains('voltage')), reason: query);
        expect(description, isNot(contains('amp')), reason: query);
        expect(description, isNot(contains('watt')), reason: query);
        expect(description, isNot(contains('teeth')), reason: query);
        expect(description, isNot(contains('pitch')), reason: query);
      }
    });

    test('does not reinterpret decimal specifications as dimensions', () {
      for (final query in const [
        'motor 0.5 HP',
        'motor 1/2 HP',
        'motor 2.5 A',
        'motor 208-230/460 V',
        'gear reducer 2.5:1 ratio',
      ]) {
        expect(extractSearchDimensions(query), isEmpty, reason: query);
      }

      expect(extractSearchDimensions('bearing 0.5 in bore'), isNotEmpty);
      expect(extractSearchDimensions('bearing bore 0.5'), isNotEmpty);
    });

    test('matches any rating in a multi-voltage field', () {
      final dualVoltage = MroPart(
        itemName: 'W700001',
        description: 'AC MOTOR 208-230/460 V 3 PHASE',
      );
      final conflicting = MroPart(
        itemName: 'W700002',
        description: 'AC MOTOR 575 V 3 PHASE',
      );

      final results = service.search([conflicting, dualVoltage], '208 V motor');

      expect(results.first.part, same(dualVoltage));
      expect(results.first.matchReasons, contains('208 VOLTAGE'));
    });

    test('penalizes an explicitly conflicting numeric specification', () {
      final correct = MroPart(
        itemName: 'W800001',
        description: 'AC MOTOR 575 V',
      );
      final conflict = MroPart(
        itemName: 'W800002',
        description: 'AC MOTOR 230/460 V',
      );

      final results = service.search([conflict, correct], '575 V motor');

      expect(results.first.part, same(correct));
      final conflictResult =
          results.where((result) => result.part == conflict).firstOrNull;
      expect(
        conflictResult == null || conflictResult.score < results.first.score,
        isTrue,
      );
    });

    test('keeps the complete local pool for an empty query', () {
      final manyParts = List.generate(
        125,
        (index) => MroPart(itemName: 'W${index.toString().padLeft(6, '0')}'),
      );

      expect(service.search(manyParts, ''), hasLength(125));
    });

    test('keeps local rank separate from display metadata', () {
      final local = SearchResult(
        part: motorPart,
        score: 420,
        matchReasons: const [],
      );
      final ai = SearchResult(
        part: motorPart,
        score: 420,
        matchReasons: const [],
        kind: SearchResultKind.ai,
        relevance: 140,
      );

      expect(local.displayLabel, 'LOCAL');
      expect(local.displayRelevance, isNull);
      expect(ai.displayLabel, '100%');
      expect(ai.displayRelevance, 100);
    });
  });
}
