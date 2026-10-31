import 'game_state.dart';
import 'level.dart';
import 'rules.dart';

class SolveResult {
  const SolveResult({required this.order, this.exhausted = false});

  /// Bus ids in tap order, or null if no solution was found.
  final List<int>? order;

  /// True when the search hit its node limit, so a null [order] only means
  /// "not found in time", not "impossible".
  final bool exhausted;
}

/// Depth-first search over tap orders with memoised dead states.
class Solver {
  const Solver._();

  /// A winning tap order for [level]: the generator's built-in one if it has
  /// one, otherwise found by search (fine for small handmade levels).
  static List<int>? orderFor(Level level) =>
      level.solution ?? solve(level.toState()).order;

  /// Default search budget: enough for any generated level.
  static const int defaultMaxNodes = 200000;

  static SolveResult solve(GameState start, {int maxNodes = defaultMaxNodes}) {
    final dead = <String>{};
    final path = <int>[];
    var nodes = 0;

    bool dfs(GameState s) {
      if (s.status == GameStatus.won) return true;
      if (s.status == GameStatus.lost) return false;
      if (dead.contains(s.key)) return false;
      if (++nodes > maxNodes) return false;

      final front = s.queue.isEmpty ? -1 : s.queue.first;
      final options =
          [
            for (final b in s.buses)
              if (Rules.canExit(s, b)) b,
          ]..sort(
            (a, b) =>
                (a.colorIndex == front ? 0 : 1) -
                (b.colorIndex == front ? 0 : 1),
          );

      for (final b in options) {
        path.add(b.id);
        if (dfs(Rules.tap(s, b.id).state)) return true;
        path.removeLast();
      }
      dead.add(s.key);
      return false;
    }

    final ok = dfs(start);
    return SolveResult(
      order: ok ? List.of(path) : null,
      exhausted: nodes > maxNodes,
    );
  }
}
