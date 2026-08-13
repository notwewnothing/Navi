import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

abstract final class Sfx {
  static bool enabled = true;

  static final _tick = AudioPlayer(playerId: 'sfx_tick');
  static final _complete = AudioPlayer(playerId: 'sfx_complete');
  static final _knf = AudioPlayer(playerId: 'sfx_knf');
  static final _glitch = AudioPlayer(playerId: 'sfx_glitch');
  static bool _ready = false;

  static Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      // game usage and no audio focus steal so ticks never yank the user's music
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            usageType: AndroidUsageType.game,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ),
      );
      for (final (player, asset) in [
        (_tick, 'sounds/tick.wav'),
        (_complete, 'sounds/complete.wav'),
        (_knf, 'sounds/knf.wav'),
        (_glitch, 'sounds/glitch.wav'),
      ]) {
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setSource(AssetSource(asset));
        await player.setReleaseMode(ReleaseMode.stop);
      }
    } catch (e) {
      debugPrint('sfx unavailable: $e');
    }
  }

  static void _play(AudioPlayer player) {
    if (!enabled) return;
    try {
      player.stop().then((_) => player.resume()).catchError((_) {});
    } catch (_) {}
  }

  static void tick() => _play(_tick);

  static void complete() => _play(_complete);

  static void knf() => _play(_knf);

  static void glitch() => _play(_glitch);
}
