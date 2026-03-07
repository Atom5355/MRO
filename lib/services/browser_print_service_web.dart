import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<bool> openPrintWindow(String htmlContent) async {
  final blob = web.Blob(
    <web.BlobPart>[htmlContent.toJS as web.BlobPart].toJS,
    web.BlobPropertyBag(type: 'text/html'),
  );
  final url = web.URL.createObjectURL(blob);
  web.window.open(url, '_blank');
  return true;
}