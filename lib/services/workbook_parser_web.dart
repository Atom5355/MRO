import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Future<List<Map<String, dynamic>>> parseExcelWorkbook(List<int> bytes) async {
  try {
    final xlsx = globalContext['XLSX'] as JSObject?;
    if (xlsx == null) {
      throw Exception(
        'SheetJS (XLSX) library not loaded. Make sure the script is included in index.html',
      );
    }

    final jsBytes = bytes.toList(growable: false).jsify() as JSArray;
    final uint8Array = _createUint8Array(jsBytes);
    final options = <String, dynamic>{'type': 'array'}.jsify() as JSObject;
    final readFn = xlsx['read'] as JSFunction;
    final workbook =
        readFn.callAsFunction(xlsx, uint8Array, options) as JSObject?;

    if (workbook == null) {
      throw Exception('Failed to read workbook');
    }

    final sheetNames = workbook['SheetNames'] as JSArray?;
    if (sheetNames == null || sheetNames.length == 0) {
      throw Exception('No sheets found in workbook');
    }

    final firstSheetName = (sheetNames[0] as JSString).toDart;
    final sheets = workbook['Sheets'] as JSObject;
    final sheet = sheets[firstSheetName] as JSObject?;
    if (sheet == null) {
      throw Exception('Could not read sheet: $firstSheetName');
    }

    final utils = xlsx['utils'] as JSObject;
    final sheetToJsonFn = utils['sheet_to_json'] as JSFunction;
    final jsonOptions = <String, dynamic>{'defval': ''}.jsify() as JSObject;
    final jsonData =
        sheetToJsonFn.callAsFunction(utils, sheet, jsonOptions) as JSArray;
    final result = <Map<String, dynamic>>[];

    for (var index = 0; index < jsonData.length; index++) {
      final row = jsonData[index] as JSObject;
      final map = <String, dynamic>{};
      for (final key in _getObjectKeys(row)) {
        map[key] = _convertJsValue(row[key]);
      }
      if (map.values.any(
        (value) => value != null && value.toString().trim().isNotEmpty,
      )) {
        result.add(map);
      }
    }

    return result;
  } catch (error) {
    throw Exception('SheetJS parsing error: $error');
  }
}

List<String> _getObjectKeys(JSObject object) {
  final jsKeys = _jsObjectKeys(object);
  return [
    for (var index = 0; index < jsKeys.length; index++)
      (jsKeys[index] as JSString).toDart,
  ];
}

dynamic _convertJsValue(JSAny? value) {
  if (value == null || value.isUndefinedOrNull) {
    return null;
  }
  if (value.isA<JSString>()) {
    return (value as JSString).toDart;
  }
  if (value.isA<JSNumber>()) {
    final number = (value as JSNumber).toDartDouble;
    return number == number.truncateToDouble() ? number.toInt() : number;
  }
  if (value.isA<JSBoolean>()) {
    return (value as JSBoolean).toDart;
  }
  return value.toString();
}

@JS('Uint8Array.from')
external JSObject _createUint8Array(JSArray array);

@JS('Object.keys')
external JSArray _jsObjectKeys(JSObject object);
