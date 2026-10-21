import 'dart:math';

import 'bus.dart';
import 'direction.dart';
import 'game_state.dart';
import 'level.dart';
import 'rng.dart';
import 'rules.dart';
import 'vehicle_kind.dart';

class LevelConfig {
  const LevelConfig({
    required this.rows,
    required this.cols,
    required this.fill,
    required this.maxVehicles,
    required this.colorCount,
    required this.laneSlots,
    required this.mix,
    required this.busChance,
    required this.irregular,
    this.longBusChance = 0,
    this.policeChance = 0,
    this.fireChance = 0,
    this.ambulanceChance = 0,
  });

  final int rows;
  final int cols;

  /// Target share of lot cells covered by vehicles (the real count may end
  /// up lower when no more fit).
  final double fill;
  final int maxVehicles;
  final int colorCount;
  final int laneSlots;

  /// 0 = passengers arrive in exit order, 1 = the queue keeps asking for
  /// vehicles that are still stuck in the jam, so the lane fills up.
  final double mix;

  /// Chance a vehicle is a 3-cell coaster rather than a 2-cell sedan.
  final double busChance;

  /// Chance a vehicle is a 5-cell, 10-seat bus.
  final double longBusChance;

  /// Chances a vehicle is a police car (4 seats, police passengers only) or
  /// a fire truck (6 seats, firefighters only).
  final double policeChance;
  final double fireChance;

  /// Chance a vehicle is an ambulance (4 seats, paramedics only).
  final double ambulanceChance;

  /// Whether the lot gets a non-rectangular outline.
  final bool irregular;
}

/// Procedural levels, deterministic per level number.
///
/// 1. Carve the lot outline, then place vehicles in *reverse* exit order:
///    each one needs a clear path past everything placed before it (those
///    leave later), so the jam can always be emptied.
/// 2. Build the passenger queue by actually playing that exit order with the
///    real rules, asking for passengers that either board right away or for
///    a vehicle still in the jam. That makes the level solvable by
///    construction (the exit order is a winning play), with no search.
class LevelGenerator {
  const LevelGenerator._();

  // ---- Difficulty curve ----------------------------------------------
  // Each knob starts at a base value and grows per level up to a cap. The
  // numbers are tuning, not rules: changing any of them changes every
  // generated level.

  /// Lot width grows by one cell every [_growEvery] levels, from
  /// [_minLotSize] up to [_minLotSize] + [_maxLotGrowth]; rows are one more
  /// than columns, capped at [_maxRows].
  static const int _minLotSize = 6;
  static const int _growEvery = 6;
  static const int _maxLotGrowth = 4;
  static const int _maxRows = 10;

  static const double _fillBase = 0.42;
  static const double _fillStep = 0.008;
  static const double _fillMax = 0.7;

  static const int _vehiclesBase = 6;
  static const int _vehiclesMax = 40;

  /// Colors in play: one more every [_growEvery] levels.
  static const int _colorsBase = 3;

  /// From this level on the lane has one slot fewer.
  static const int _shortLaneAfter = 40;
  static const int _laneSlots = 5;
  static const int _shortLaneSlots = 4;

  static const double _mixBase = 0.15;
  static const double _mixStep = 0.012;
  static const double _mixMax = 0.7;

  static const double _coasterBase = 0.3;
  static const double _coasterStep = 0.005;
  static const double _coasterMax = 0.45;

  /// Lots stop being plain rectangles from this level.
  static const int _irregularFrom = 3;

  static const int _busFrom = 4;
  static const double _busBase = 0.06;
  static const double _busStep = 0.002;
  static const double _busMax = 0.14;

  /// Service vehicles: each appears from its own level, starting rare.
  static const int _policeFrom = 12;
  static const int _fireFrom = 20;
  static const int _ambulanceFrom = 28;
  static const double _serviceBase = 0.04;
  static const double _serviceStep = 0.004;
  static const double _policeMax = 0.12;
  static const double _fireMax = 0.1;
  static const double _ambulanceMax = 0.1;

  /// A service chance that is 0 before [from] and then ramps up.
  static double _serviceChance(int n, int from, double max) => n >= from
      ? (_serviceBase + (n - from) * _serviceStep).clamp(_serviceBase, max)
      : 0;

