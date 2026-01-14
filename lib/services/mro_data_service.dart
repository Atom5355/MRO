import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:http/http.dart' as http;
import '../models/mro_part.dart';

/// Service for loading and searching MRO parts data from Excel file
class MroDataService {
  // Singleton pattern
  static final MroDataService _instance = MroDataService._internal();
  factory MroDataService() => _instance;
  MroDataService._internal();

  List<MroPart> _parts = [];
  List<String> _columnHeaders = [];
  bool _isLoaded = false;

  List<MroPart> get parts => _parts;
  List<String> get columnHeaders => _columnHeaders;
  bool get isLoaded => _isLoaded;

  /// Load MRO data from the Excel file with progress callback
  Future<void> loadData({
    Function(double progress, String status)? onProgress,
  }) async {
    if (_isLoaded) return;

    try {
      onProgress?.call(0.0, 'Fetching Excel file...');

      // Fetch the Excel file from web folder
      final response = await http.get(Uri.parse('MRO%2012.18.25.xlsx'));

      if (response.statusCode != 200) {
        throw Exception('Failed to load Excel file: ${response.statusCode}');
      }

      onProgress?.call(0.2, 'Parsing Excel data...');
      final bytes = response.bodyBytes.toList();

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

      // Define exact column mappings based on MRO file structure
      // Headers: Location, Legacy Code, Item Name, Min, Max, Unit Cost, Description, Description 2-6, Manufacturer, Manufacturer Part Number, Supplier Part Number

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

        // Get the main description and filter out duplicate Description columns (2-6)
        final mainDescription = _getString(row, 'Description');

        // Build additional fields, excluding standard columns and duplicate descriptions
        final additionalFields = <String, dynamic>{};
        final excludedColumns = {
          'location',
          'legacy code',
          'item name',
          'min',
          'max',
          'unit cost',
          'description',
          'description 2',
          'description 3',
          'description 4',
          'description 5',
          'description 6',
          'manufacturer',
          'manufacturer part number',
          'supplier part number',
        };

        for (final entry in row.entries) {
          final keyLower = entry.key.toLowerCase().trim();
          if (!excludedColumns.contains(keyLower)) {
            final value = entry.value;
            if (value != null && value.toString().trim().isNotEmpty) {
              additionalFields[entry.key] = value;
            }
          }
        }

        final part = MroPart(
          location: _getString(row, 'Location'),
          legacyCode: _getString(row, 'Legacy Code'),
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

        // Only add if we have at least a legacy code, item name, or description
        if (part.legacyCode.isNotEmpty ||
            part.itemName.isNotEmpty ||
            part.description.isNotEmpty) {
          _parts.add(part);
        }
      }

      onProgress?.call(1.0, 'Loading complete!');
      _isLoaded = true;
    } catch (e) {
      throw Exception('Failed to load MRO data: $e');
    }
  }

  /// Search parts by query string
  List<MroPart> search(String query) {
    if (query.trim().isEmpty) return _parts;
    return _parts.where((part) => part.matchesSearch(query)).toList();
  }

  /// Get value from row with case-insensitive column lookup
  String _getString(Map<String, dynamic> row, String column) {
    // Try exact match first
    var value = row[column];

    // If not found, try case-insensitive match
    if (value == null) {
      final lowerColumn = column.toLowerCase();
      // Also try removing spaces for columns like "Unit Cost" -> "unitcost"
      final noSpaceColumn = lowerColumn.replaceAll(' ', '');
      for (final key in row.keys) {
        final lowerKey = key.toLowerCase();
        final noSpaceKey = lowerKey.replaceAll(' ', '');
        if (lowerKey == lowerColumn || noSpaceKey == noSpaceColumn) {
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
  ) async {
    try {
      // Get XLSX from global scope
      final xlsx = globalContext['XLSX'] as JSObject?;
      if (xlsx == null) {
        throw Exception(
          'SheetJS (XLSX) library not loaded. Make sure the script is included in index.html',
        );
      }

      // Create Uint8Array from bytes
      final jsBytes = bytes.jsify() as JSArray;
      final uint8Array = _createUint8Array(jsBytes);

      // Create options object
      final options = <String, dynamic>{'type': 'array'}.jsify() as JSObject;

      // Call XLSX.read()
      final readFn = xlsx['read'] as JSFunction;
      final workbook =
          readFn.callAsFunction(xlsx, uint8Array, options) as JSObject?;

      if (workbook == null) {
        throw Exception('Failed to read workbook');
      }

      // Get sheet names
      final sheetNames = workbook['SheetNames'] as JSArray?;
      if (sheetNames == null || sheetNames.length == 0) {
        throw Exception('No sheets found in workbook');
      }

      // Get first sheet
      final firstSheetName = (sheetNames[0] as JSString).toDart;
      final sheets = workbook['Sheets'] as JSObject;
      final sheet = sheets[firstSheetName] as JSObject?;

      if (sheet == null) {
        throw Exception('Could not read sheet: $firstSheetName');
      }

      // Get utils and convert to JSON
      final utils = xlsx['utils'] as JSObject;
      final sheetToJsonFn = utils['sheet_to_json'] as JSFunction;

      // Options: defval for empty cells
      final jsonOptions = <String, dynamic>{'defval': ''}.jsify() as JSObject;
      final jsonData =
          sheetToJsonFn.callAsFunction(utils, sheet, jsonOptions) as JSArray;

      // Convert to Dart List<Map>
      final result = <Map<String, dynamic>>[];

      for (int i = 0; i < jsonData.length; i++) {
        final row = jsonData[i] as JSObject;
        final map = <String, dynamic>{};

        // Get object keys
        final keys = _getObjectKeys(row);

        for (final key in keys) {
          final jsValue = row[key];
          map[key] = _convertJsValue(jsValue);
        }

        // Skip completely empty rows
        if (map.values.any(
          (v) => v != null && v.toString().trim().isNotEmpty,
        )) {
          result.add(map);
        }
      }

      return result;
    } catch (e) {
      throw Exception('SheetJS parsing error: $e');
    }
  }

  List<String> _getObjectKeys(JSObject obj) {
    final jsKeys = _jsObjectKeys(obj);
    final keys = <String>[];
    for (int i = 0; i < jsKeys.length; i++) {
      keys.add((jsKeys[i] as JSString).toDart);
    }
    return keys;
  }

  dynamic _convertJsValue(JSAny? value) {
    if (value == null || value.isUndefinedOrNull) {
      return null;
    }
    if (value.isA<JSString>()) {
      return (value as JSString).toDart;
    }
    if (value.isA<JSNumber>()) {
      final num = (value as JSNumber).toDartDouble;
      // Return as int if it's a whole number
      if (num == num.truncateToDouble()) {
        return num.toInt();
      }
      return num;
    }
    if (value.isA<JSBoolean>()) {
      return (value as JSBoolean).toDart;
    }
    return value.toString();
  }
}

@JS('Uint8Array.from')
external JSObject _createUint8Array(JSArray array);

@JS('Object.keys')
external JSArray _jsObjectKeys(JSObject obj);
