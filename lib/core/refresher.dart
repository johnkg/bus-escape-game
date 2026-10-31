import 'bus.dart';
import 'game_state.dart';
import 'level.dart';
import 'placement.dart';
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

  /// Refresh needs at least this many vehicles to swap around.
  static const int minBuses = 2;

  /// Search budget for finding a winning order to place against.
  static const int _maxNodes = 20000;

  /// Whole re-placements tried before giving up.
  static const int _attempts = 40;

  /// Random spots tried per vehicle within one re-placement.
  static const int _placementTries = 400;

  static RefreshResult? reshuffle(
    GameState s,
    Rng rng, {
    List<int>? fallbackOrder,
  }) {
    if (s.status != GameStatus.playing || s.buses.length < minBuses) {
      return null;
    }
    final order = _winningOrder(s, fallbackOrder);
    if (order == null) return null;

    for (var i = 0; i < _attempts; i++) {
      final placed = _place(s, order, rng);
      if (placed != null) {
        return RefreshResult(s.copyWith(buses: placed), order);
      }
    }
    return null;
  }

  static List<int>? _winningOrder(GameState s, List<int>? fallbackOrder) {
    final found = Solver.solve(s, maxNodes: _maxNodes).order;
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
    bool onLot(int r, int c) => lotHasCell(s.shape, s.rows, s.cols, r, c);

    final byId = {for (final b in s.buses) b.id: b};
    final occupied = <Cell>{};
    final placed = <int, Bus>{};

    for (final id in order.reversed) {
      final original = byId[id]!;
      final found = placeRandomly(
        rng: rng,
        id: id,
        spec: () =>
            (length: original.length, pickColor: () => original.colorIndex),
        rows: s.rows,
        cols: s.cols,
        onLot: onLot,
        occupied: occupied,
        tries: _placementTries,
      );
      if (found == null) return null;
      placed[id] = found;
      occupied.addAll(found.cells);
    }
    return [for (final b in s.buses) placed[b.id]!];
  }
}
