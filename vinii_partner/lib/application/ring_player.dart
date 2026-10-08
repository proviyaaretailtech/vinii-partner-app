import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/local_prefs.dart';

/// The new-order ring: a loud loop plus vibration until someone answers
/// (partner PRD §5). Failing to play sound must never break taking orders,
/// so every audio call is guarded.
class RingPlayer {
  RingPlayer(this.prefs);

  final LocalPrefs prefs;
  AudioPlayer? _player;
  Timer? _buzz;
  bool _ringing = false;

  bool get ringing => _ringing;

  Future<void> start() async {
    if (_ringing) return;
    _ringing = true;
    _buzz = Timer.periodic(
      const Duration(milliseconds: 1600),
      (_) => HapticFeedback.heavyImpact(),
    );
    if (!prefs.ringEnabled) return;
    try {
      _player ??= AudioPlayer(playerId: 'new-order-ring');
      await _player!.setReleaseMode(ReleaseMode.loop);
      await _player!.play(AssetSource('sounds/new_order.wav'), volume: 1);
    } catch (e) {
      debugPrint('Ring could not play: $e'); // i18n-ignore: debug output
    }
  }

  Future<void> stop() async {
    _ringing = false;
    _buzz?.cancel();
    _buzz = null;
    try {
      await _player?.stop();
    } catch (e) {
      debugPrint('Ring could not stop: $e'); // i18n-ignore: debug output
    }
  }

  /// Settings → "Test the ring": three seconds, then silence.
  Future<void> test() async {
    try {
      final p = AudioPlayer(playerId: 'ring-test');
      await p.play(AssetSource('sounds/new_order.wav'), volume: 1);
      unawaited(
        Future<void>.delayed(const Duration(seconds: 3), () => p.dispose()),
      );
    } catch (e) {
      debugPrint('Ring test could not play: $e'); // i18n-ignore: debug output
    }
  }

  Future<void> dispose() async {
    await stop();
    await _player?.dispose();
  }
}
