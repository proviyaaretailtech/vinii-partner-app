import 'dart:async';

import 'package:vinii_partner/l10n/locales.dart';
import 'package:vinii_partner/l10n/script_fonts.dart';

/// A script-font loader the test controls: it can be held back (the font is
/// "still downloading"), made to fail, and it counts how often it was asked.
class FakeScriptFonts implements ScriptFontLoader {
  FakeScriptFonts({this.ready = false});

  bool ready;
  var loads = 0;

  /// While set, `ensureLoaded` waits for it (a slow download).
  Completer<void>? gate;

  /// While set, `ensureLoaded` throws it (a failed download).
  Object? failWith;

  @override
  bool isReady(ScriptKind script) => script == ScriptKind.latin || ready;

  Future<void>? _inFlight;

  /// Like the real loader: calls made while a load runs share it; a failed
  /// load is forgotten so the next call tries again.
  @override
  Future<void> ensureLoaded(ScriptKind script) {
    if (isReady(script)) return Future.value();
    return _inFlight ??= _load().whenComplete(() => _inFlight = null);
  }

  Future<void> _load() async {
    loads++;
    final g = gate;
    if (g != null) await g.future;
    final f = failWith;
    if (f != null) throw f;
    ready = true;
  }

  /// Starts holding loads back.
  Completer<void> hold() => gate = Completer<void>();
}
