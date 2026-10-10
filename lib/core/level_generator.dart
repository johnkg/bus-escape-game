import 'dart:math';

import 'bus.dart';
import 'direction.dart';
import 'game_state.dart';
import 'level.dart';
import 'rng.dart';
import 'rules.dart';

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

  /// Chance a vehicle is a 3-cell bus rather than a 2-cell car.
  final double busChance;

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

  static LevelConfig configFor(int level) {
    final n = level < 1 ? 1 : level;
    final size = 6 + (n ~/ 6).clamp(0, 4); // 6 .. 10
    final rows = min(10, size + 1);
    final cols = size;
    return LevelConfig(
      rows: rows,
      cols: cols,
      fill: (0.42 + n * 0.008).clamp(0.42, 0.7),
      maxVehicles: (6 + n).clamp(6, 40),
      colorCount: (3 + n ~/ 6).clamp(3, 6),
      laneSlots: n > 40 ? 4 : 5,
      mix: (0.15 + n * 0.012).clamp(0.15, 0.7),
      busChance: (0.3 + n * 0.005).clamp(0.3, 0.45),
      irregular: n >= 3,
    );
  }

  /// [difficulty] defaults to [levelNumber]; the repository lowers it so
  /// generated levels start easy after the handmade tutorial.
  static Level generate(int levelNumber, {int? difficulty}) {
    final c = configFor(difficulty ?? levelNumber);
    final rng = Rng(levelNumber * 7919 + 13);

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

  static List<String> _rect(LevelConfig c) => List.filled(c.rows, '#' * c.cols);

  /// A rounded blob with a random bite taken out of an edge.
  static List<String> _carve(LevelConfig c, Rng rng) {
    final p = 2.0 + rng.nextDouble() * 2.0; // 2 = ellipse, 4 = squircle
    final grid = [
      for (var r = 0; r < c.rows; r++)
        [
          for (var col = 0; col < c.cols; col++)
            (pow(((col + 0.5) - c.cols / 2).abs() / (c.cols / 2), p) +
                    pow(((r + 0.5) - c.rows / 2).abs() / (c.rows / 2), p)) <=
                1.08,
        ],
    ];
    // One or two bites make the outline lopsided.
    for (var b = 0; b < 1 + rng.nextInt(2); b++) {
      final r0 = rng.nextInt(c.rows - 1);
      final c0 = rng.nextInt(c.cols - 1);
      for (var r = r0; r < min(c.rows, r0 + 2); r++) {
        for (var col = c0; col < min(c.cols, c0 + 1 + rng.nextInt(2)); col++) {
          if (rng.chance(0.7)) grid[r][col] = false;
        }
      }
    }
    return [for (final row in grid) row.map((on) => on ? '#' : '.').join()];
  }

  /// Vehicles in exit order (index 0 leaves first), ids = exit index.
  static List<Bus> _placeVehicles(LevelConfig c, List<String> shape, Rng rng) {
    bool inShape(int r, int col) =>
        r >= 0 &&
        r < shape.length &&
        col >= 0 &&
        col < shape[r].length &&
        shape[r][col] == '#';

    final lotCells = shape.fold<int>(
      0,
      (sum, row) => sum + '#'.allMatches(row).length,
    );
    final occupied = <Cell>{};
    final placed = <Bus>[]; // last-to-exit first

    while (placed.length < c.maxVehicles &&
        occupied.length < lotCells * c.fill) {
      Bus? found;
      for (var t = 0; t < 250 && found == null; t++) {
        final length = rng.chance(c.busChance) ? 3 : 2;
        final dir = Direction.values[rng.nextInt(4)];
        final maxRow = dir.isHorizontal ? c.rows : c.rows - length + 1;
        final maxCol = dir.isHorizontal ? c.cols - length + 1 : c.cols;
        final bus = Bus(
          id: placed.length,
          colorIndex: rng.nextInt(c.colorCount),
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
        guard++ < 100000) {
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
