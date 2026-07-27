import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/mro_part.dart';
import 'mro_search_index.dart';
import 'search_text_utils.dart';
import 'workbook_parser.dart';

/// Service for loading and searching MRO parts data from Excel file
class MroDataService {
  static const String _mroConfigAssetPath = 'web/mro-config.json';
  static const String _defaultExcelFileName = 'MRO.xlsx';
  static const List<String> _primaryDescriptionColumns = [
    'Item Description',
    'Description',
  ];
  static const List<String> legacyColumnAliases = [
    'Legacy #',
    'Legacy Code',
    'Legacy Number',
    'Legacy Part Number',
  ];
  static const Set<String> _excludedColumns = {
    'location',
    'legacy',
    'legacycode',
    'legacynumber',
    'legacypartnumber',
    'itemname',
    'min',
    'max',
    'unitcost',
    'description',
    'description2',
    'description3',
    'description4',
    'description5',
    'description6',
    'itemdescription',
    'itemdescription2',
    'itemdescription3',
    'itemdescription4',
    'itemdescription5',
    'itemdescription6',
    'manufacturer',
    'manufacturerpartnumber',
    'supplierpartnumber',
  };

  // Singleton pattern
  static final MroDataService _instance = MroDataService._internal();
  factory MroDataService() => _instance;
  MroDataService._internal();

  List<MroPart> _parts = [];
  List<String> _columnHeaders = [];
  MroSearchIndex? _searchIndex;
  bool _isLoaded = false;

  List<MroPart> get parts => _parts;
  List<String> get columnHeaders => _columnHeaders;
  MroSearchIndex? get searchIndex => _searchIndex;
  bool get isLoaded => _isLoaded;

  /// Load MRO data from the Excel file with progress callback
  Future<void> loadData({
    Function(double progress, String status)? onProgress,
  }) async {
    if (_isLoaded) return;

    try {
      onProgress?.call(0.0, 'Resolving workbook...');

      final excelFileName = await _resolveExcelFileName();

      onProgress?.call(0.1, 'Loading workbook...');
      final bytes = await _loadExcelBytes(excelFileName);

      onProgress?.call(0.2, 'Parsing Excel data...');

      // Use JavaScript SheetJS to parse the Excel file
      final data = await _parseExcelWithSheetJS(bytes);

      if (data.isEmpty) {
        throw Exception('No data found in Excel file');
      }

      onProgress?.call(0.4, 'Reading column headers...');
      // Get headers from first row keys
      if (data.isNotEmpty) {
        _columnHeaders = data.first.keys.toList();
      }

      validateHeaders(_columnHeaders);

      // Define exact column mappings based on MRO file structure.
      // The primary description header may be either Item Description or Description.

      // Parse data rows progressively
      _parts = [];
      final totalRows = data.length;
      const batchSize = 500; // Process in batches to avoid blocking

      for (var i = 0; i < totalRows; i++) {
        final row = data[i];

        // Update progress every batch
        if (i % batchSize == 0) {
          final progress = 0.4 + (0.6 * (i / totalRows));
          onProgress?.call(
            progress,
            'Processing parts ${i + 1}/$totalRows...',
          );
          // Allow UI to update
          await Future.delayed(Duration.zero);
        }

        final part = _parsePartRow(row);

        // Only add if we have at least a legacy code, item name, or description
        if (part.legacyCode.isNotEmpty ||
            part.itemName.isNotEmpty ||
            part.description.isNotEmpty) {
          _parts.add(part);
        }
      }

      _searchIndex = MroSearchIndex.build(_parts);
      _parts = _searchIndex!.parts;

      onProgress?.call(1.0, 'Loading complete!');
      _isLoaded = true;
    } catch (e) {
      throw Exception('Failed to load MRO data: $e');
    }
  }

  /// Search parts by query string
  List<MroPart> search(String query) {
    if (query.trim().isEmpty) return _parts;
    final index = _searchIndex ?? MroSearchIndex.build(_parts);
    final exactMatches = index.exactIdentifierMatches(query);
    if (exactMatches.isNotEmpty) return exactMatches;

    final normalizedQuery = normalizeSearchText(query);
    return index.entries
        .where((entry) => entry.searchableText.contains(normalizedQuery))
        .map((entry) => entry.part)
        .toList(growable: false);
  }

  Future<String> _resolveExcelFileName() async {
    try {
      final rawConfig = await _loadWorkbookConfig();
      final decoded = jsonDecode(rawConfig);

      if (decoded is Map<String, dynamic>) {
        final configuredFileName =
            (decoded['excelFile'] as String? ?? '').trim();
        if (configuredFileName.isNotEmpty) {
          return configuredFileName;
        }
      }
    } catch (_) {
      // Fall back to the current default workbook when the config is absent.
    }

    return _defaultExcelFileName;
  }

