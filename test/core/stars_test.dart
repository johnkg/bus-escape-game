import 'package:bus_escape_game/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Level 2 shape: bus 0 is blocked by bus 1; clearing 1 then 0 wins.
Level level({int slots = 5}) => Level(
  id: 1,
  rows: 4,
  cols: 4,
  laneSlots: slots,
  buses: const [
    Bus(id: 0, colorIndex: 0, row: 1, col: 0, length: 2, dir: Direction.east),
    Bus(id: 1, colorIndex: 1, row: 0, col: 2, length: 2, dir: Direction.south),
  ],
  queue: [1, 1, 1, 1, 0, 0, 0, 0],
);

GameSession played() {
  final g = GameSession(level());
  g.tap(1);
  g.tap(0);
  return g;
}

void main() {
  test('no stars until the level is won', () {
    final g = GameSession(level());
    expect(g.stars, 0);
    g.tap(1);
    expect(g.stars, 0);
  });

  test('a clean win earns 3 stars', () {
    final g = played();
    expect(g.state.status, GameStatus.won);
    expect(g.stars, 3);
    expect(g.blockedTaps, 0);
  });

  test('tapping a blocked bus costs a star', () {
    final g = GameSession(level());
    expect(g.tap(0), isFalse); // blocked by bus 1
    expect(g.blockedTaps, 1);
    g.tap(1);
    g.tap(0);
    expect(g.stars, 2);
  });

  test('taps on missing buses or after the game ends are not mistakes', () {
    final g = GameSession(level());
    g.tap(99);
    expect(g.blockedTaps, 0);
    g.tap(1);
    g.tap(0);
    g.tap(0); // already gone, game over
    expect(g.blockedTaps, 0);
    expect(g.stars, 3);
  });

  test('using undo drops to 1 star', () {
    final g = GameSession(level());
    g.tap(1);
    g.undo();
    expect(g.undos, 1);
    g.tap(1);
    g.tap(0);
    expect(g.stars, 1);
  });

  test('using an extra slot drops to 1 star', () {
    final g = GameSession(level());
    g.addExtraSlot();
    g.tap(1);
    g.tap(0);
    expect(g.stars, 1);
  });

  test('using a hint drops to 1 star', () {
    final g = GameSession(level());
    g.noteHintUsed();
    g.tap(1);
    g.tap(0);
    expect(g.hintsUsed, 1);
    expect(g.stars, 1);
  });

  test('a lost game has no stars', () {
    final g = GameSession(
      Level(
        id: 1,
        rows: 4,
        cols: 4,
        laneSlots: 1,
        buses: const [
          Bus(
            id: 0,
            colorIndex: 0,
            row: 0,
            col: 2,
            length: 2,
            dir: Direction.east,
          ),
        ],
        queue: [5, 5],
      ),
    );
    g.tap(0);
    expect(g.state.status, GameStatus.lost);
    expect(g.stars, 0);
  });
}
