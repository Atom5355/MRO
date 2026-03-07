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

  Set<String> get partIds {
    final ids = <String>{};
    final trimmedLegacyCode = legacyCode.trim();
    final trimmedItemName = itemName.trim();
    final trimmedManufacturerPartNumber = manufacturerPartNumber.trim();
    final trimmedSupplierPartNumber = supplierPartNumber.trim();
    final trimmedDescription = description.trim();

    if (trimmedLegacyCode.isNotEmpty) {
      ids.add(trimmedLegacyCode);
    }

    if (trimmedItemName.isNotEmpty || trimmedManufacturerPartNumber.isNotEmpty) {
      ids.add('${trimmedItemName}_$trimmedManufacturerPartNumber');
    }

    if (trimmedManufacturerPartNumber.isNotEmpty) {
      ids.add(trimmedManufacturerPartNumber);
    }

    if (trimmedSupplierPartNumber.isNotEmpty) {
      ids.add(trimmedSupplierPartNumber);
    }

    if (trimmedItemName.isNotEmpty) {
      ids.add(trimmedItemName);
    }

    if (trimmedDescription.isNotEmpty) {
      ids.add(trimmedDescription);
    }

    ids.removeWhere((value) => value.trim().isEmpty || value == '_');
    return ids;
  }

  String get partId => partIds.firstOrNull ?? '';

  String get searchableText => normalizeSearchText([
        location,
        legacyCode,
        itemName,
        description,
        manufacturer,
        manufacturerPartNumber,
        supplierPartNumber,
        ...additionalFields.values.map((value) => value.toString()),
      ].join(' '));

  Set<String> get searchTokens => tokenizeSearchText(searchableText).toSet();

  String get normalizedManufacturer => normalizeSearchText(manufacturer);

  Set<String> get normalizedPartIdentifiers {
    return {
      if (legacyCode.isNotEmpty) normalizeSearchIdentifier(legacyCode),
      if (manufacturerPartNumber.isNotEmpty)
        normalizeSearchIdentifier(manufacturerPartNumber),
      if (supplierPartNumber.isNotEmpty)
        normalizeSearchIdentifier(supplierPartNumber),
      if (partId.isNotEmpty) normalizeSearchIdentifier(partId),
    }.where((value) => value.isNotEmpty).toSet();
  }

  /// Check if this part matches the search query
  bool matchesSearch(String query) {
    final normalizedQuery = normalizeSearchText(query);
    return searchableText.contains(normalizedQuery) ||
        additionalFields.values.any((value) =>
        normalizeSearchText(value.toString()).contains(normalizedQuery));
  }

  /// Get the display name (prefer Item Name, fallback to Legacy Code)
  String get displayName => itemName.isNotEmpty ? itemName : legacyCode;

  @override
  String toString() {
    return 'MroPart(legacyCode: $legacyCode, itemName: $itemName)';
  }
}
