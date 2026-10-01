/// Opens Cashfree's hosted checkout over the page (browser build), or says
/// plainly that it cannot (other builds). Mobile builds will use Cashfree's
/// own Flutter package; until then this is the only launcher.
library;

export 'cashfree_checkout_stub.dart'
    if (dart.library.js_interop) 'cashfree_checkout_web.dart';
