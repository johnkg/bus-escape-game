import 'dart:ui';

import 'package:flame/components.dart';

import 'bus_escape_game.dart';
import 'layout.dart';
import 'palette.dart';

/// Ground, depot building and the parking lot under the jam.
class SceneView extends PositionComponent with HasGameReference<BusEscapeGame> {
  SceneView() : super(priority: -10);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, GameLayout.width, GameLayout.height),
      Paint()..color = pavementColor,
    );
    _paintBuilding(canvas);
    _paintLot(canvas);
  }

  void _paintBuilding(Canvas canvas) {
    const body = Rect.fromLTWH(14, 4, 362, 126);
    final r = RRect.fromRectAndRadius(body, const Radius.circular(12));
    canvas.drawRRect(
      r.shift(const Offset(0, 4)),
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawRRect(r, Paint()..color = const Color(0xFFF3F6F9));
    // Roof band.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        const Rect.fromLTWH(14, 4, 362, 26),
        topLeft: const Radius.circular(12),
        topRight: const Radius.circular(12),
      ),
      Paint()..color = const Color(0xFF5D6D80),
    );
    // Windows.
    final glass = Paint()..color = const Color(0xFF8DB4D8);
    for (var i = 0; i < 5; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(30 + i * 52.0, 50, 40, 30),
          const Radius.circular(4),
        ),
        glass,
      );
    }
    // Sign and door the queue walks out of.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(292, 36, 66, 48),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFD9444A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(288, 88, 32, 42),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF55698C),
    );
    canvas.drawRect(
      const Rect.fromLTWH(282, 84, 44, 8),
      Paint()..color = const Color(0xFF3F4E6E),
    );
  }

  /// The lot: one tile per parking cell, so irregular outlines show.
  void _paintLot(Canvas canvas) {
    final l = game.layout;
    final level = game.level;
    final fill = Paint()..color = lotColor;
    final edge = Paint()
      ..color = lotLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rim = Paint()..color = const Color(0x22000000);
    for (var r = 0; r < l.rows; r++) {
      for (var c = 0; c < l.cols; c++) {
        if (!level.hasCell(r, c)) continue;
        final rect = Rect.fromLTWH(
          l.gridOrigin.x + c * l.cellSize,
          l.gridOrigin.y + r * l.cellSize,
          l.cellSize,
          l.cellSize,
        );
        canvas.drawRect(rect.inflate(3).translate(0, 2), rim);
      }
    }
    for (var r = 0; r < l.rows; r++) {
      for (var c = 0; c < l.cols; c++) {
        if (!level.hasCell(r, c)) continue;
        final rect = Rect.fromLTWH(
          l.gridOrigin.x + c * l.cellSize,
          l.gridOrigin.y + r * l.cellSize,
          l.cellSize,
          l.cellSize,
        );
        canvas.drawRect(rect.inflate(0.5), fill);
        canvas.drawRect(rect, edge);
      }
    }
  }
}
