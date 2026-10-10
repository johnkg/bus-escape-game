import 'package:bus_escape_game/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

Bus bus(int id, int color, int row, int col, Direction dir, {int length = 2}) =>
    Bus(
      id: id,
      colorIndex: color,
      row: row,
      col: col,
      length: length,
      dir: dir,
    );

Level level(List<Bus> buses, List<int> queue, {int slots = 5}) => Level(
  id: 1,
  rows: 4,
  cols: 4,
  buses: buses,
  queue: queue,
  laneSlots: slots,
);

void main() {
  group('Clear (airlift)', () {
    // Bus 0 (red) is blocked by bus 1 (blue).
    Level blocked() => level(
      [bus(0, 0, 1, 0, Direction.east), bus(1, 1, 0, 2, Direction.south)],
      [0, 0, 0, 0, 1, 1, 1, 1],
    );

    test('lifts a blocked vehicle straight into the lane', () {
      final s = blocked().toState();
      expect(Rules.tap(s, 0).moved, isFalse);
      final r = Rules.airlift(s, 0);
      expect(r.moved, isTrue);
      expect(r.state.buses.map((b) => b.id), [1]);
      expect(r.state.moves, 1);
      // Its passengers boarded and it left.
      expect(r.state.queue, [1, 1, 1, 1]);
    });

    test('does nothing when the lane is full or the bus is missing', () {
      final full = level(
        [bus(0, 0, 0, 2, Direction.east), bus(1, 1, 1, 2, Direction.east)],
        [5, 5],
        slots: 1,
      );
      var s = Rules.tap(full.toState(), 0).state; // fills the only slot
      expect(Rules.airlift(s, 1).moved, isFalse);
      expect(Rules.airlift(s, 99).moved, isFalse);
    });
  });

  group('Sort', () {
    test('matching passengers jump the queue and fill parked vehicles', () {
      // Red parks first; the queue starts with blue so nobody boards red.
      var s = level(
        [bus(0, 0, 0, 2, Direction.east), bus(1, 1, 1, 2, Direction.east)],
        [1, 0, 0, 0, 0, 1, 1, 1],
      ).toState();
      s = Rules.tap(s, 0).state;
      expect(s.lane[0]?.boarded, 0);

      final sorted = Rules.sortQueue(s);
      expect(sorted, isNotNull);
      // Four reds jumped ahead, boarded and the red vehicle left.
      expect(sorted!.lane.every((p) => p == null), isTrue);
      expect(sorted.queue, [1, 1, 1, 1]);
    });

    test('only fills the seats that are free', () {
      var s = level(
        [bus(0, 0, 0, 2, Direction.east), bus(1, 1, 1, 2, Direction.east)],
        [1, 0, 0, 0, 0, 0, 0, 1],
      ).toState();
      s = Rules.tap(s, 0).state;
      final sorted = Rules.sortQueue(s)!;
      // Red has 4 seats: exactly four of the six reds jumped.
      expect(sorted.queue.where((c) => c == 0).length, 2);
      expect(sorted.queue.first, 1);
    });

    test('is a no-op (null) when nobody can be helped', () {
      final s = level([bus(0, 0, 0, 2, Direction.east)], [1, 1]).toState();
      expect(Rules.sortQueue(s), isNull); // lane is empty
      final parked = Rules.tap(s, 0).state;
      expect(Rules.sortQueue(parked), isNull); // no red passengers
    });
  });

  group('Session boosters', () {
    Level blockedLevel() => level(
      [bus(0, 0, 1, 0, Direction.east), bus(1, 1, 0, 2, Direction.south)],
      [1, 1, 1, 1, 0, 0, 0, 0],
    );

    test('clear costs the star bonus and can be undone', () {
      final g = GameSession(blockedLevel());
      expect(g.clear(0), isTrue);
      expect(g.helpUsed, 1);
      expect(g.undo(), isTrue);
      expect(g.state.buses.length, 2);
    });

    test('a won game that used any booster has 1 star', () {
      final g = GameSession(blockedLevel());
      g.clear(0);
      g.tap(1);
      expect(g.state.status, GameStatus.won);
      expect(g.stars, 1);
    });

    test('sort counts as help and is undoable', () {
      var g = GameSession(
        level(
          [bus(0, 0, 0, 2, Direction.east), bus(1, 1, 1, 2, Direction.east)],
          [1, 0, 0, 0, 0, 1, 1, 1],
        ),
      );
      g.tap(0);
      expect(g.sort(), isTrue);
      expect(g.helpUsed, 1);
      expect(g.undo(), isTrue);
      expect(g.state.lane[0]?.boarded, 0);
    });

    test('sort that changes nothing is not spent', () {
      final g = GameSession(blockedLevel());
      expect(g.sort(), isFalse);
      expect(g.helpUsed, 0);
      expect(g.canUndo, isFalse);
    });
  });

  group('Refresh', () {
    test('keeps the same vehicles but moves them, still winnable', () {
      for (var n = 1; n <= 40; n++) {
        final lv = LevelGenerator.generate(n, difficulty: n);
        final s = lv.toState();
        final r = Refresher.reshuffle(s, Rng(n), fallbackOrder: lv.solution);
        expect(r, isNotNull, reason: 'level $n could not refresh');

        // Same vehicles (id, color, length), unique cells, inside the lot.
        expect(
          r!.state.buses.map((b) => (b.id, b.colorIndex, b.length)).toSet(),
          s.buses.map((b) => (b.id, b.colorIndex, b.length)).toSet(),
        );
        final seen = <Cell>{};
        for (final b in r.state.buses) {
          for (final c in b.cells) {
            expect(lv.hasCell(c.$1, c.$2), isTrue, reason: 'level $n off lot');
            expect(seen.add(c), isTrue, reason: 'level $n overlap');
          }
        }

        // The order it promises really wins from the new layout.
        final g = GameSession(
          Level(
            id: 1,
            rows: lv.rows,
            cols: lv.cols,
            buses: r.state.buses,
            queue: s.queue,
            laneSlots: lv.laneSlots,
            shape: lv.shape,
          ),
        );
        for (final id in r.order) {
          expect(g.tap(id), isTrue, reason: 'level $n bus $id');
        }
        expect(g.state.status, GameStatus.won, reason: 'level $n');
      }
    });

    test('actually changes the layout on a big level', () {
      final lv = LevelGenerator.generate(40, difficulty: 40);
      final s = lv.toState();
      final r = Refresher.reshuffle(s, Rng(7), fallbackOrder: lv.solution)!;
      final before = {for (final b in s.buses) b.id: (b.row, b.col, b.dir)};
      final moved = r.state.buses
          .where((b) => before[b.id] != (b.row, b.col, b.dir))
          .length;
      expect(moved, greaterThan(s.buses.length ~/ 2));
    });

    test('works mid-game and keeps lane, queue and moves', () {
      final lv = LevelGenerator.generate(30, difficulty: 30);
      final g = GameSession(lv);
      for (final id in lv.solution!.take(5)) {
        g.tap(id);
      }
      final before = g.state;
      expect(g.refresh(Rng(3), fallbackOrder: lv.solution), isTrue);
      expect(g.state.lane.map((p) => p?.id), before.lane.map((p) => p?.id));
      expect(g.state.queue, before.queue);
      expect(g.state.buses.length, before.buses.length);
      expect(g.helpUsed, 1);
      expect(g.undo(), isTrue);
      expect(
        g.state.buses.map((b) => (b.id, b.row, b.col)).toList(),
        before.buses.map((b) => (b.id, b.row, b.col)).toList(),
      );
    });

    test('refuses when there is nothing to shuffle', () {
      final lv = level([bus(0, 0, 0, 2, Direction.east)], [0, 0, 0, 0]);
      final g = GameSession(lv);
      expect(g.refresh(Rng(1)), isFalse);
      expect(g.helpUsed, 0);
    });
  });
}
