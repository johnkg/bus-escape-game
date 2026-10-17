import 'package:bus_escape_game/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Rng', () {
    test('same seed gives same sequence', () {
      final a = Rng(42);
      final b = Rng(42);
      expect(
        [for (var i = 0; i < 20; i++) a.nextInt(1000)],
        [for (var i = 0; i < 20; i++) b.nextInt(1000)],
      );
    });

    test('different seeds differ', () {
      expect(Rng(1).nextU32(), isNot(Rng(2).nextU32()));
    });
  });

  group('Solver', () {
    test('solves a trivial level', () {
      final level = Level(
        id: 1,
        rows: 4,
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
        ],
        queue: [0, 0, 0, 0],
      );
      final r = Solver.solve(level.toState());
      expect(r.order, [0]);
    });

    test('detects an unsolvable level', () {
      // Two buses facing each other head-on in the same row.
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
      expect(Solver.solve(level.toState()).order, isNull);
    });

    test('solution actually wins when replayed', () {
      final level = Level(
        id: 1,
        rows: 4,
        cols: 4,
        buses: const [
          Bus(
            id: 0,
            colorIndex: 0,
            row: 1,
            col: 0,
            length: 2,
            dir: Direction.east,
          ),
          Bus(
            id: 1,
            colorIndex: 1,
            row: 0,
            col: 2,
            length: 2,
            dir: Direction.south,
          ),
        ],
        queue: [1, 1, 1, 1, 0, 0, 0, 0],
      );
      final order = Solver.solve(level.toState()).order!;
      final session = GameSession(level);
      for (final id in order) {
        expect(session.tap(id), isTrue);
      }
      expect(session.state.status, GameStatus.won);
    });
  });

  group('LevelGenerator', () {
    Level gen(int n) => LevelGenerator.generate(n, difficulty: n);

    test('is deterministic per level number', () {
      expect(gen(12).toJson(), gen(12).toJson());
    });

    test('different level numbers give different levels', () {
      expect(gen(3).toJson(), isNot(gen(4).toJson()));
    });

    test('vehicles stay on lot cells and never overlap', () {
      for (var n = 1; n <= 80; n++) {
        final level = gen(n);
        final seen = <Cell>{};
        for (final b in level.buses) {
          for (final c in b.cells) {
            expect(
              level.hasCell(c.$1, c.$2),
              isTrue,
              reason: 'level $n has a vehicle off the lot',
            );
            expect(seen.add(c), isTrue, reason: 'overlap in level $n');
          }
        }
      }
    });

    test('only sedans, coaster buses and buses; services keep their kind', () {
      var police = 0, fire = 0, ambulance = 0, buses = 0;
      for (var n = 1; n <= 80; n++) {
        for (final b in gen(n).buses) {
          expect([2, 3, 5], contains(b.length), reason: 'level $n');
          if (b.colorIndex == policeColor) {
            police++;
            expect(b.length, 2, reason: 'police car is a sedan (level $n)');
          } else if (b.colorIndex == fireColor) {
            fire++;
            expect(b.length, 3, reason: 'fire truck is 6 seats (level $n)');
          } else if (b.colorIndex == ambulanceColor) {
            ambulance++;
            expect(b.length, 2, reason: 'ambulance is 4 seats (level $n)');
          } else {
            expect(b.colorIndex, lessThan(6), reason: 'level $n');
          }
          if (b.length == 5) buses++;
        }
      }
      expect(police, greaterThan(0));
      expect(fire, greaterThan(0));
      expect(ambulance, greaterThan(0));
      expect(buses, greaterThan(0));
    });

    test('police and fire only turn up on higher levels', () {
      for (var n = 1; n < 12; n++) {
        expect(
          gen(n).buses.any((b) => isServiceColor(b.colorIndex)),
          isFalse,
          reason: 'level $n',
        );
      }
      for (var n = 1; n < 20; n++) {
        expect(
          gen(n).buses.any((b) => b.colorIndex == fireColor),
          isFalse,
          reason: 'level $n',
        );
      }
      for (var n = 1; n < 28; n++) {
        expect(
          gen(n).buses.any((b) => b.colorIndex == ambulanceColor),
          isFalse,
          reason: 'level $n',
        );
      }
    });

    test('service passengers only board their own vehicle', () {
      const sedan = ParkedBus(id: 0, colorIndex: 0, capacity: 4);
      const police = ParkedBus(id: 1, colorIndex: policeColor, capacity: 4);
      GameState state(List<ParkedBus?> lane, List<int> queue) => GameState(
        rows: 2,
        cols: 2,
        buses: const [],
        lane: lane,
        queue: queue,
      );

      // A police officer will not take a seat in an ordinary sedan.
      var s = Rules.board(state([sedan], [policeColor]));
      expect(s.lane[0]!.boarded, 0);
      expect(s.queue, [policeColor]);

      // ...but boards the police car, even when it is parked further along.
      s = Rules.board(state([sedan, police], [policeColor]));
      expect(s.lane[0]!.boarded, 0);
      expect(s.lane[1]!.boarded, 1);
      expect(s.queue, isEmpty);
    });

    test('paramedics only board the ambulance', () {
      const police = ParkedBus(id: 0, colorIndex: policeColor, capacity: 4);
      const ambulance = ParkedBus(
        id: 1,
        colorIndex: ambulanceColor,
        capacity: 4,
      );
      GameState state(List<ParkedBus?> lane, List<int> queue) => GameState(
        rows: 2,
        cols: 2,
        buses: const [],
        lane: lane,
        queue: queue,
      );

      var s = Rules.board(state([police], [ambulanceColor]));
      expect(s.lane[0]!.boarded, 0);
      expect(s.queue, [ambulanceColor]);

      s = Rules.board(state([police, ambulance], [ambulanceColor]));
      expect(s.lane[0]!.boarded, 0);
      expect(s.lane[1]!.boarded, 1);
      expect(s.queue, isEmpty);
    });

    test('vehicle kinds follow length and color', () {
      expect(
        VehicleKind.of(length: 2, colorIndex: 1),
        VehicleKind.sedan,
      );
      expect(VehicleKind.of(length: 3, colorIndex: 4), VehicleKind.coaster);
      expect(VehicleKind.of(length: 5, colorIndex: 0), VehicleKind.bus);
      expect(
        VehicleKind.of(length: 2, colorIndex: policeColor),
        VehicleKind.policeCar,
      );
      expect(
        VehicleKind.of(length: 3, colorIndex: fireColor),
        VehicleKind.fireTruck,
      );
      expect(
        VehicleKind.of(length: 2, colorIndex: ambulanceColor),
        VehicleKind.ambulance,
      );
    });

    test('passenger count equals total seats', () {
      for (var n = 1; n <= 80; n++) {
        final level = gen(n);
        final seats = level.buses.fold<int>(0, (a, b) => a + b.capacity);
        expect(level.queue.length, seats, reason: 'level $n');
      }
    });

    test('tapping the built-in solution wins every level 1..200', () {
      for (var n = 1; n <= 200; n++) {
        final level = gen(n);
        final session = GameSession(level);
        for (final id in level.solution!) {
          expect(session.tap(id), isTrue, reason: 'level $n bus $id');
        }
        expect(session.state.status, GameStatus.won, reason: 'level $n');
      }
    });

    test('later levels are dense, mixed and irregular', () {
      var bigWithHoles = 0;
      for (var n = 20; n <= 60; n++) {
        final level = gen(n);
        final cells = level.shape!.fold<int>(
          0,
          (a, row) => a + '#'.allMatches(row).length,
        );
        final used = level.buses.fold<int>(0, (a, b) => a + b.length);
        expect(used / cells, greaterThan(0.45), reason: 'level $n is sparse');
        expect(
          level.buses.length,
          greaterThanOrEqualTo(15),
          reason: 'level $n',
        );
        expect(level.buses.any((b) => b.length == 2), isTrue);
        expect(level.buses.any((b) => b.length == 3), isTrue);
        if (level.shape!.any((row) => row.contains('.'))) bigWithHoles++;
      }
      expect(bigWithHoles, greaterThan(20)); // most outlines are not rectangles
    });

    test('hard levels make the lane fill up', () {
      // Replaying the solution, the lane should regularly hold several
      // vehicles at once (that is the difficulty).
      var tight = 0;
      for (var n = 40; n <= 80; n++) {
        final level = gen(n);
        final session = GameSession(level);
        var peak = 0;
        for (final id in level.solution!) {
          session.tap(id);
          final parked = session.state.lane.where((p) => p != null).length;
          if (parked > peak) peak = parked;
        }
        if (peak >= level.laneSlots - 1) tight++;
      }
      expect(tight, greaterThan(20));
    });

    test('queue is mixed, not simply in exit order', () {
      var mixed = 0;
      for (var n = 15; n <= 50; n++) {
        final level = gen(n);
        final inExitOrder = [
          for (final b in level.buses) ...List.filled(b.capacity, b.colorIndex),
        ];
        if (level.queue.toString() != inExitOrder.toString()) mixed++;
      }
      expect(mixed, greaterThan(25));
    });

    test('difficulty ramps up', () {
      final early = LevelGenerator.configFor(1);
      final late = LevelGenerator.configFor(80);
      expect(late.maxVehicles, greaterThan(early.maxVehicles));
      expect(late.fill, greaterThan(early.fill));
      expect(late.colorCount, greaterThanOrEqualTo(early.colorCount));
    });

    test('generating is fast', () {
      final sw = Stopwatch()..start();
      for (var n = 1; n <= 100; n++) {
        gen(n);
      }
      expect(sw.elapsedMilliseconds, lessThan(2000));
    });
  });
}
