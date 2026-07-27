import 'package:flutter_test/flutter_test.dart';
import 'package:mro_engine/models/mro_part.dart';
import 'package:mro_engine/services/advanced_search_service.dart';
import 'package:mro_engine/services/part_filter_service.dart';

void main() {
  const service = PartFilterService();

  final first = MroPart(
    itemName: 'W1',
    legacyCode: 'L-1',
    manufacturer: 'Acme',
    description: 'Blue food grade seal',
    location: 'A-01',
  );
  final second = MroPart(
    itemName: 'W2',
    legacyCode: 'L-2',
    manufacturer: 'Acme',
    description: 'Red industrial seal',
    location: 'A-02',
  );
  final third = MroPart(
    itemName: 'W3',
    legacyCode: 'L-1',
    manufacturer: 'Beta',
    description: 'Blue industrial bearing',
    location: 'B-01',
  );
  final results = [first, second, third]
      .map(
        (part) => SearchResult(
          part: part,
          score: 10,
          matchReasons: const [],
        ),
      )
      .toList(growable: false);

  test('ORs selections within a facet and ANDs across facets', () {
    final filtered = service.apply(
      results,
      const PartFilterState(
        selectedWPartNumbers: {'W1', 'W2', 'does-not-exist'},
        selectedManufacturers: {'Acme'},
        selectedLegacyCodes: {'L2'},
      ),
    );

    expect(filtered.map((result) => result.part), [second]);
  });

  test('ANDs every text tag, including tags in the same field', () {
    final filtered = service.apply(
      results,
      const PartFilterState(
        textFilters: {
          'description': {'red', 'seal'},
          'location': {'a-02'},
        },
      ),
    );

    expect(filtered.map((result) => result.part), [second]);
  });

  test('normalizes punctuation in legacy selections', () {
    final filtered = service.apply(
      results,
      const PartFilterState(selectedLegacyCodes: {'l 1'}),
    );

    expect(filtered.map((result) => result.part), [first, third]);
  });

  test('each facet option list excludes only its own selection', () {
    const state = PartFilterState(
      selectedWPartNumbers: {'W1', 'W2'},
      selectedManufacturers: {'Acme'},
      selectedLegacyCodes: {'L-1'},
    );

    expect(
      service.options(results, state, PartFilterFacet.wPartNumber),
      ['W1'],
    );
    expect(
      service.options(results, state, PartFilterFacet.manufacturer),
      ['Acme'],
    );
    expect(
      service.options(results, state, PartFilterFacet.legacyCode),
      ['L-1', 'L-2'],
    );
  });

  test('preserves input ranking order', () {
    final filtered = service.apply(
      results.reversed.toList(),
      const PartFilterState(selectedManufacturers: {'Acme', 'Beta'}),
    );

    expect(filtered.map((result) => result.part), [third, second, first]);
  });
}
