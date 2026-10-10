import 'package:bus_escape_game/core/core.dart';
import 'package:bus_escape_game/game/tap_events.dart';
import 'package:bus_escape_game/services/feedback_service.dart';
import 'package:bus_escape_game/services/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSound implements SoundPlayer {
  final List<String> played = [];
  int musicStarts = 0;
  int musicStops = 0;

  @override
  Future<void> playSfx(String file) async => played.add(file);

  @override
  Future<void> startMusic() async => musicStarts++;

  @override
  Future<void> stopMusic() async => musicStops++;
}

class FakeHaptics implements HapticsPlayer {
  final List<HapticKind> played = [];

  @override
  Future<void> play(HapticKind kind) async => played.add(kind);
}

Future<(FeedbackService, FakeSound, FakeHaptics, ProgressService)> make([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final progress = await ProgressService.load();
  final sound = FakeSound();
  final haptics = FakeHaptics();
  final fb = FeedbackService(
    settings: progress,
    sound: sound,
    haptics: haptics,
  );
  return (fb, sound, haptics, progress);
}

void main() {
  group('FeedbackService.emit', () {
    test('plays sound and haptic for an event', () async {
      final (fb, sound, haptics, _) = await make();
      fb.emit(GameEvent.board);
      expect(sound.played, ['board.wav']);
      expect(haptics.played, [HapticKind.selection]);
    });

    test('every event has a sound file and a haptic', () async {
      final (fb, sound, haptics, _) = await make();
      for (final e in GameEvent.values) {
        fb.emit(e);
      }
      expect(sound.played.length, GameEvent.values.length);
      expect(sound.played.every((f) => f.endsWith('.wav')), isTrue);
      expect(haptics.played.length, GameEvent.values.length);
    });

    test('sound off silences sfx but keeps haptics', () async {
      final (fb, sound, haptics, _) = await make({'sound': false});
      fb.emit(GameEvent.win);
      expect(sound.played, isEmpty);
      expect(haptics.played, isNotEmpty);
    });

    test('haptics off silences haptics but keeps sfx', () async {
      final (fb, sound, haptics, _) = await make({'haptics': false});
      fb.emit(GameEvent.win);
      expect(sound.played, isNotEmpty);
      expect(haptics.played, isEmpty);
    });
  });

  group('FeedbackService music', () {
    test('starts music once when enabled', () async {
      final (fb, sound, _, _) = await make();
      fb.syncMusic();
      fb.syncMusic();
      expect(sound.musicStarts, 1);
    });

    test('does not start when music is off', () async {
      final (fb, sound, _, _) = await make({'music': false});
      fb.syncMusic();
      expect(sound.musicStarts, 0);
    });

    test('toggling the setting starts and stops music', () async {
      final (fb, sound, _, progress) = await make();
      fb.syncMusic();
      await progress.setMusicOn(false);
      expect(sound.musicStops, 1);
      await progress.setMusicOn(true);
      expect(sound.musicStarts, 2);
      fb.dispose();
    });
  });

  group('eventsForMove', () {
    Bus bus(int id, int color, int row) => Bus(
      id: id,
      colorIndex: color,
      row: row,
      col: 0,
      length: 2,
      dir: Direction.east,
    );

    GameState start(List<Bus> buses, List<int> queue, {int slots = 5}) => Level(
      id: 1,
      rows: 4,
      cols: 4,
      buses: buses,
      queue: queue,
      laneSlots: slots,
    ).toState();

    test('plain exit', () {
      final s = start([bus(0, 0, 0), bus(1, 1, 1)], [1, 1, 1, 1, 0, 0, 0, 0]);
      expect(eventsForMove(s, Rules.tap(s, 0).state), [GameEvent.busExit]);
    });

    test('exit with boarding', () {
      final s = start([bus(0, 0, 0), bus(1, 1, 1)], [0, 0, 1, 1, 1, 1, 0, 0]);
      expect(eventsForMove(s, Rules.tap(s, 0).state), [
        GameEvent.busExit,
        GameEvent.board,
      ]);
    });

    test('full bus departs', () {
      final s = start([bus(0, 0, 0), bus(1, 1, 1)], [0, 0, 0, 0, 1, 1, 1, 1]);
      expect(eventsForMove(s, Rules.tap(s, 0).state), [
        GameEvent.busExit,
        GameEvent.board,
        GameEvent.depart,
      ]);
    });

    test('last bus out wins', () {
      final s = start([bus(0, 0, 0)], [0, 0, 0, 0]);
      expect(eventsForMove(s, Rules.tap(s, 0).state), [
        GameEvent.busExit,
        GameEvent.board,
        GameEvent.depart,
        GameEvent.win,
      ]);
    });

    test('full lane loses', () {
      var s = start(
        [bus(0, 0, 0), bus(1, 1, 1), bus(2, 2, 2)],
        [5, 5],
        slots: 2,
      );
      s = Rules.tap(s, 0).state;
      final after = Rules.tap(s, 1).state;
      expect(eventsForMove(s, after), [GameEvent.busExit, GameEvent.lose]);
    });
  });
}
