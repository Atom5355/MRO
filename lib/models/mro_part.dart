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

  /// Check if this part matches the search query
  bool matchesSearch(String query) {
    final lowerQuery = query.toLowerCase();
    return location.toLowerCase().contains(lowerQuery) ||
        legacyCode.toLowerCase().contains(lowerQuery) ||
        itemName.toLowerCase().contains(lowerQuery) ||
        description.toLowerCase().contains(lowerQuery) ||
        manufacturer.toLowerCase().contains(lowerQuery) ||
        manufacturerPartNumber.toLowerCase().contains(lowerQuery) ||
        supplierPartNumber.toLowerCase().contains(lowerQuery) ||
        additionalFields.values.any((value) =>
            value.toString().toLowerCase().contains(lowerQuery));
  }

  /// Get the display name (prefer Item Name, fallback to Legacy Code)
  String get displayName => itemName.isNotEmpty ? itemName : legacyCode;

  @override
  String toString() {
    return 'MroPart(legacyCode: $legacyCode, itemName: $itemName)';
  }
}