  Future<String> _loadWorkbookConfig() async {
    return rootBundle.loadString(_mroConfigAssetPath, cache: false);
  }

  Future<List<int>> _loadExcelBytes(String excelFileName) async {
    try {
      final data = await rootBundle.load('web/$excelFileName');
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (e) {
      throw Exception('Unable to load workbook asset "$excelFileName": $e');
    }
  }

  @visibleForTesting
  static MroPart parsePartRow(Map<String, dynamic> row) {
    return _instance._parsePartRow(row);
  }

  /// Validate the identifier-bearing columns before parsing thousands of rows.
  @visibleForTesting
  static void validateHeaders(Iterable<String> headers) {
    final normalizedHeaders = headers.map(_normalizeColumnName).toSet();
    final missing = <String>[];

    if (!normalizedHeaders.contains(_normalizeColumnName('Item Name'))) {
      missing.add('"Item Name"');
    }

    final hasLegacyHeader = legacyColumnAliases
        .map(_normalizeColumnName)
        .any(normalizedHeaders.contains);
    if (!hasLegacyHeader) {
      missing.add(
        'one of ${legacyColumnAliases.map((value) => '"$value"').join(', ')}',
      );
    }

    if (missing.isNotEmpty) {
      throw FormatException(
        'Workbook schema error: missing required identifier '
        'column${missing.length == 1 ? '' : 's'} ${missing.join(' and ')}.',
      );
    }
  }

  MroPart _parsePartRow(Map<String, dynamic> row) {
    final mainDescription = _getFirstNonEmptyString(
      row,
      _primaryDescriptionColumns,
    );

    final additionalFields = <String, dynamic>{};
    for (final entry in row.entries) {
      final normalizedKey = _normalizeColumnName(entry.key);
      if (!_excludedColumns.contains(normalizedKey)) {
        final value = entry.value;
        if (value != null && value.toString().trim().isNotEmpty) {
          additionalFields[entry.key] = value;
        }
      }
    }

    return MroPart(
      location: _getString(row, 'Location'),
      legacyCode: _getFirstNonEmptyString(row, legacyColumnAliases),
      itemName: _getString(row, 'Item Name'),
      min: _getInt(row, 'Min'),
      max: _getInt(row, 'Max'),
      unitCost: _getUnitCost(row),
      description: mainDescription,
      manufacturer: _getString(row, 'Manufacturer'),
      manufacturerPartNumber: _getString(row, 'Manufacturer Part Number'),
      supplierPartNumber: _getString(row, 'Supplier Part Number'),
      additionalFields: additionalFields,
    );
  }

  String _getFirstNonEmptyString(
    Map<String, dynamic> row,
    Iterable<String> columns,
  ) {
    for (final column in columns) {
      final value = _getString(row, column);
      if (value.isNotEmpty) {
        return value;
      }
    }
    return '';
  }

  /// Get value from row with case-insensitive column lookup
  String _getString(Map<String, dynamic> row, String column) {
    // Try exact match first
    var value = row[column];

    // If not found, try case-insensitive match
    if (value == null) {
      final normalizedColumn = _normalizeColumnName(column);
      for (final key in row.keys) {
        if (_normalizeColumnName(key) == normalizedColumn) {
          value = row[key];
          break;
        }
      }
    }

    if (value == null) return '';
    final str = value.toString().trim();
    // Handle Excel null representations
    if (str.isEmpty ||
        str.toLowerCase() == 'null' ||
        str == 'N/A' ||
        str == 'n/a') {
      return '';
    }
    return str;
  }

  static String _normalizeColumnName(String column) {
    return column.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  int _getInt(Map<String, dynamic> row, String column) {
    final strValue = _getString(row, column);
    if (strValue.isEmpty) return 0;
    // Remove any non-numeric characters except minus and decimal
    final cleaned = strValue.replaceAll(RegExp(r'[^\d.-]'), '');
    return int.tryParse(cleaned) ?? double.tryParse(cleaned)?.toInt() ?? 0;
  }

  double _getDouble(Map<String, dynamic> row, String column) {
    final strValue = _getString(row, column);
    if (strValue.isEmpty) return 0.0;
    // Remove currency symbols and other non-numeric characters
    final cleaned = strValue.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  /// Try multiple column name variations for unit cost
  double _getUnitCost(Map<String, dynamic> row) {
    // Try different column name variations
    final variations = [
      'Unit Cost',
      'UnitCost',
      'Cost',
      'Price',
      'Unit Price',
      'UnitPrice',
    ];
    for (final col in variations) {
      final value = _getDouble(row, col);
      if (value > 0) return value;
    }
    return 0.0;
  }

  /// Parse Excel file using SheetJS via JavaScript interop
  Future<List<Map<String, dynamic>>> _parseExcelWithSheetJS(
    List<int> bytes,
  ) {
    return parseExcelWorkbook(bytes);
  }
}
