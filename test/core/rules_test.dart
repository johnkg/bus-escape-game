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

GameState state(
  List<Bus> buses,
  List<int> queue, {
  int rows = 4,
  int cols = 4,
  int slots = 5,
}) => Level(
  id: 1,
  rows: rows,
  cols: cols,
  buses: buses,
  queue: queue,
  laneSlots: slots,
).toState();

void main() {
  group('Bus geometry', () {
    test('cells and path for each direction', () {
      final e = bus(0, 0, 1, 0, Direction.east);
      expect(e.cells, [(1, 0), (1, 1)]);
      expect(e.pathCells(4, 4), [(1, 2), (1, 3)]);

      final w = bus(0, 0, 1, 2, Direction.west);
      expect(w.pathCells(4, 4), [(1, 1), (1, 0)]);

      final s = bus(0, 0, 0, 2, Direction.south, length: 3);
      expect(s.cells, [(0, 2), (1, 2), (2, 2)]);
      expect(s.pathCells(4, 4), [(3, 2)]);

      final n = bus(0, 0, 2, 1, Direction.north);
      expect(n.pathCells(4, 4), [(1, 1), (0, 1)]);
    });

    test('bus at the edge has an empty path', () {
      final b = bus(0, 0, 0, 2, Direction.east);
      expect(b.pathCells(4, 4), isEmpty);
    });

    test('capacity scales with length', () {
      expect(bus(0, 0, 0, 0, Direction.east).capacity, 4);
      expect(bus(0, 0, 0, 0, Direction.east, length: 3).capacity, 6);
    });
  });

  group('Exit rule', () {
    test('free path can exit', () {
      final s = state([bus(0, 0, 0, 0, Direction.east)], [0, 0, 0, 0]);
      expect(Rules.canExit(s, s.buses.first), isTrue);
    });

    test('blocked bus cannot exit, tap changes nothing', () {
      final s = state(
        [bus(0, 0, 0, 0, Direction.east), bus(1, 1, 0, 2, Direction.south)],
        [0, 0, 0, 0, 1, 1, 1, 1],
      );
      final r = Rules.tap(s, 0);
      expect(r.moved, isFalse);
      expect(r.state, same(s));
      expect(r.state.moves, 0);
    });

    test('unblocking lets the bus out', () {
      var s = state(
        [bus(0, 0, 0, 0, Direction.east), bus(1, 1, 0, 2, Direction.south)],
        [1, 1, 1, 1, 0, 0, 0, 0],
      );
      s = Rules.tap(s, 1).state;
      final r = Rules.tap(s, 0);
      expect(r.moved, isTrue);
      expect(r.state.moves, 2);
    });
  });

  group('Lane and boarding', () {
    test('exited bus parks in first free slot', () {
      final s = state([bus(0, 0, 0, 0, Direction.east)], [9]);
      final r = Rules.tap(s, 0).state;
      expect(r.buses, isEmpty);
      expect(r.lane[0]?.id, 0);
      expect(r.lane[1], isNull);
    });

    test('front passenger boards the matching parked bus', () {
      final s = state([bus(0, 0, 0, 0, Direction.east)], [0, 0]);
      final r = Rules.tap(s, 0).state;
      expect(r.lane[0]?.boarded, 2);
      expect(r.queue, isEmpty);
    });

    test('passenger waits when front color does not match', () {
      final s = state([bus(0, 0, 0, 0, Direction.east)], [1, 0]);
      final r = Rules.tap(s, 0).state;
      expect(r.lane[0]?.boarded, 0);
      expect(r.queue, [1, 0]);
    });

    test('boards the leftmost matching bus', () {
      var s = state(
        [
          bus(0, 0, 0, 0, Direction.east),
          bus(1, 0, 1, 0, Direction.east),
          bus(2, 1, 2, 0, Direction.east),
        ],
        [1, 0, 0],
      );
      s = Rules.tap(s, 0).state;
      s = Rules.tap(s, 1).state;
      expect(s.lane[0]?.boarded, 0);
      expect(s.lane[1]?.boarded, 0);
      s = Rules.tap(s, 2).state; // color 1 boards, then color 0 unblocks
      expect(s.lane[0]?.boarded, 2); // leftmost gets both
      expect(s.lane[1]?.boarded, 0);
    });

    test('full bus departs and frees its slot', () {
      final s = state(
        [bus(0, 0, 0, 0, Direction.east), bus(1, 1, 1, 0, Direction.east)],
        [0, 0, 0, 0, 1, 1, 1, 1],
      );
      var r = Rules.tap(s, 0).state;
      expect(r.lane.every((p) => p == null), isTrue);
      expect(r.status, GameStatus.playing);
      r = Rules.tap(r, 1).state;
      expect(r.status, GameStatus.won);
    });
  });

  group('Win and lose', () {
    test('lose when lane is full and nobody can board', () {
      var s = state(
        [
          bus(0, 0, 0, 0, Direction.east),
          bus(1, 1, 1, 0, Direction.east),
          bus(2, 2, 2, 0, Direction.east),
        ],
        [5, 5],
        slots: 2,
      );
      s = Rules.tap(s, 0).state;
      expect(s.status, GameStatus.playing);
      s = Rules.tap(s, 1).state;
      expect(s.status, GameStatus.lost);
    });

    test('taps are ignored once the game is over', () {
      var s = state(
        [
          bus(0, 0, 0, 0, Direction.east),
          bus(1, 1, 1, 0, Direction.east),
          bus(2, 2, 2, 0, Direction.east),
        ],
        [5, 5],
        slots: 2,
      );
      s = Rules.tap(Rules.tap(s, 0).state, 1).state;
      final r = Rules.tap(s, 2);
      expect(r.moved, isFalse);
    });
  });

  group('Session: undo and extra slot', () {
    GameSession session() => GameSession(
      Level(
        id: 1,
        rows: 4,
        cols: 4,
        buses: [
          bus(0, 0, 0, 0, Direction.east),
          bus(1, 1, 1, 0, Direction.east),
          bus(2, 2, 2, 0, Direction.east),
        ],
        queue: [5, 5],
        laneSlots: 2,
      ),
    );

    test('undo restores previous snapshot', () {
      final g = session();
      g.tap(0);
      expect(g.state.moves, 1);
      expect(g.undo(), isTrue);
      expect(g.state.moves, 0);
      expect(g.state.buses.length, 3);
      expect(g.undo(), isFalse);
    });

    test('blocked/ignored taps do not create undo entries', () {
      final g = session();
      g.tap(99);
      expect(g.canUndo, isFalse);
    });

    test('extra slot rescues a lost game', () {
      final g = session();
      g.tap(0);
      g.tap(1);
      expect(g.state.status, GameStatus.lost);
      g.addExtraSlot();
      expect(g.state.status, GameStatus.playing);
      expect(g.state.lane.length, 3);
    });

    test('extra slots are capped per level', () {
      final g = session();
      for (var i = 0; i < GameSession.maxExtraSlots; i++) {
        expect(g.addExtraSlot(), isTrue);
      }
      expect(g.addExtraSlot(), isFalse);
      expect(g.state.lane.length, 2 + GameSession.maxExtraSlots);
      expect(g.extraSlots, GameSession.maxExtraSlots);
    });

    test('undo keeps the extra slot', () {
      final g = session();
      g.addExtraSlot();
      g.tap(0);
      g.undo();
      expect(g.state.lane.length, 3);
    });
  });
}
