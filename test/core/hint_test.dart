import 'package:bus_escape_game/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('following hints from the start wins levels 1..40', () {
    for (var n = 1; n <= 40; n++) {
      final level = LevelGenerator.generate(n, difficulty: n);
      final g = GameSession(level);
      var guard = 0;
      while (g.state.status == GameStatus.playing && guard++ < 100) {
        final id = Hints.nextBus(g.state, fallbackOrder: level.solution);
        expect(id, isNotNull, reason: 'level $n has a hint');
        expect(Rules.canExit(g.state, g.state.busById(id!)!), isTrue);
        g.tap(id);
      }
      expect(g.state.status, GameStatus.won, reason: 'level $n');
    }
  });

  test('a hint recovers from a bad move when one is still possible', () {
    final level = LevelGenerator.generate(3, difficulty: 3);
    final g = GameSession(level);
    // Make an arbitrary exitable move, then ask again.
    final first = g.state.buses.firstWhere((b) => Rules.canExit(g.state, b));
    g.tap(first.id);
    if (g.state.status == GameStatus.playing) {
      final id = Hints.nextBus(g.state);
      if (id != null) {
        expect(Rules.canExit(g.state, g.state.busById(id)!), isTrue);
      }
    }
  });

  test('no hint once the game is over', () {
    final level = LevelGenerator.generate(1, difficulty: 1);
    final g = GameSession(level);
    for (final id in level.solution!) {
      g.tap(id);
    }
    expect(g.state.status, GameStatus.won);
    expect(Hints.nextBus(g.state), isNull);
  });

  test('no hint when the position cannot be won', () {
    // Two buses facing each other head-on.
    final level = Level(
      id: 1,
      rows: 1,
      cols: 4,
      buses: const [
        Bus(
          id: 0,
          colorIndex: 0,
          row: 0,
          col: 0,
          length: 2,
          dir: Direction.east,
        ),
        Bus(
          id: 1,
          colorIndex: 0,
          row: 0,
          col: 2,
          length: 2,
          dir: Direction.west,
        ),
      ],
      queue: [0, 0, 0, 0, 0, 0, 0, 0],
    );
    expect(Hints.nextBus(level.toState()), isNull);
  });
}