  static LevelConfig configFor(int level) {
    final n = level < 1 ? 1 : level;
    final size = _minLotSize + (n ~/ _growEvery).clamp(0, _maxLotGrowth);
    final rows = min(_maxRows, size + 1);
    final cols = size;
    return LevelConfig(
      rows: rows,
      cols: cols,
      fill: (_fillBase + n * _fillStep).clamp(_fillBase, _fillMax),
      maxVehicles: (_vehiclesBase + n).clamp(_vehiclesBase, _vehiclesMax),
      colorCount: (_colorsBase + n ~/ _growEvery).clamp(
        _colorsBase,
        ordinaryColorCount,
      ),
      laneSlots: n > _shortLaneAfter ? _shortLaneSlots : _laneSlots,
      mix: (_mixBase + n * _mixStep).clamp(_mixBase, _mixMax),
      busChance: (_coasterBase + n * _coasterStep).clamp(
        _coasterBase,
        _coasterMax,
      ),
      irregular: n >= _irregularFrom,
      longBusChance: n >= _busFrom
          ? (_busBase + n * _busStep).clamp(_busBase, _busMax)
          : 0,
      policeChance: _serviceChance(n, _policeFrom, _policeMax),
      fireChance: _serviceChance(n, _fireFrom, _fireMax),
      ambulanceChance: _serviceChance(n, _ambulanceFrom, _ambulanceMax),
    );
  }

  /// Level number -> RNG seed (a prime stride keeps neighbours unrelated).
  static const int _seedStride = 7919;
  static const int _seedOffset = 13;

  /// [difficulty] defaults to [levelNumber]; the repository lowers it so
  /// generated levels start easy after the handmade tutorial.
  static Level generate(int levelNumber, {int? difficulty}) {
    final c = configFor(difficulty ?? levelNumber);
    final rng = Rng(levelNumber * _seedStride + _seedOffset);

    final shape = c.irregular ? _carve(c, rng) : _rect(c);
    final exitOrder = _placeVehicles(c, shape, rng);
    final queue = _buildQueue(c, exitOrder, rng);

    return Level(
      id: levelNumber,
      rows: c.rows,
      cols: c.cols,
      buses: exitOrder,
      queue: queue,
      laneSlots: c.laneSlots,
      shape: shape,
      solution: [for (final b in exitOrder) b.id],
    );
  }

  static List<String> _rect(LevelConfig c) =>
      List.filled(c.rows, Level.lotCell * c.cols);

  /// Outline exponents: 2 is an ellipse, 4 a squircle.
  static const double _minRoundness = 2;
  static const double _roundnessRange = 2;

  /// How far past the unit "circle" a cell may be and still count.
  static const double _outlineSlack = 1.08;

  /// Bites out of the outline: one plus up to [_extraBites] more, each up to
  /// [_biteRows] tall and one plus up to [_extraBiteCols] wide, removing a
  /// cell with probability [_biteChance].
  static const int _extraBites = 1;
  static const int _biteRows = 2;
  static const int _extraBiteCols = 1;
  static const double _biteChance = 0.7;

  /// A rounded blob with a random bite taken out of an edge.
  static List<String> _carve(LevelConfig c, Rng rng) {
    final p = _minRoundness + rng.nextDouble() * _roundnessRange;
    const centre = 0.5; // sample each cell at its middle
    final grid = [
      for (var r = 0; r < c.rows; r++)
        [
          for (var col = 0; col < c.cols; col++)
            (pow(((col + centre) - c.cols / 2).abs() / (c.cols / 2), p) +
                    pow(((r + centre) - c.rows / 2).abs() / (c.rows / 2), p)) <=
                _outlineSlack,
        ],
    ];
    // One or two bites make the outline lopsided.
    for (var b = 0; b < 1 + rng.nextInt(_extraBites + 1); b++) {
      final r0 = rng.nextInt(c.rows - 1);
      final c0 = rng.nextInt(c.cols - 1);
      for (var r = r0; r < min(c.rows, r0 + _biteRows); r++) {
        for (
          var col = c0;
          col < min(c.cols, c0 + 1 + rng.nextInt(_extraBiteCols + 1));
          col++
        ) {
          if (rng.chance(_biteChance)) grid[r][col] = false;
        }
      }
    }
    return [
      for (final row in grid)
        row.map((on) => on ? Level.lotCell : Level.offLotCell).join(),
    ];
  }

  /// Random placements tried per vehicle before the lot counts as full.
  static const int _placementTries = 250;

