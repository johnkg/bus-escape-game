import 'bus.dart';
import 'direction.dart';
import 'rng.dart';

/// A vehicle about to be placed: its length, and how to pick its color
/// (called once the direction is drawn, which keeps generated levels
/// identical to earlier versions).
typedef VehicleSpec = ({int length, int Function() pickColor});

/// Tries random positions and directions on a [rows] x [cols] lot until a
/// vehicle fits: every cell is on the lot ([onLot]), none is [occupied],
/// and its way out does not cross an [occupied] cell either. Null if
/// nothing fits in [tries] attempts.
///
/// [spec] is asked afresh on every attempt, so a caller may vary the
/// vehicle between attempts (the level generator does).
///
/// Used both to generate levels and by the Refresh booster; placing
/// vehicles in reverse exit order this way keeps a level winnable.
Bus? placeRandomly({
  required Rng rng,
  required int id,
  required VehicleSpec Function() spec,
  required int rows,
  required int cols,
  required bool Function(int row, int col) onLot,
  required Set<Cell> occupied,
  required int tries,
}) {
  for (var t = 0; t < tries; t++) {
    final (:length, :pickColor) = spec();
    final dir = Direction.values[rng.nextInt(Direction.values.length)];
    final maxRow = dir.isHorizontal ? rows : rows - length + 1;
    final maxCol = dir.isHorizontal ? cols - length + 1 : cols;
    final bus = Bus(
      id: id,
      colorIndex: pickColor(),
      row: rng.nextInt(maxRow),
      col: rng.nextInt(maxCol),
      length: length,
      dir: dir,
    );
    if (!bus.cells.every((cell) => onLot(cell.$1, cell.$2))) continue;
    if (bus.cells.any(occupied.contains)) continue;
    if (bus.pathCells(rows, cols).any(occupied.contains)) continue;
    return bus;
  }
  return null;
}
