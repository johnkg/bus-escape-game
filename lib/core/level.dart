import 'bus.dart';
import 'game_state.dart';

/// Static description of a level; [toState] creates the starting snapshot.
class Level {
  const Level({
    required this.id,
    required this.rows,
    required this.cols,
    required this.buses,
    required this.queue,
    this.laneSlots = defaultLaneSlots,
    this.hint,
    this.shape,
    this.solution,
  });

  factory Level.fromJson(Map<String, dynamic> json) => Level(
    id: json['id'] as int,
    rows: json['rows'] as int,
    cols: json['cols'] as int,
    laneSlots: json['laneSlots'] as int? ?? defaultLaneSlots,
    buses: [
      for (final b in json['buses'] as List)
        Bus.fromJson(b as Map<String, dynamic>),
    ],
    hint: json['hint'] as String?,
    shape: (json['shape'] as List?)?.cast<String>(),
    queue: json.containsKey('queueRuns')
        ? [
            // [[color, count], ...] keeps handmade levels readable.
            for (final run in json['queueRuns'] as List)
              ...List.filled((run as List)[1] as int, run[0] as int),
          ]
        : (json['queue'] as List).cast<int>(),
  );

  /// Lane slots when a level does not say otherwise.
  static const int defaultLaneSlots = 5;

  /// Characters of a [shape] row.
  static const String lotCell = '#';
  static const String offLotCell = '.';

  final int id;
  final int rows;
  final int cols;
  final List<Bus> buses;
  final List<int> queue;
  final int laneSlots;

  /// Short teaching text shown above the board (tutorial levels).
  final String? hint;

  /// Optional lot outline: one string per row, `#` = parking cell, `.` = no
  /// cell. Null means the whole rectangle. Vehicles only sit on `#` cells;
  /// anything else is open ground they can drive across.
  final List<String>? shape;

  /// A known winning tap order (bus ids), when the generator built one.
  /// Not serialized; levels are deterministic so it can be rebuilt.
  final List<int>? solution;

  bool hasCell(int row, int col) => lotHasCell(shape, rows, cols, row, col);

  GameState toState() => GameState(
    rows: rows,
    cols: cols,
    buses: buses,
    lane: List<ParkedBus?>.filled(laneSlots, null),
    queue: queue,
    shape: shape,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'rows': rows,
    'cols': cols,
    'laneSlots': laneSlots,
    'buses': [for (final b in buses) b.toJson()],
    'queue': queue,
    if (hint != null) 'hint': hint,
    if (shape != null) 'shape': shape,
  };
}

/// Whether ([row], [col]) is a parking cell of a [rows] x [cols] lot with
/// the optional outline [shape] (see [Level.shape]).
bool lotHasCell(List<String>? shape, int rows, int cols, int row, int col) {
  if (shape == null) return row >= 0 && row < rows && col >= 0 && col < cols;
  return row >= 0 &&
      row < shape.length &&
      col >= 0 &&
      col < shape[row].length &&
      shape[row][col] == Level.lotCell;
}
