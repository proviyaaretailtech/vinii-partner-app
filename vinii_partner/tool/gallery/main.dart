// Design gallery: NOT part of the app and never built into it.
//
// Mounts the guest runtime on clearly synthetic fixture data so screens can be
// reviewed in a browser without a login, a database or any real restaurant's
// rows. The dish names and prices are copied from the founder's two reference
// boards (docs/reference/). Nothing here is read from or written to Supabase.
//
//   flutter run -d web-server --web-port 8091 -t tool/gallery/main.dart
//
// Query parameters: ?t=bistro|artisan|fresh  &table=12  &photos=0|1
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/widgets.dart';

import 'gallery_kit.dart';

void main() {
  // ?fakecf=1 stands a pretend Cashfree script in the page, so the real web
  // checkout code (not a dialog) is what runs. It pays nothing and talks to
  // nobody.
  if (Uri.base.queryParameters['fakecf'] == '1') _installFakeCashfree();
  runApp(const GalleryApp());
}

void _installFakeCashfree() {
  final sdk = JSObject();
  sdk['checkout'] = ((JSAny? args) {
    final result = JSObject();
    final details = JSObject();
    details['paymentMessage'] = 'Simulated by the design gallery'.toJS;
    result['paymentDetails'] = details;
    return Future<JSAny?>.delayed(
      const Duration(milliseconds: 900),
      () => result,
    ).toJS;
  }).toJS;
  globalContext['Cashfree'] = ((JSAny? options) => sdk).toJS;
}
