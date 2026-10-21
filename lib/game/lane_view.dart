import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../core/core.dart';
import '../services/progress_service.dart';
import 'bus_escape_game.dart';
import 'layout.dart';
import 'palette.dart';
import 'parked_vehicle_painter.dart';
import 'layers.dart';

/// Draws the road and the loading lane from core state, plus the timing
/// tricks (held snapshots, hops) that keep it in step with animations.
class LaneView extends PositionComponent with HasGameReference<BusEscapeGame> {
  LaneView() : super(priority: Layer.lane);

  static const double hopDuration = 0.18;

  static const double _priceFontSize = 10;

  /// How high a vehicle bobs when a passenger lands in it.
  static const double _hopHeight = 4;

  /// What each bay shows right now. Driven by the animations rather than by
  /// core state, so a vehicle appears when it parks, gains passengers as
  /// they land, and leaves the moment its last seat is taken.
  final Map<int, ParkedBus> bays = {};

  /// Remaining hop time per bay.
  final Map<int, double> hopT = {};

  void hop(int bay) => hopT[bay] = hopDuration;

  void reset() {
    bays.clear();
    hopT.clear();
  }

  /// Shows the lane exactly as core state has it (start, undo, new slot).
  void syncFrom(List<ParkedBus?> lane) {
    reset();
    for (var i = 0; i < lane.length; i++) {
      final p = lane[i];
      if (p != null) bays[i] = p;
    }
  }

  @override
  void update(double dt) {
    for (final slot in hopT.keys.toList()) {
      final left = hopT[slot]! - dt;
      if (left <= 0) {
        hopT.remove(slot);
      } else {
        hopT[slot] = left;
      }
    }
  }

  static final _unlockText = TextPaint(
    style: const TextStyle(
      color: white,
      fontSize: _priceFontSize,
      fontWeight: FontWeight.bold,
    ),
  );

  // Road kerbs, bay outlines and the locked-bay "+" button.
  static const double _kerbHeight = 4;
  static const double _bayOutlineInset = 1;
  static const double _bayRadius = 8;
  static const double _bayLineWidth = 2;
  static const double _plusRise = 6;
  static const double _plusRadius = 11;
  static const double _plusArm = 5;
  static const double _plusWidth = 3;
  static const double _priceDrop = 16;
  static const double _dash = 6;
  static const double _dashGap = 5;

  @override
  void render(Canvas canvas) {
    final layout = game.layout;
    _paintRoad(canvas);
    for (var i = 0; i < layout.slotCount; i++) {
      final r = layout.laneSlotRect(i);
      if (i >= layout.laneSlots) {
        _paintLocked(canvas, r);
        continue;
      }
      _paintBay(canvas, r);
      final p = bays[i];
      if (p == null) continue;
      final left = hopT[i];
      final lift = left == null
          ? 0.0
          : -sin(pi * (1 - left / hopDuration)) * _hopHeight;
      canvas.save();
      canvas.translate(0, lift);
      paintLaneVehicle(canvas, r, p, symbols: game.showSymbols);
      paintSeatsLeft(canvas, r, p);
      canvas.restore();
    }
  }

  void _paintRoad(Canvas canvas) {
    const road = Rect.fromLTWH(
      0,
      GameLayout.roadTop,
      GameLayout.width,
      GameLayout.roadHeight,
    );
    canvas.drawRect(road, Paint()..color = roadColor);
    final edge = Paint()..color = roadEdgeColor;
    canvas.drawRect(Rect.fromLTWH(0, road.top, road.width, _kerbHeight), edge);
    canvas.drawRect(
      Rect.fromLTWH(0, road.bottom - _kerbHeight, road.width, _kerbHeight),
      edge,
    );
  }

  void _paintBay(Canvas canvas, Rect r) => _dashedRRect(
    canvas,
    RRect.fromRectAndRadius(
      r.deflate(_bayOutlineInset),
      const Radius.circular(_bayRadius),
    ),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _bayLineWidth
      ..color = bayLineColor,
  );

  void _paintLocked(Canvas canvas, Rect r) {
    _paintBay(canvas, r);
    final c = r.center.translate(0, -_plusRise);
    canvas.drawCircle(c, _plusRadius, Paint()..color = unlockGreen);
    final plus = Paint()
      ..color = white
      ..strokeWidth = _plusWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-_plusArm, 0), c.translate(_plusArm, 0), plus);
    canvas.drawLine(c.translate(0, -_plusArm), c.translate(0, _plusArm), plus);
    _unlockText.render(
      canvas,
      '${ProgressService.slotUnlockCost}',
      Vector2(r.center.dx, r.center.dy + _priceDrop),
      anchor: Anchor.center,
    );
  }
}

void _dashedRRect(Canvas canvas, RRect rrect, Paint paint) {
  const dash = LaneView._dash;
  const gap = LaneView._dashGap;
  for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      canvas.drawPath(
        metric.extractPath(d, min(d + dash, metric.length)),
        paint,
      );
      d += dash + gap;
    }
  }
}
