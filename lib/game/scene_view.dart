import 'dart:ui';

import 'package:flame/components.dart';

import 'bus_escape_game.dart';
import 'layout.dart';
import 'palette.dart';
import 'layers.dart';

/// Ground, depot building and the parking lot under the jam.
class SceneView extends PositionComponent with HasGameReference<BusEscapeGame> {
  SceneView() : super(priority: Layer.scene);

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, GameLayout.width, GameLayout.height),
      Paint()..color = pavementColor,
    );
    _paintBuilding(canvas);
    _paintLot(canvas);
  }

  // The depot building at the top of the screen, in design pixels.
  static const Rect _building = Rect.fromLTWH(14, 4, 362, 126);
  static const double _roofHeight = 26;
  static const double _buildingRadius = 12;
  static const Offset _buildingShadow = Offset(0, 4);
  static const int _windowCount = 5;
  static const Rect _firstWindow = Rect.fromLTWH(30, 50, 40, 30);
  static const double _windowPitch = 52;
  static const double _windowRadius = 4;
  static const Rect _sign = Rect.fromLTWH(292, 36, 66, 48);
  static const double _signRadius = 6;
  static const Rect _door = Rect.fromLTWH(288, 88, 32, 42);
  static const double _doorRadius = 4;
  static const Rect _awning = Rect.fromLTWH(282, 84, 44, 8);

  void _paintBuilding(Canvas canvas) {
    final r = RRect.fromRectAndRadius(
      _building,
      const Radius.circular(_buildingRadius),
    );
    canvas.drawRRect(
      r.shift(_buildingShadow),
      Paint()..color = softShadow,
    );
    canvas.drawRRect(r, Paint()..color = buildingWallColor);
    // Roof band.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(
          _building.left,
          _building.top,
          _building.width,
          _roofHeight,
        ),
        topLeft: const Radius.circular(_buildingRadius),
        topRight: const Radius.circular(_buildingRadius),
      ),
      Paint()..color = buildingRoofColor,
    );
    // Windows.
    final glass = Paint()..color = buildingWindowColor;
    for (var i = 0; i < _windowCount; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _firstWindow.translate(i * _windowPitch, 0),
          const Radius.circular(_windowRadius),
        ),
        glass,
      );
    }
    // Sign and door the queue walks out of.
    canvas.drawRRect(
      RRect.fromRectAndRadius(_sign, const Radius.circular(_signRadius)),
      Paint()..color = buildingSignColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(_door, const Radius.circular(_doorRadius)),
      Paint()..color = buildingDoorColor,
    );
    canvas.drawRect(_awning, Paint()..color = buildingAwningColor);
  }

  // Lot tiles: a soft rim under the whole lot, then each tile slightly
  // overlapping its neighbours so no seams show.
  static const double _rimSpread = 3;
  static const double _rimDrop = 2;
  static const double _tileOverlap = 0.5;
  static const double _tileLine = 1;

  /// The lot: one tile per parking cell, so irregular outlines show.
  void _paintLot(Canvas canvas) {
    final l = game.layout;
    final level = game.level;
    final fill = Paint()..color = lotColor;
    final edge = Paint()
      ..color = lotLineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _tileLine;
    final rim = Paint()..color = softShadow;
    for (var r = 0; r < l.rows; r++) {
      for (var c = 0; c < l.cols; c++) {
        if (!level.hasCell(r, c)) continue;
        final rect = l.cellRect(r, c);
        canvas.drawRect(rect.inflate(_rimSpread).translate(0, _rimDrop), rim);
      }
    }
    for (var r = 0; r < l.rows; r++) {
      for (var c = 0; c < l.cols; c++) {
        if (!level.hasCell(r, c)) continue;
        final rect = l.cellRect(r, c);
        canvas.drawRect(rect.inflate(_tileOverlap), fill);
        canvas.drawRect(rect, edge);
      }
    }
  }
}
