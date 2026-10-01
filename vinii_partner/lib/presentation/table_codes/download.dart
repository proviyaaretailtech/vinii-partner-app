// Saving a file to the device: the browser build downloads it, other builds
// say they cannot yet (see download_stub.dart).
export 'download_stub.dart' if (dart.library.js_interop) 'download_web.dart';
