import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../core/core.dart';
import '../services/progress_service.dart';
import 'bus_escape_game.dart';
import 'layout.dart';
import 'palette.dart';
import 'symbols.dart';
import 'vehicle_painter.dart';

/// Draws the road and the loading lane from core state, plus the timing
/// tricks (held snapshots, hops) that keep it in step with animations.
class LaneView extends PositionComponent with HasGameReference<BusEscapeGame> {
  LaneView() : super(priority: 0);

  static const double hopDuration = 0.28;

  /// Slots whose bus is still flying in: draw nothing there yet.
  final Set<int> hidden = {};

  /// Slots drawn from this snapshot instead of core state, so boarding and
  /// departure show up when the animation says so, not when the tap happened.
  final Map<int, ParkedBus> holding = {};

  /// Remaining hop time per slot.
  final Map<int, double> hopT = {};

  void hop(int slot) => hopT[slot] = hopDuration;

  void reset() {
    hidden.clear();
    holding.clear();
    hopT.clear();
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
      color: Color(0xFFFFFFFF),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    ),
  );

  @override
  void render(Canvas canvas) {
    final layout = game.layout;
    _paintRoad(canvas);
    final lane = game.session.state.lane;
    for (var i = 0; i < layout.slotCount; i++) {
      final r = layout.laneSlotRect(i);
      if (i >= layout.laneSlots) {
        _paintLocked(canvas, r);
        continue;
      }
      _paintBay(canvas, r);
      if (hidden.contains(i)) continue;
      final p = holding[i] ?? lane[i];
      if (p == null) continue;
      final left = hopT[i];
      final lift = left == null
          ? 0.0
          : -sin(pi * (1 - left / hopDuration)) * 10;
      canvas.save();
      canvas.translate(0, lift);
      paintLaneVehicle(canvas, r, p, symbols: game.showSymbols);
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
    canvas.drawRect(Rect.fromLTWH(0, road.top, road.width, 4), edge);
    canvas.drawRect(Rect.fromLTWH(0, road.bottom - 4, road.width, 4), edge);
  }

  void _paintBay(Canvas canvas, Rect r) => _dashedRRect(
    canvas,
    RRect.fromRectAndRadius(r.deflate(1), const Radius.circular(8)),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = bayLineColor,
  );

  void _paintLocked(Canvas canvas, Rect r) {
    _paintBay(canvas, r);
    final c = r.center.translate(0, -6);
    canvas.drawCircle(c, 11, Paint()..color = const Color(0xFF3DBE5B));
    final plus = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c.translate(-5, 0), c.translate(5, 0), plus);
    canvas.drawLine(c.translate(0, -5), c.translate(0, 5), plus);
    _unlockText.render(
      canvas,
      '${ProgressService.slotUnlockCost}',
      Vector2(r.center.dx, r.center.dy + 16),
      anchor: Anchor.center,
    );
  }
}

/// A parked vehicle seen from above, nose up, roof open so the seats show:
/// empty seats are plain, boarded ones hold a passenger. Cars fill part of
/// the slot, buses all of it.
void paintLaneVehicle(
  Canvas canvas,
  Rect slot,
  ParkedBus p, {
  bool symbols = false,
}) {
  final length = p.capacity ~/ Bus.seatsPerCell;
  final color = busColors[p.colorIndex % busColors.length];
  final inner = slot.deflate(3);
  final h = inner.height * (length <= 2 ? 0.72 : 1.0);
  final body = Rect.fromLTWH(inner.left, inner.bottom - h, inner.width, h);
  final radius = Radius.circular(body.width * 0.28);

  canvas.drawRRect(
    RRect.fromRectAndRadius(body.translate(1.5, 2.5).inflate(1), radius),
    Paint()..color = const Color(0x33000000),
  );
  final shell = RRect.fromRectAndRadius(body, radius);
  canvas.drawRRect(shell, Paint()..color = color);
  canvas.drawRRect(
    shell,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = shade(color, -0.25),
  );

  final glass = Rect.fromLTWH(
    body.left + body.width * 0.16,
    body.top + 3,
    body.width * 0.68,
    body.height * 0.1,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(glass, const Radius.circular(3)),
    Paint()..color = const Color(0xE63A526B),
  );
  if (symbols) {
    paintSymbol(
      canvas,
      Offset(body.center.dx, glass.top - 0.5 + glass.height / 2),
      min(glass.height * 0.7, 7),
      symbolFor(p.colorIndex),
    );
  }

  final cab = Rect.fromLTRB(
    body.left + body.width * 0.11,
    glass.bottom + 3,
    body.right - body.width * 0.11,
    body.bottom - 4,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(cab, const Radius.circular(4)),
    Paint()..color = const Color(0xFFF6EBD0),
  );
  final rows = (p.capacity / Bus.seatsPerCell).ceil();
  final cw = cab.width / Bus.seatsPerCell;
  final ch = cab.height / rows;
  final seat = min(cw, ch) * 0.8;
  for (var i = 0; i < p.capacity; i++) {
    final c = Offset(
      cab.left + cw * (i % Bus.seatsPerCell + 0.5),
      cab.top + ch * (i ~/ Bus.seatsPerCell + 0.5),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: c, width: seat, height: seat),
        Radius.circular(seat * 0.25),
      ),
      Paint()..color = const Color(0xFFD9B27C),
    );
    if (i < p.boarded) {
      paintPerson(canvas, c.translate(0, -1), color, scale: seat / 20);
    }
  }
}

void _dashedRRect(Canvas canvas, RRect rrect, Paint paint) {
  const dash = 6.0;
  const gap = 5.0;
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
