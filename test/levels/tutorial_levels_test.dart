import 'package:bus_escape_game/core/core.dart';
import 'package:bus_escape_game/levels/level_repository.dart';
import 'package:bus_escape_game/levels/tutorial_levels.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final levels = TutorialLevels.all;

  test('there are 10 tutorial levels numbered 1..10', () {
    expect(levels.length, 10);
    expect([for (final l in levels) l.id], [for (var i = 1; i <= 10; i++) i]);
  });

  test('every tutorial level has a hint', () {
    for (final l in levels) {
      expect(l.hint, isNotNull, reason: 'level ${l.id}');
      expect(l.hint!.trim(), isNotEmpty, reason: 'level ${l.id}');
    }
  });

  test('buses are in bounds, never overlap, ids are unique', () {
    for (final l in levels) {
      final seen = <Cell>{};
      final ids = <int>{};
      for (final b in l.buses) {
        expect(ids.add(b.id), isTrue, reason: 'dup id in level ${l.id}');
        for (final c in b.cells) {
          expect(
            c.$1,
            inInclusiveRange(0, l.rows - 1),
            reason: 'level ${l.id}',
          );
          expect(
            c.$2,
            inInclusiveRange(0, l.cols - 1),
            reason: 'level ${l.id}',
          );
          expect(seen.add(c), isTrue, reason: 'overlap in level ${l.id}');
        }
      }
    }
  });

  test('passenger count equals total seats', () {
    for (final l in levels) {
      final seats = l.buses.fold<int>(0, (a, b) => a + b.capacity);
      expect(l.queue.length, seats, reason: 'level ${l.id}');
    }
  });

  test('every tutorial level is solvable', () {
    for (final l in levels) {
      expect(
        Solver.solve(l.toState()).order,
        isNotNull,
        reason: 'level ${l.id}',
      );
    }
  });

  group('each level teaches what its hint says', () {
    Level lv(int n) => levels[n - 1];

    test('1: nothing is blocked', () {
      final s = lv(1).toState();
      expect(s.buses.every((b) => Rules.canExit(s, b)), isTrue);
    });

    test('2: a bus starts out blocked', () {
      final s = lv(2).toState();
      expect(s.buses.any((b) => !Rules.canExit(s, b)), isTrue);
      expect(s.buses.any((b) => Rules.canExit(s, b)), isTrue);
    });

    test('4: the lane is small and a wrong order loses', () {
      final l = lv(4);
      expect(l.laneSlots, 3);
      final front = l.queue.first;
      final wrong = [
        for (final b in l.buses)
          if (b.colorIndex != front) b.id,
      ];
      final g = GameSession(l);
      for (final id in wrong) {
        g.tap(id);
      }
      expect(g.state.status, GameStatus.lost);
    });

    test('5: a mistake can be undone back to a winnable state', () {
      final g = GameSession(lv(5));
      final solution = Solver.solve(g.state).order!;
      final mistake = g.state.buses
          .firstWhere(
            (b) =>
                Rules.canExit(g.state, b) &&
                b.id != solution.first &&
                b.colorIndex != g.state.queue.first,
          )
          .id;
      g.tap(mistake);
      expect(g.undo(), isTrue);
      expect(Solver.solve(g.state).order, isNotNull);
    });

    test('6: the lane is tight (2 slots)', () {
      expect(lv(6).laneSlots, 2);
    });

    test('10: final test has the smallest lane', () {
      expect(lv(10).laneSlots, 3);
    });
  });

  group('LevelRepository', () {
    test('serves handmade levels first, generated afterwards', () {
      expect(LevelRepository.levelFor(1).toJson(), levels[0].toJson());
      expect(LevelRepository.levelFor(10).toJson(), levels[9].toJson());
      final gen = LevelRepository.levelFor(11);
      expect(gen.id, 11);
      expect(gen.hint, isNull);
    });

    test('generated levels start easy after the tutorial', () {
      final first = LevelRepository.levelFor(11);
      final easy = LevelGenerator.configFor(1);
      expect(first.buses.length, lessThanOrEqualTo(easy.maxVehicles));
      expect(first.rows, easy.rows);
    });

    test('levels 1..80 are all winnable and deterministic', () {
      for (var n = 1; n <= 80; n++) {
        final a = LevelRepository.levelFor(n);
        expect(Solver.orderFor(a), isNotNull, reason: 'level $n');
        expect(a.toJson(), LevelRepository.levelFor(n).toJson());
      }
    });
  });

  test('replaying a winning order wins levels 1..60 end to end', () {
    for (var n = 1; n <= 60; n++) {
      final level = LevelRepository.levelFor(n);
      final order = Solver.orderFor(level)!;
      final g = GameSession(level);
      for (final id in order) {
        expect(g.tap(id), isTrue, reason: 'level $n bus $id');
      }
      expect(g.state.status, GameStatus.won, reason: 'level $n');
      expect(g.state.moves, level.buses.length, reason: 'level $n');
    }
  });

  group('Level JSON', () {
    test('queueRuns expands to a flat queue', () {
      final l = Level.fromJson({
        'id': 1,
        'rows': 2,
        'cols': 2,
        'buses': <Map<String, dynamic>>[],
        'queueRuns': [
          [0, 2],
          [1, 3],
        ],
      });
      expect(l.queue, [0, 0, 1, 1, 1]);
    });

    test('hint round-trips', () {
      final l = Level.fromJson({
        'id': 1,
        'rows': 2,
        'cols': 2,
        'hint': 'hello',
        'buses': <Map<String, dynamic>>[],
        'queue': <int>[],
      });
      expect(Level.fromJson(l.toJson()).hint, 'hello');
    });
  });

  test('the daily level is the same all day, differs by day, and is solvable',
      () {
    final a = LevelRepository.dailyLevel(DateTime(2026, 10, 19, 8));
    final b = LevelRepository.dailyLevel(DateTime(2026, 10, 19, 23));
    expect(a.toJson(), b.toJson());
    expect(
      a.toJson(),
      isNot(LevelRepository.dailyLevel(DateTime(2026, 10, 20)).toJson()),
    );
    for (var d = 0; d < 14; d++) {
      final level = LevelRepository.dailyLevel(DateTime(2026, 10, 1 + d));
      expect(Solver.solve(level.toState()).order, isNotNull, reason: 'day $d');
    }
  });

  test('every fifth level after the tutorial is timed', () {
    expect(
      [for (var n = 1; n <= 30; n++) if (LevelRepository.isTimed(n)) n],
      [13, 18, 23, 28],
    );
    expect(LevelRepository.timeLimitFor(3, LevelRepository.levelFor(3)), isNull);
    final level = LevelRepository.levelFor(13);
    expect(
      LevelRepository.timeLimitFor(13, level),
      20 + 6.0 * level.buses.length,
    );
  });
}
