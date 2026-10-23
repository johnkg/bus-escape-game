import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flame_audio/flame_audio.dart';

import 'progress_service.dart';

/// Things that happen in a game that deserve a sound and/or a buzz.
enum GameEvent { busExit, blocked, board, depart, win, lose, undo, booster }

enum HapticKind { selection, light, medium, heavy }

abstract class SoundPlayer {
  Future<void> playSfx(String file);
  Future<void> startMusic();
  Future<void> stopMusic();
}

abstract class HapticsPlayer {
  Future<void> play(HapticKind kind);
}

/// Plays sound and haptics for [GameEvent]s, honouring the user's settings.
class FeedbackService {
  FeedbackService({
    required this.settings,
    required this.sound,
    required this.haptics,
  }) {
    settings.addListener(syncMusic);
  }

  /// Silent service for tests and platforms without audio.
  factory FeedbackService.silent(ProgressService settings) => FeedbackService(
    settings: settings,
    sound: const NoopSoundPlayer(),
    haptics: const NoopHapticsPlayer(),
  );

  final ProgressService settings;
  final SoundPlayer sound;
  final HapticsPlayer haptics;

  bool _musicPlaying = false;

  static const Map<GameEvent, String> _sfx = {
    GameEvent.busExit: 'exit.wav',
    GameEvent.blocked: 'blocked.wav',
    GameEvent.board: 'board.wav',
    GameEvent.depart: 'depart.wav',
    GameEvent.win: 'win.wav',
    GameEvent.lose: 'lose.wav',
    GameEvent.undo: 'undo.wav',
    GameEvent.booster: 'booster.wav',
  };

  static const Map<GameEvent, HapticKind> _haptic = {
    GameEvent.busExit: HapticKind.light,
    GameEvent.blocked: HapticKind.heavy,
    GameEvent.board: HapticKind.selection,
    GameEvent.depart: HapticKind.medium,
    GameEvent.win: HapticKind.heavy,
    GameEvent.lose: HapticKind.heavy,
    GameEvent.undo: HapticKind.light,
    GameEvent.booster: HapticKind.medium,
  };

  void emit(GameEvent event) {
    if (settings.soundOn) sound.playSfx(_sfx[event]!);
    if (settings.hapticsOn) haptics.play(_haptic[event]!);
  }

  /// Starts or stops music to match the setting. Safe to call repeatedly.
  void syncMusic() {
    if (settings.musicOn && !_musicPlaying) {
      _musicPlaying = true;
      sound.startMusic();
    } else if (!settings.musicOn && _musicPlaying) {
      _musicPlaying = false;
      sound.stopMusic();
    }
  }

  void dispose() => settings.removeListener(syncMusic);
}

class NoopSoundPlayer implements SoundPlayer {
  const NoopSoundPlayer();

  @override
  Future<void> playSfx(String file) async {}

  @override
  Future<void> startMusic() async {}

  @override
  Future<void> stopMusic() async {}
}

class NoopHapticsPlayer implements HapticsPlayer {
  const NoopHapticsPlayer();

  @override
  Future<void> play(HapticKind kind) async {}
}

/// Real audio via flame_audio. Failures (blocked autoplay, missing
/// platform support) are swallowed: sound must never break the game.
class FlameSoundPlayer implements SoundPlayer {
  /// Effects play near full volume; music sits quietly underneath.
  static const double _sfxVolume = 0.8;
  static const double _musicVolume = 0.35;

  static const String musicFile = 'music.wav';

  Future<void> preload() async {
    try {
      // Lets the music pause and resume when the app goes to the background.
      FlameAudio.bgm.initialize();
      await FlameAudio.audioCache.loadAll([
        musicFile,
        'exit.wav',
        'blocked.wav',
        'board.wav',
        'depart.wav',
        'win.wav',
        'lose.wav',
        'undo.wav',
        'booster.wav',
      ]);
    } catch (e) {
      debugPrint('Audio preload failed: $e');
    }
  }

  @override
  Future<void> playSfx(String file) async {
    try {
      await FlameAudio.play(file, volume: _sfxVolume);
    } catch (e) {
      debugPrint('SFX failed ($file): $e');
    }
  }

  @override
  Future<void> startMusic() async {
    try {
      await FlameAudio.bgm.play(musicFile, volume: _musicVolume);
    } catch (e) {
      debugPrint('Music failed: $e');
    }
  }

  @override
  Future<void> stopMusic() async {
    try {
      await FlameAudio.bgm.stop();
    } catch (e) {
      debugPrint('Music stop failed: $e');
    }
  }
}

/// Real haptics. A no-op on web, where there is no vibration API we use.
class SystemHapticsPlayer implements HapticsPlayer {
  @override
  Future<void> play(HapticKind kind) async {
    if (kIsWeb) return;
    try {
      switch (kind) {
        case HapticKind.selection:
          await HapticFeedback.selectionClick();
        case HapticKind.light:
          await HapticFeedback.lightImpact();
        case HapticKind.medium:
          await HapticFeedback.mediumImpact();
        case HapticKind.heavy:
          await HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('Haptics failed: $e');
    }
  }
}
