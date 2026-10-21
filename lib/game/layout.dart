import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';

/// Fixed design-space geometry (390x844 portrait).
///
/// Top to bottom: building and HUD, passenger queue, road with the loading
/// lane, the jam, then the booster bar (a Flutter overlay).
class GameLayout {
  GameLayout({
    required this.rows,
    required this.cols,
    required this.laneSlots,
    required this.lockedSlots,
  });

  static const double width = 390;
  static const double height = 844;

  final int rows;
  final int cols;

  /// Open lane slots. Mutable: unlocking a slot adds one mid-level.
  int laneSlots;

  /// Locked placeholders still to unlock, drawn after the open slots.
  int lockedSlots;

  // Queue: starts at the front (left), runs right, then up to the door.
  static const Offset queueFront = Offset(116, 206);
  static const double queueSpacing = 17;
  static const double queueRightX = 304;
  static const double doorY = 138;

  /// How many people fit on the queue path.
  static int get queueVisible =>
      ((queueRightX - queueFront.dx) +
              (queueFront.dy - doorY - _doorClearance)) ~/
          queueSpacing +
      1;

  /// Nobody is drawn closer than this to the depot door.
  static const double _doorClearance = 8;

  /// The lane and the jam span this width, centred on screen.
  static const double contentWidth = 350;
  static const double _sideMargin = (width - contentWidth) / 2;

  /// A jam cell is at most this much wider than a lane bay.
  static const double _maxCellToBay = 1.15;

  static const double roadTop = 240;
  static const double roadHeight = 110;
  static const double laneTop = 250;
  static const double laneHeight = 70;

  /// Centre line of the strip below the bays that vehicles drive along.
  static const double driveY = 336;

  static const double jamTop = 362;
  static const double jamHeight = 386;
  static const double boosterTop = 768;

  /// Jam vehicles are never much wider than a lane bay, so a car looks like
  /// it fits the slot it is driving to.
  late final double cellSize = min(
    min(contentWidth / cols, jamHeight / rows),
    _bayWidth * _maxCellToBay,
  );
  late final Vector2 gridOrigin = Vector2(
    (width - cols * cellSize) / 2,
    jamTop + (jamHeight - rows * cellSize) / 2,
  );
  late final Rect gridRect = Rect.fromLTWH(
    gridOrigin.x,
    gridOrigin.y,
    cols * cellSize,
    rows * cellSize,
  );

  int get slotCount => laneSlots + lockedSlots;

  static const double _gap = 5;

  double get _bayWidth => (contentWidth - _gap * (slotCount - 1)) / slotCount;

  Rect laneSlotRect(int slot) {
    final w = _bayWidth;
    return Rect.fromLTWH(
      _sideMargin + slot * (w + _gap),
      laneTop,
      w,
      laneHeight,
    );
  }

  /// The square of jam cell ([row], [col]).
  Rect cellRect(int row, int col) => Rect.fromLTWH(
    gridOrigin.x + col * cellSize,
    gridOrigin.y + row * cellSize,
    cellSize,
    cellSize,
  );

  /// Where the [i]-th waiting passenger stands (0 = front).
  Offset queuePoint(int i) {
    final d = i * queueSpacing;
    final row = queueRightX - queueFront.dx;
    if (d <= row) return Offset(queueFront.dx + d, queueFront.dy);
    return Offset(queueRightX, queueFront.dy - (d - row));
  }
}
