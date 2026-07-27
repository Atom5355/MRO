import '../services/search_text_utils.dart';

/// Model representing an MRO (Maintenance, Repair, and Operations) part
class MroPart {
  final String location;
  final String legacyCode;
  final String itemName;
  final int min;
  final int max;
  final double unitCost;
  final String description;
  final String manufacturer;
  final String manufacturerPartNumber;
  final String supplierPartNumber;
  final Map<String, dynamic> additionalFields;

  MroPart({
    this.location = '',
    this.legacyCode = '',
    this.itemName = '',
    this.min = 0,
    this.max = 0,
    this.unitCost = 0.0,
    this.description = '',
    this.manufacturer = '',
    this.manufacturerPartNumber = '',
    this.supplierPartNumber = '',
    this.additionalFields = const {},
  });

  /// Durable identity for carts, saved lists, and result merging.
  ///
  /// The workbook's Item Name column contains the unique W/item number. Legacy
  /// numbers are search aliases only because a small number are shared by more
  /// than one inventory row.
  late final String stableId = _buildStableId();

  /// Identifiers that a user may type into search. These must never be treated
  /// as unique persistence keys.
  late final Set<String> searchIdentifiers = Set.unmodifiable({
    itemName.trim(),
    legacyCode.trim(),
    manufacturerPartNumber.trim(),
    supplierPartNumber.trim(),
  }..removeWhere((value) => value.isEmpty));

  /// IDs accepted while resolving previously saved data.
  ///
  /// The item/MPN composite was the effective ID before legacy-column loading
  /// was repaired, so it remains as a migration alias without making legacy
  /// codes primary keys.
  late final Set<String> persistenceAliases = Set.unmodifiable({
    stableId,
    if (itemName.trim().isNotEmpty || manufacturerPartNumber.trim().isNotEmpty)
      '${itemName.trim()}_${manufacturerPartNumber.trim()}',
  }..removeWhere((value) => value.isEmpty || value == '_'));

  /// Backwards-compatible aliases for existing cart/list callers.
  Set<String> get partIds => persistenceAliases;

  /// Backwards-compatible singular ID, now guaranteed to use stable identity.
  String get partId => stableId;

  late final String searchableText = normalizeSearchText([
    location,
    legacyCode,
    itemName,
    description,
    manufacturer,
    manufacturerPartNumber,
    supplierPartNumber,
    ...additionalFields.values.map((value) => value.toString()),
  ].join(' '));

  late final Set<String> searchTokens =
      Set.unmodifiable(tokenizeSearchText(searchableText));

  late final String normalizedManufacturer = normalizeSearchText(manufacturer);

  late final Set<String> normalizedPartIdentifiers = Set.unmodifiable(
    searchIdentifiers
        .map(normalizeSearchIdentifier)
        .where((value) => value.isNotEmpty),
  );

  String _buildStableId() {
    final trimmedItemName = itemName.trim();
    if (trimmedItemName.isNotEmpty) return trimmedItemName;

    final fallbackComponents = [
      location,
      legacyCode,
      manufacturer,
      manufacturerPartNumber,
      supplierPartNumber,
      description,
    ]
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map(Uri.encodeComponent)
        .toList(growable: false);

    return fallbackComponents.isEmpty
        ? 'mro:unidentified'
        : 'mro:${fallbackComponents.join('|')}';
  }

  /// Check if this part matches the search query
  bool matchesSearch(String query) {
    final normalizedQuery = normalizeSearchText(query);
    return searchableText.contains(normalizedQuery) ||
        additionalFields.values.any((value) =>
            normalizeSearchText(value.toString()).contains(normalizedQuery));
  }

  /// W part numbers are sourced from the Item Name column in the workbook.
  String get wPartNumber {
    final trimmedItemName = itemName.trim();
    if (trimmedItemName.isEmpty ||
        !trimmedItemName.toLowerCase().startsWith('w')) {
      return '';
    }
    return trimmedItemName;
  }

  /// Get the display name (prefer Item Name, fallback to Legacy Code)
  String get displayName => itemName.isNotEmpty ? itemName : legacyCode;

  @override
  String toString() {
    return 'MroPart(legacyCode: $legacyCode, itemName: $itemName)';
  }
}
