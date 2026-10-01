import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// The browser saves a file to Downloads when a link with a file name is
/// clicked.
bool get canDownloadFiles => true;

Future<bool> downloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final link = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  web.document.body?.append(link);
  link.click();
  link.remove();
  // Let the browser start reading the file before its address is released.
  Timer(const Duration(seconds: 5), () => web.URL.revokeObjectURL(url));
  return true;
}
