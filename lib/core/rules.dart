import 'bus.dart';
import 'game_state.dart';

class TapResult {
  const TapResult(this.state, {required this.moved});

  final GameState state;
  final bool moved;
}

/// Pure game rules. No side effects, no randomness.
class Rules {
  const Rules._();

  static bool canExit(GameState s, Bus bus) {
    final path = bus.pathCells(s.rows, s.cols);
    if (path.isEmpty) return true;
    final blocked = <Cell>{
      for (final other in s.buses)
        if (other.id != bus.id) ...other.cells,
    };
    return path.every((c) => !blocked.contains(c));
  }

  static TapResult tap(GameState s, int busId) {
    if (s.status != GameStatus.playing) return TapResult(s, moved: false);
    final bus = s.busById(busId);
    if (bus == null || !canExit(s, bus)) return TapResult(s, moved: false);
    return _exit(s, bus);
  }

  /// The Clear booster: a helicopter lifts any vehicle straight into the
  /// lane, even one that is boxed in. Needs a free lane slot.
  static TapResult airlift(GameState s, int busId) {
    if (s.status != GameStatus.playing) return TapResult(s, moved: false);
    final bus = s.busById(busId);
    if (bus == null) return TapResult(s, moved: false);
    return _exit(s, bus);
  }

  static TapResult _exit(GameState s, Bus bus) {
    final slot = s.lane.indexOf(null);
    if (slot < 0) return TapResult(s, moved: false);

    final lane = [...s.lane];
    lane[slot] = ParkedBus.fromBus(bus);
    final next = board(
      s.copyWith(
        buses: [
          for (final b in s.buses)
            if (b.id != bus.id) b,
        ],
        lane: lane,
        moves: s.moves + 1,
      ),
    );
    return TapResult(next.copyWith(status: evaluate(next)), moved: true);
  }

  /// The queue as the Sort booster leaves it before boarding: passengers
  /// matching a parked vehicle with free seats move to the front. Null if
  /// nobody can be helped.
  static List<int>? sortedQueue(GameState s) {
    if (s.status != GameStatus.playing) return null;
    final pulled = <int>[];
    final rest = [...s.queue];
    for (final p in s.lane) {
      if (p == null || p.isFull) continue;
      var need = p.capacity - p.boarded;
      for (var i = 0; i < rest.length && need > 0;) {
        if (rest[i] == p.colorIndex) {
          pulled.add(rest.removeAt(i));
          need--;
        } else {
          i++;
        }
      }
    }
    return pulled.isEmpty ? null : [...pulled, ...rest];
  }

  /// The Sort booster: passengers whose color matches a parked vehicle with
  /// free seats jump the queue and board it. Null if nobody can be helped.
  static GameState? sortQueue(GameState s) {
    final queue = sortedQueue(s);
    if (queue == null) return null;
    final next = board(s.copyWith(queue: queue));
    return next.copyWith(status: evaluate(next));
  }

  /// Re-derives status from the board; used after taps and booster use.
  static GameStatus evaluate(GameState s) {
    final laneEmpty = s.lane.every((p) => p == null);
    if (s.buses.isEmpty && laneEmpty && s.queue.isEmpty) return GameStatus.won;
    if (s.buses.isEmpty) return GameStatus.lost;
    if (!s.lane.contains(null)) return GameStatus.lost;
    return GameStatus.playing;
  }

  /// Board front-of-queue passengers into the leftmost matching bus until
  /// nobody can board. Full buses depart.
  static GameState board(GameState s) {
    final lane = [...s.lane];
    var qi = 0;
    while (qi < s.queue.length) {
      final color = s.queue[qi];
      final idx = lane.indexWhere(
        (p) => p != null && p.colorIndex == color && !p.isFull,
      );
      if (idx < 0) break;
      final boarded = lane[idx]!.withBoarded(lane[idx]!.boarded + 1);
      lane[idx] = boarded.isFull ? null : boarded;
      qi++;
    }
    return s.copyWith(lane: lane, queue: s.queue.sublist(qi));
  }
}
