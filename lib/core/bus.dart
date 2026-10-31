import 'direction.dart';

/// (row, col) on the grid.
typedef Cell = (int, int);

class Bus {
  const Bus({
    required this.id,
    required this.colorIndex,
    required this.row,
    required this.col,
    required this.length,
    required this.dir,
  });

  factory Bus.fromJson(Map<String, dynamic> json) => Bus(
    id: json['id'] as int,
    colorIndex: json['color'] as int,
    row: json['row'] as int,
    col: json['col'] as int,
    length: json['length'] as int,
    dir: Direction.values.byName(json['dir'] as String),
  );

  static const int seatsPerCell = 2;

  final int id;
  final int colorIndex;

  /// Top-left cell of the bus.
  final int row;
  final int col;
  final int length;
  final Direction dir;

  int get capacity => length * seatsPerCell;

  Bus copyWith({int? id, int? row, int? col, Direction? dir}) => Bus(
    id: id ?? this.id,
    colorIndex: colorIndex,
    row: row ?? this.row,
    col: col ?? this.col,
    length: length,
    dir: dir ?? this.dir,
  );

  List<Cell> get cells => [
    for (var i = 0; i < length; i++)
      dir.isHorizontal ? (row, col + i) : (row + i, col),
  ];

  /// The cell at the nose of the bus.
  Cell get front => switch (dir) {
    Direction.east => (row, col + length - 1),
    Direction.south => (row + length - 1, col),
    Direction.west || Direction.north => (row, col),
  };

  /// Cells from just in front of the bus to the grid edge.
  List<Cell> pathCells(int rows, int cols) {
    final out = <Cell>[];
    var r = front.$1 + dir.dRow;
    var c = front.$2 + dir.dCol;
    while (r >= 0 && r < rows && c >= 0 && c < cols) {
      out.add((r, c));
      r += dir.dRow;
      c += dir.dCol;
    }
    return out;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'color': colorIndex,
    'row': row,
    'col': col,
    'length': length,
    'dir': dir.name,
  };
}
