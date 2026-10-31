import 'bus.dart';

enum GameStatus { playing, won, lost }

/// A bus waiting in the loading lane.
class ParkedBus {
  const ParkedBus({
    required this.id,
    required this.colorIndex,
    required this.capacity,
    this.boarded = 0,
  });

  /// [bus] as it pulls into the lane, with every seat empty.
  ParkedBus.fromBus(Bus bus)
    : this(id: bus.id, colorIndex: bus.colorIndex, capacity: bus.capacity);

  final int id;
  final int colorIndex;
  final int capacity;
  final int boarded;

  bool get isFull => boarded >= capacity;

  ParkedBus withBoarded(int n) =>
      ParkedBus(id: id, colorIndex: colorIndex, capacity: capacity, boarded: n);
}

/// Immutable snapshot of a game. Every rule returns a new instance.
class GameState {
  const GameState({
    required this.rows,
    required this.cols,
    required this.buses,
    required this.lane,
    required this.queue,
    this.moves = 0,
    this.status = GameStatus.playing,
    this.shape,
  });

  final int rows;
  final int cols;

  /// Buses still on the grid.
  final List<Bus> buses;

  /// Fixed-size lane; null = free slot.
  final List<ParkedBus?> lane;

  /// Waiting passenger colors; index 0 is the front of the queue.
  final List<int> queue;
  final int moves;
  final GameStatus status;

  /// Lot outline (see [Level.shape]); null = the whole rectangle.
  final List<String>? shape;

  Bus? busById(int id) {
    for (final b in buses) {
      if (b.id == id) return b;
    }
    return null;
  }

  GameState copyWith({
    List<Bus>? buses,
    List<ParkedBus?>? lane,
    List<int>? queue,
    int? moves,
    GameStatus? status,
  }) => GameState(
    rows: rows,
    cols: cols,
    buses: buses ?? this.buses,
    lane: lane ?? this.lane,
    queue: queue ?? this.queue,
    moves: moves ?? this.moves,
    status: status ?? this.status,
    shape: shape,
  );

  /// Identifies the search-relevant part of the state (ignores moves).
  String get key {
    final b = buses.map((e) => e.id).join(',');
    final l = lane
        .map((e) => e == null ? '-' : '${e.id}:${e.boarded}')
        .join(',');
    return '$b|$l|${queue.length}';
  }
}
