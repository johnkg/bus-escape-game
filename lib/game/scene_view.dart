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

  // The depot building at the top of the screen, in design pixels. A
  // broad clay roof carries the HUD; the wall below shows windows, the
  // door the queue walks out of, its awning and a bus-stop sign.
  static const Rect _roof = Rect.fromLTWH(10, 2, 370, 64);
  static const double _roofRadius = 18;
  static const double _roofShine = 10;
  static const Rect _wall = Rect.fromLTWH(20, 56, 350, 78);
  static const double _wallRadius = 12;
  static const double _lip = 4;
  static const double _rim = 2;
  static const Offset _buildingShadow = Offset(0, 6);
  static const int _windowCount = 4;
  static const Rect _firstWindow = Rect.fromLTWH(34, 80, 44, 30);
  static const double _windowPitch = 58;
  static const double _windowRadius = 8;
  static const double _windowShine = 0.4;
  static const Rect _door = Rect.fromLTWH(288, 92, 32, 42);
  static const double _doorRadius = 8;
  static const Rect _awning = Rect.fromLTWH(280, 80, 48, 13);
  static const double _awningRadius = 6;
  static const Offset _signCenter = Offset(351, 100);
  static const double _signRadius = 15;

  // The bus pictogram on the sign, relative to its centre.
  static const Rect _iconBody = Rect.fromLTWH(-7, -7, 14, 12);
  static const double _iconRadius = 3;
  static const Rect _iconGlass = Rect.fromLTWH(-5, -5, 10, 4);
  static const double _iconWheel = 2;
  static const double _iconWheelX = 4;
  static const double _iconWheelY = 6;

  /// A raised clay shape: darker lip under the face, lighter rim on top.
  static void _clay(Canvas canvas, RRect shape, Color color) {
    canvas.drawRRect(
      shape.shift(const Offset(0, _lip)),
      Paint()..color = shade(color, clayLipShade),
    );
    canvas.drawRRect(shape, Paint()..color = color);
    canvas.drawRRect(
      shape.deflate(_rim / 2),
      Paint()
        ..color = shade(color, clayRimShade)
        ..style = PaintingStyle.stroke
        ..strokeWidth = _rim,
    );
  }

  void _paintBuilding(Canvas canvas) {
    final wall = RRect.fromRectAndRadius(
      _wall,
      const Radius.circular(_wallRadius),
    );
    final roof = RRect.fromRectAndRadius(
      _roof,
      const Radius.circular(_roofRadius),
    );
    canvas.drawRRect(wall.shift(_buildingShadow), Paint()..color = softShadow);
    canvas.drawRRect(wall, Paint()..color = buildingWallColor);
    canvas.drawRRect(
      wall.deflate(_rim / 2),
      Paint()
        ..color = buildingWallRimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = _rim,
    );
    _clay(canvas, roof, buildingRoofColor);
    // Gloss along the top of the roof.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          _roof.left + _roofRadius,
          _roof.top + _rim * 2,
          _roof.width - _roofRadius * 2,
          _roofShine,
        ),
        const Radius.circular(_roofShine / 2),
      ),
      Paint()..color = shade(buildingRoofColor, clayRimShade),
    );
    // Windows, each with a pale shine across the top.
    for (var i = 0; i < _windowCount; i++) {
      final pane = _firstWindow.translate(i * _windowPitch, 0);
      final glass = RRect.fromRectAndRadius(
        pane,
        const Radius.circular(_windowRadius),
      );
      canvas.drawRRect(glass, Paint()..color = buildingWindowColor);
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            pane.left,
            pane.top,
            pane.width,
            pane.height * _windowShine,
          ),
          topLeft: const Radius.circular(_windowRadius),
          topRight: const Radius.circular(_windowRadius),
        ),
        Paint()..color = shade(buildingWindowColor, clayRimShade),
      );
      canvas.drawRRect(
        glass,
        Paint()
          ..color = buildingWallRimColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = _rim,
      );
    }
    // Door the queue walks out of, under a clay awning.
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        _door,
        topLeft: const Radius.circular(_doorRadius),
        topRight: const Radius.circular(_doorRadius),
      ),
      Paint()..color = buildingDoorColor,
    );
    canvas.drawLine(
      Offset(_door.center.dx, _door.top),
      Offset(_door.center.dx, _door.bottom),
      Paint()
        ..color = shade(buildingDoorColor, clayLipShade)
        ..strokeWidth = _rim,
    );
    _clay(
      canvas,
      RRect.fromRectAndRadius(_awning, const Radius.circular(_awningRadius)),
      buildingAwningColor,
    );
    _paintBusStopSign(canvas);
  }

  /// A round blue sign with a white bus on it.
  void _paintBusStopSign(Canvas canvas) {
    canvas.drawCircle(
      _signCenter.translate(0, _lip),
      _signRadius,
      Paint()..color = shade(busStopSignColor, clayLipShade),
    );
    canvas.drawCircle(_signCenter, _signRadius, Paint()..color = white);
    canvas.drawCircle(
      _signCenter,
      _signRadius - _rim,
      Paint()..color = busStopSignColor,
    );
    final icon = Paint()..color = white;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        _iconBody.shift(_signCenter),
        const Radius.circular(_iconRadius),
      ),
      icon,
    );
    canvas.drawRect(
      _iconGlass.shift(_signCenter),
      Paint()..color = busStopIconGlass,
    );
    for (final dx in [-_iconWheelX, _iconWheelX]) {
      canvas.drawCircle(
        _signCenter.translate(dx, _iconWheelY),
        _iconWheel,
        icon,
      );
    }
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