  /// Vehicles in exit order (index 0 leaves first), ids = exit index.
  static List<Bus> _placeVehicles(LevelConfig c, List<String> shape, Rng rng) {
    bool inShape(int r, int col) => lotHasCell(shape, c.rows, c.cols, r, col);

    final lotCells = shape.fold<int>(
      0,
      (sum, row) => sum + Level.lotCell.allMatches(row).length,
    );
    final occupied = <Cell>{};
    final placed = <Bus>[]; // last-to-exit first

    while (placed.length < c.maxVehicles &&
        occupied.length < lotCells * c.fill) {
      Bus? found;
      for (var t = 0; t < _placementTries && found == null; t++) {
        var length = rng.chance(c.busChance)
            ? VehicleKind.coasterLength
            : VehicleKind.sedanLength;
        if (c.longBusChance > 0 && rng.chance(c.longBusChance)) {
          length = VehicleKind.busLength;
        }
        // Services are a sedan-sized police car or ambulance, or a
        // coaster-sized fire truck; their passengers only board their own
        // vehicle.
        int? service;
        if (c.fireChance > 0 && rng.chance(c.fireChance)) {
          service = fireColor;
          length = VehicleKind.coasterLength;
        } else if (c.policeChance > 0 && rng.chance(c.policeChance)) {
          service = policeColor;
          length = VehicleKind.sedanLength;
        } else if (c.ambulanceChance > 0 && rng.chance(c.ambulanceChance)) {
          service = ambulanceColor;
          length = VehicleKind.sedanLength;
        }
        final dir = Direction.values[rng.nextInt(Direction.values.length)];
        final maxRow = dir.isHorizontal ? c.rows : c.rows - length + 1;
        final maxCol = dir.isHorizontal ? c.cols - length + 1 : c.cols;
        final bus = Bus(
          id: placed.length,
          colorIndex: service ?? rng.nextInt(c.colorCount),
          row: rng.nextInt(maxRow),
          col: rng.nextInt(maxCol),
          length: length,
          dir: dir,
        );
        if (!bus.cells.every((cell) => inShape(cell.$1, cell.$2))) continue;
        if (bus.cells.any(occupied.contains)) continue;
        if (bus.pathCells(c.rows, c.cols).any(occupied.contains)) continue;
        found = bus;
      }
      if (found == null) break; // nothing else fits
      placed.add(found);
      occupied.addAll(found.cells);
    }

    final order = placed.reversed.toList();
    return [
      for (var i = 0; i < order.length; i++)
        Bus(
          id: i,
          colorIndex: order[i].colorIndex,
          row: order[i].row,
          col: order[i].col,
          length: order[i].length,
          dir: order[i].dir,
        ),
    ];
  }

  /// Plays [exitOrder] against the real rules while inventing the queue.
  ///
  /// Each step adds one passenger: either one that boards a vehicle that is
  /// already parked, or one for a vehicle still in the jam (forcing the
  /// player to send out everything up to it first, as far as the lane
  /// allows). Because this uses [Rules] itself, the finished queue is
  /// guaranteed to be won by tapping [exitOrder].
  /// Safety stop for [_buildQueue]; real levels need a few hundred steps.
  static const int _maxQueueSteps = 100000;

  static List<int> _buildQueue(LevelConfig c, List<Bus> exitOrder, Rng rng) {
    var s = GameState(
      rows: c.rows,
      cols: c.cols,
      buses: exitOrder,
      lane: List<ParkedBus?>.filled(c.laneSlots, null),
      queue: const [],
    );
    final queue = <int>[];
    var next = 0; // index in exitOrder of the next vehicle to send out

    List<ParkedBus> parkedWithSeats() => [
      for (final p in s.lane)
        if (p != null && !p.isFull) p,
    ];

    void send() {
      // The queue is built lazily, so the board often looks "lost" (lane
      // full, nobody waiting yet). Ignore that while constructing.
      final r = Rules.tap(
        s.copyWith(status: GameStatus.playing),
        exitOrder[next].id,
      );
      if (!r.moved) {
        throw StateError(
          'Generator could not send vehicle ${exitOrder[next].id}',
        );
      }
      s = r.state;
      next++;
    }

    var guard = 0;
    while ((next < exitOrder.length || parkedWithSeats().isNotEmpty) &&
        guard++ < _maxQueueSteps) {
      final waiting = parkedWithSeats();
      final parkedCount = s.lane.where((p) => p != null).length;
      final room = c.laneSlots - parkedCount; // free slots right now
      final remaining = exitOrder.length - next;

      // Option B: ask for a vehicle still in the jam. Only legal if the
      // lane can hold everything that must leave before it.
      var reach = 0;
      if (remaining > 0 && room > 0) {
        final canGo = min(remaining, room);
        reach = 1 + rng.nextInt(canGo); // exits needed, 1..canGo
      }
      final wantB = reach > 0 && (waiting.isEmpty || rng.chance(c.mix));

      final int color;
      if (wantB) {
        color = exitOrder[next + reach - 1].colorIndex;
      } else if (waiting.isNotEmpty) {
        color = waiting[rng.nextInt(waiting.length)].colorIndex;
      } else {
        break; // nothing left to do
      }

      queue.add(color);
      s = Rules.board(s.copyWith(queue: [...s.queue, color]));
      // If the passenger could not board, play the exits it is waiting on.
      while (s.queue.isNotEmpty && next < exitOrder.length) {
        send();
      }
    }
    return queue;
  }
}
