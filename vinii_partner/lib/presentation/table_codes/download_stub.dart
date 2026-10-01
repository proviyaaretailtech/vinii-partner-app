import 'dart:typed_data';

/// Phones and tests cannot save a file straight to a folder; a share sheet
/// comes with the Android and iPhone apps. Only the browser build can.
bool get canDownloadFiles => false;

Future<bool> downloadBytes(
  Uint8List bytes,
  String filename,
  String mimeType,
) async => false;
