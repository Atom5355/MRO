import 'browser_print_service_stub.dart'
    if (dart.library.js_interop) 'browser_print_service_web.dart' as impl;

Future<bool> openPrintWindow(String htmlContent) {
  return impl.openPrintWindow(htmlContent);
}