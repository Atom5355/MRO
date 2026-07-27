import '../models/mro_part.dart';
import 'advanced_search_service.dart';
import 'search_text_utils.dart';

enum PartFilterFacet { wPartNumber, manufacturer, legacyCode }

/// Immutable description of all result filters.
class PartFilterState {
  final Set<String> selectedWPartNumbers;
  final Set<String> selectedManufacturers;
  final Set<String> selectedLegacyCodes;
  final Map<String, Set<String>> textFilters;

  const PartFilterState({
    this.selectedWPartNumbers = const {},
    this.selectedManufacturers = const {},
    this.selectedLegacyCodes = const {},
    this.textFilters = const {},
  });

  bool get isEmpty =>
      selectedWPartNumbers.isEmpty &&
      selectedManufacturers.isEmpty &&
      selectedLegacyCodes.isEmpty &&
      textFilters.values.every((values) => values.isEmpty);
}

/// Pure filter operations shared by the result list and every facet menu.
///
/// Values within a multi-select facet are ORed. Different facets and every
/// free-text tag are ANDed. Facet options exclude that facet's own selection,
/// which keeps all three option lists symmetric.
class PartFilterService {
  const PartFilterService();

  List<SearchResult> apply(
    List<SearchResult> results,
    PartFilterState state, {
    PartFilterFacet? excludedFacet,
  }) {
    return results.where((result) {
      final part = result.part;

      if (excludedFacet != PartFilterFacet.wPartNumber &&
          state.selectedWPartNumbers.isNotEmpty &&
          !_matchesAnyExact(part.wPartNumber, state.selectedWPartNumbers)) {
        return false;
      }

      if (excludedFacet != PartFilterFacet.manufacturer &&
          state.selectedManufacturers.isNotEmpty &&
          !_matchesAnyExact(part.manufacturer, state.selectedManufacturers)) {
        return false;
      }

      if (excludedFacet != PartFilterFacet.legacyCode &&
          state.selectedLegacyCodes.isNotEmpty &&
          !_matchesAnyIdentifier(part.legacyCode, state.selectedLegacyCodes)) {
        return false;
      }

      for (final entry in state.textFilters.entries) {
        final fieldValue = _fieldValue(part, entry.key);
        for (final tag in entry.value) {
          if (!_matchesTextTag(entry.key, fieldValue, tag)) {
            return false;
          }
        }
      }

      return true;
    }).toList(growable: false);
  }

  List<String> options(
    List<SearchResult> results,
    PartFilterState state,
    PartFilterFacet facet,
  ) {
    final values = apply(results, state, excludedFacet: facet)
        .map((result) => _facetValue(result.part, facet).trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  bool _matchesAnyExact(String value, Set<String> selections) {
    final normalizedValue = normalizeSearchText(value);
    return selections.any(
      (selection) => normalizeSearchText(selection) == normalizedValue,
    );
  }

  bool _matchesAnyIdentifier(String value, Set<String> selections) {
    final normalizedValue = normalizeSearchIdentifier(value);
    return selections.any(
      (selection) => normalizeSearchIdentifier(selection) == normalizedValue,
    );
  }

  bool _matchesTextTag(String field, String value, String tag) {
    final normalizedTag = normalizeSearchText(tag);
    if (normalizedTag.isEmpty) return true;

    final normalizedField = normalizeSearchIdentifier(field);
    if ({
      'legacy',
      'legacycode',
      'legacynumber',
      'legacypartnumber',
      'item',
      'itemname',
      'wpartnumber',
      'manufacturerpartnumber',
      'mpn',
      'supplierpartnumber',
      'supplierpn',
    }.contains(normalizedField)) {
      return normalizeSearchIdentifier(value)
          .contains(normalizeSearchIdentifier(tag));
    }

    if (normalizedTag.length <= 2) {
      return containsSearchPhrase(value, normalizedTag);
    }
    return normalizeSearchText(value).contains(normalizedTag);
  }

  String _facetValue(MroPart part, PartFilterFacet facet) {
    return switch (facet) {
      PartFilterFacet.wPartNumber => part.wPartNumber,
      PartFilterFacet.manufacturer => part.manufacturer,
      PartFilterFacet.legacyCode => part.legacyCode,
    };
  }

  String _fieldValue(MroPart part, String field) {
    switch (normalizeSearchIdentifier(field)) {
      case 'location':
        return part.location;
      case 'legacy':
      case 'legacycode':
      case 'legacynumber':
      case 'legacypartnumber':
        return part.legacyCode;
      case 'item':
      case 'itemname':
      case 'wpartnumber':
        return part.itemName;
      case 'description':
      case 'itemdescription':
        return part.description;
      case 'manufacturer':
        return part.manufacturer;
      case 'manufacturerpartnumber':
      case 'mpn':
        return part.manufacturerPartNumber;
      case 'supplierpartnumber':
      case 'supplierpn':
        return part.supplierPartNumber;
      case 'all':
      case 'searchabletext':
        return part.searchableText;
    }

    final normalizedField = normalizeSearchIdentifier(field);
    for (final entry in part.additionalFields.entries) {
      if (normalizeSearchIdentifier(entry.key) == normalizedField) {
        return entry.value.toString();
      }
    }
    return '';
  }
}
