import 'game_state.dart';
import 'rules.dart';
import 'solver.dart';

class Hints {
  const Hints._();

  /// Id of a bus to tap next, or null if the game is over or the position
  /// can no longer be won.
  ///
  /// Searches for a winning line first. Big levels can outgrow the search
  /// limit; then [fallbackOrder] (the level's known solution) and finally the
  /// first exitable vehicle the front passenger is waiting for are used as a
  /// best guess.
  static int? nextBus(
    GameState s, {
    List<int>? fallbackOrder,
    int maxNodes = 4000,
  }) {
    if (s.status != GameStatus.playing) return null;
    final r = Solver.solve(s, maxNodes: maxNodes);
    if (r.order != null && r.order!.isNotEmpty) return r.order!.first;
    if (!r.exhausted) return null; // proven unwinnable

    for (final id in fallbackOrder ?? const <int>[]) {
      final bus = s.busById(id);
      if (bus != null && Rules.canExit(s, bus)) return id;
    }
    final front = s.queue.isEmpty ? null : s.queue.first;
    final exitable = [
      for (final b in s.buses)
        if (Rules.canExit(s, b)) b,
    ];
    for (final b in exitable) {
      if (b.colorIndex == front) return b.id;
    }
    return exitable.isEmpty ? null : exitable.first.id;
  }
}
