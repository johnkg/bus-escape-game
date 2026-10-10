/// Facing direction of a bus. Row 0 is the top of the grid.
enum Direction {
  north(-1, 0),
  south(1, 0),
  east(0, 1),
  west(0, -1);

  const Direction(this.dRow, this.dCol);

  final int dRow;
  final int dCol;

  bool get isHorizontal => this == east || this == west;
}
