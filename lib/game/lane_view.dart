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

  static const double hopDuration = 0.18;

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
      color: Color(0xFFFFFFFF),
      fontSize: 10,
      fontWeight: FontWeight.bold,
    ),
  );

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
          : -sin(pi * (1 - left / hopDuration)) * 4;
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

typedef _LaneBody = ({Rect body, Rect glass, Rect cab});

VehicleKind _kindOf(ParkedBus p) => VehicleKind.of(
  length: p.capacity ~/ Bus.seatsPerCell,
  colorIndex: p.colorIndex,
);

/// How much of its bay a parked vehicle fills. The bus fills it; the
/// others are proportionally shorter, so a bus is always a little longer.
({double w, double h}) _bayFill(VehicleKind kind) => switch (kind) {
  VehicleKind.bus => (w: 1.0, h: 1.0),
  VehicleKind.coaster || VehicleKind.fireTruck => (w: 0.94, h: 0.8),
  VehicleKind.sedan || VehicleKind.policeCar => (w: 0.86, h: 0.62),
};

/// Size of a parked vehicle in [slot]; the flight shrinks to exactly this.
Size laneVehicleSize(Rect slot, ParkedBus p) {
  final f = _bayFill(_kindOf(p));
  final inner = slot.deflate(3);
  return Size(inner.width * f.w, inner.height * f.h);
}

_LaneBody _laneBody(Rect slot, ParkedBus p) {
  final size = laneVehicleSize(slot, p);
  final body = Rect.fromCenter(
    center: slot.center,
    width: size.width,
    height: size.height,
  );
  final glass = Rect.fromLTWH(
    body.left + body.width * 0.16,
    body.top + 3,
    body.width * 0.68,
    body.height * 0.1,
  );
  // A fire truck keeps a rack for its ladder at the back.
  final rear = _kindOf(p) == VehicleKind.fireTruck ? body.height * 0.16 : 4.0;
  final cab = Rect.fromLTRB(
    body.left + body.width * 0.11,
    glass.bottom + 3,
    body.right - body.width * 0.11,
    body.bottom - rear,
  );
  return (body: body, glass: glass, cab: cab);
}

/// Where seat [index] of a parked vehicle is, and how big its passenger is.
({Offset center, double scale}) laneSeat(Rect slot, ParkedBus p, int index) {
  final cab = _laneBody(slot, p).cab;
  final rows = (p.capacity / Bus.seatsPerCell).ceil();
  final cw = cab.width / Bus.seatsPerCell;
  final ch = cab.height / rows;
  final seat = min(cw, ch) * 0.8;
  final c = Offset(
    cab.left + cw * (index % Bus.seatsPerCell + 0.5),
    cab.top + ch * (index ~/ Bus.seatsPerCell + 0.5),
  );
  return (center: c.translate(0, -1), scale: seat / 20);
}

/// A parked vehicle seen from above, nose up, roof open so the seats show:
/// empty seats are plain, boarded ones hold a passenger. Each kind has its
/// own fixed size in the bay.
void paintLaneVehicle(
  Canvas canvas,
  Rect slot,
  ParkedBus p, {
  bool symbols = false,
}) {
  final kind = _kindOf(p);
  final color = colorFor(p.colorIndex);
  final (:body, :glass, :cab) = _laneBody(slot, p);
  final radius = Radius.circular(
    body.width *
        (kind == VehicleKind.bus || kind == VehicleKind.fireTruck ? 0.2 : 0.3),
  );

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

  canvas.drawRRect(
    RRect.fromRectAndRadius(glass, const Radius.circular(3)),
    Paint()..color = const Color(0xE63A526B),
  );
  _laneBadge(canvas, kind, body, glass);
  if (symbols) {
    paintSymbol(
      canvas,
      Offset(body.center.dx, glass.top - 0.5 + glass.height / 2),
      min(glass.height * 0.7, 7),
      symbolFor(p.colorIndex),
    );
  }

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
      paintPassenger(
        canvas,
        c.translate(0, -1),
        p.colorIndex,
        scale: seat / 20,
      );
    }
  }
}

/// How many seats are still empty, as a small badge on the vehicle's top
/// corner, so a glance shows which vehicle is nearly ready to go.
void paintSeatsLeft(Canvas canvas, Rect slot, ParkedBus p) {
  final left = p.capacity - p.boarded;
  if (left <= 0) return;
  final body = _laneBody(slot, p).body;
  final c = Offset(body.right - 1, body.top + 1);
  canvas.drawCircle(c, 8, Paint()..color = const Color(0xFFFFFFFF));
  canvas.drawCircle(
    c,
    8,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = shade(colorFor(p.colorIndex), -0.25),
  );
  _seatsText.render(
    canvas,
    '$left',
    Vector2(c.dx, c.dy),
    anchor: Anchor.center,
  );
}

final _seatsText = TextPaint(
  style: const TextStyle(
    color: Color(0xFF1B2733),
    fontSize: 11,
    fontWeight: FontWeight.w900,
  ),
);

/// What tells a police car or fire truck apart in the bay.
void _laneBadge(Canvas canvas, VehicleKind kind, Rect body, Rect glass) {
  switch (kind) {
    case VehicleKind.policeCar:
      final bar = Rect.fromCenter(
        center: Offset(body.center.dx, glass.bottom + 0.5),
        width: body.width * 0.5,
        height: 3.2,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(bar.left, bar.top, bar.center.dx, bar.bottom),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFFFF4A4A),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(bar.center.dx, bar.top, bar.right, bar.bottom),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFF4AA3FF),
      );
      canvas.drawLine(
        Offset(body.left + 2, body.bottom - 2.5),
        Offset(body.right - 2, body.bottom - 2.5),
        Paint()
          ..color = const Color(0xFF2B4C9B)
          ..strokeWidth = 2,
      );
    case VehicleKind.fireTruck:
      final rack = Rect.fromLTRB(
        body.left + body.width * 0.14,
        body.bottom - body.height * 0.14,
        body.right - body.width * 0.14,
        body.bottom - 3,
      );
      final rail = Paint()
        ..color = const Color(0xFFCFD6DD)
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(rack.topLeft, rack.topRight, rail);
      canvas.drawLine(rack.bottomLeft, rack.bottomRight, rail);
      final rung = Paint()
        ..color = const Color(0xFF9AA4AE)
        ..strokeWidth = 1;
      for (var i = 0; i < 6; i++) {
        final x = rack.left + rack.width * (i + 0.5) / 6;
        canvas.drawLine(Offset(x, rack.top), Offset(x, rack.bottom), rung);
      }
    case VehicleKind.sedan || VehicleKind.coaster || VehicleKind.bus:
      break;
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
