import '../models/mro_part.dart';
import 'search_text_utils.dart';

/// Cached, normalized fields for one immutable [MroPart].
class IndexedMroPart {
  final MroPart part;
  final String searchableText;
  final Set<String> tokens;
  final List<SearchDimension> dimensions;
  final String itemName;
  final String description;
  final String manufacturer;
  final Set<String> identifiers;

  IndexedMroPart._(this.part)
      : searchableText = part.searchableText,
        tokens = part.searchTokens,
        dimensions = List.unmodifiable(
          extractSearchDimensions(part.searchableText),
        ),
        itemName = normalizeSearchText(part.itemName),
        description = normalizeSearchText(part.description),
        manufacturer = part.normalizedManufacturer,
        identifiers = part.normalizedPartIdentifiers;

  /// Backwards-compatible numeric projection of [dimensions].
  late final List<double> numbers = List.unmodifiable(
    dimensions.map((dimension) => dimension.value),
  );
}

/// Immutable search index built once for a loaded workbook.
///
/// Identifier values map to lists because legacy, manufacturer, and supplier
/// numbers are not guaranteed to be unique.
class MroSearchIndex {
  final List<MroPart> parts;
  final List<IndexedMroPart> entries;
  final Map<String, List<MroPart>> identifierLookup;
  final List<String> manufacturerVocabulary;
  final Map<String, String> normalizedManufacturers;

  final Map<MroPart, IndexedMroPart> _entryByPart;

  MroSearchIndex._({
    required this.parts,
    required this.entries,
    required this.identifierLookup,
    required this.manufacturerVocabulary,
    required this.normalizedManufacturers,
    required Map<MroPart, IndexedMroPart> entryByPart,
  }) : _entryByPart = entryByPart;

  factory MroSearchIndex.build(List<MroPart> sourceParts) {
    final parts = List<MroPart>.unmodifiable(sourceParts);
    final entries = <IndexedMroPart>[];
    final byPart = <MroPart, IndexedMroPart>{};
    final identifiers = <String, List<MroPart>>{};
    final manufacturers = <String, String>{};

    for (final part in parts) {
      final entry = IndexedMroPart._(part);
      entries.add(entry);
      byPart[part] = entry;

      for (final identifier in entry.identifiers) {
        identifiers.putIfAbsent(identifier, () => <MroPart>[]).add(part);
      }

      final normalizedManufacturer = entry.manufacturer;
      if (normalizedManufacturer.isNotEmpty) {
        manufacturers.putIfAbsent(
          normalizedManufacturer,
          () => part.manufacturer.trim(),
        );
      }
    }

    final frozenLookup = <String, List<MroPart>>{
      for (final entry in identifiers.entries)
        entry.key: List<MroPart>.unmodifiable(entry.value),
    };
    final vocabulary = manufacturers.values.toList(growable: false)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return MroSearchIndex._(
      parts: parts,
      entries: List<IndexedMroPart>.unmodifiable(entries),
      identifierLookup: Map<String, List<MroPart>>.unmodifiable(frozenLookup),
      manufacturerVocabulary: List<String>.unmodifiable(vocabulary),
      normalizedManufacturers: Map<String, String>.unmodifiable(manufacturers),
      entryByPart: Map<MroPart, IndexedMroPart>.unmodifiable(byPart),
    );
  }

  /// Every row matching the complete, punctuation-insensitive identifier.
  List<MroPart> exactIdentifierMatches(String query) {
    final normalized = normalizeSearchIdentifier(query.trim());
    if (normalized.isEmpty) return const [];
    return identifierLookup[normalized] ?? const [];
  }

  IndexedMroPart entryFor(MroPart part) =>
      _entryByPart[part] ?? IndexedMroPart._(part);

  /// Whether this index represents the same object list supplied by a caller.
  bool represents(List<MroPart> candidateParts) {
    if (identical(parts, candidateParts)) return true;
    if (parts.length != candidateParts.length) return false;
    for (var index = 0; index < parts.length; index++) {
      if (!identical(parts[index], candidateParts[index])) return false;
    }
    return true;
  }
}
