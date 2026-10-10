import 'bus.dart';
import 'direction.dart';
import 'game_state.dart';
import 'rng.dart';
import 'rules.dart';
import 'solver.dart';

class RefreshResult {
  const RefreshResult(this.state, this.order);

  /// The state with the remaining vehicles in new places.
  final GameState state;

  /// A tap order that wins from [state] (proof the shuffle is fair).
  final List<int> order;
}

/// The Refresh booster: re-place every vehicle still in the jam.
///
/// Lane, queue and the vehicles themselves stay as they are; only positions
/// and directions change. To keep the level winnable it first finds a
/// winning order for the *current* state (search, or [fallbackOrder] if the
/// search runs out), then places vehicles in reverse of that order so each
/// has a clear way out once the ones before it are gone.
class Refresher {
  const Refresher._();

  static RefreshResult? reshuffle(
    GameState s,
    Rng rng, {
    List<int>? fallbackOrder,
    int maxNodes = 20000,
    int attempts = 40,
  }) {
    if (s.status != GameStatus.playing || s.buses.length < 2) return null;
    final order = _winningOrder(s, fallbackOrder, maxNodes);
    if (order == null) return null;

    for (var i = 0; i < attempts; i++) {
      final placed = _place(s, order, rng);
      if (placed != null) {
        return RefreshResult(s.copyWith(buses: placed), order);
      }
    }
    return null;
  }

  static List<int>? _winningOrder(
    GameState s,
    List<int>? fallbackOrder,
    int maxNodes,
  ) {
    final found = Solver.solve(s, maxNodes: maxNodes).order;
    if (found != null && _wins(s, found)) return found;
    if (fallbackOrder != null) {
      final remaining = {for (final b in s.buses) b.id};
      final filtered = [
        for (final id in fallbackOrder)
          if (remaining.contains(id)) id,
      ];
      if (filtered.length == remaining.length && _wins(s, filtered)) {
        return filtered;
      }
    }
    return null;
  }

  /// Would sending vehicles out in [order] win, ignoring where they sit?
  static bool _wins(GameState s, List<int> order) {
    var cur = s;
    for (final id in order) {
      final r = Rules.airlift(cur, id);
      if (!r.moved) return false;
      cur = r.state;
    }
    return cur.status == GameStatus.won;
  }

  static List<Bus>? _place(GameState s, List<int> order, Rng rng) {
    bool inLot(int r, int c) {
      final shape = s.shape;
      if (shape == null) return r >= 0 && r < s.rows && c >= 0 && c < s.cols;
      return r >= 0 &&
          r < shape.length &&
          c >= 0 &&
          c < shape[r].length &&
          shape[r][c] == '#';
    }

    final original = {for (final b in s.buses) b.id: b};
    final occupied = <Cell>{};
    final placed = <int, Bus>{};

    for (final id in order.reversed) {
      final o = original[id]!;
      Bus? found;
      for (var t = 0; t < 400 && found == null; t++) {
        final dir = Direction.values[rng.nextInt(4)];
        final maxRow = dir.isHorizontal ? s.rows : s.rows - o.length + 1;
        final maxCol = dir.isHorizontal ? s.cols - o.length + 1 : s.cols;
        final bus = Bus(
          id: o.id,
          colorIndex: o.colorIndex,
          row: rng.nextInt(maxRow),
          col: rng.nextInt(maxCol),
          length: o.length,
          dir: dir,
        );
        if (!bus.cells.every((c) => inLot(c.$1, c.$2))) continue;
        if (bus.cells.any(occupied.contains)) continue;
        if (bus.pathCells(s.rows, s.cols).any(occupied.contains)) continue;
        found = bus;
      }
      if (found == null) return null;
      placed[id] = found;
      occupied.addAll(found.cells);
    }
    return [for (final b in s.buses) placed[b.id]!];
  }
}
