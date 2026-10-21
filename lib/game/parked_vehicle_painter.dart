import 'dart:math';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flutter/painting.dart' show TextStyle, FontWeight;

import '../core/core.dart';
import 'palette.dart';
import 'symbols.dart';
import 'vehicle_painter.dart';

// Parked vehicles: seen from above, nose up, roof open so the seats show.

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
  VehicleKind.sedan ||
  VehicleKind.policeCar ||
  VehicleKind.ambulance => (w: 0.86, h: 0.62),
};

/// Gap between a vehicle and its bay outline.
const double _bayInset = 3;

/// Size of a parked vehicle in [slot]; the flight shrinks to exactly this.
Size laneVehicleSize(Rect slot, ParkedBus p) {
  final f = _bayFill(_kindOf(p));
  final inner = slot.deflate(_bayInset);
  return Size(inner.width * f.w, inner.height * f.h);
}

// Body layout, as shares of the body or in pixels.
const double _glassSide = 0.16;
const double _glassTop = 3;
const double _glassWidth = 0.68;
const double _glassHeight = 0.1;
const double _cabSide = 0.11;
const double _cabGap = 3;
const double _cabRear = 4;

/// A fire truck keeps a rack for its ladder at the back.
const double _ladderRack = 0.16;

_LaneBody _laneBody(Rect slot, ParkedBus p) {
  final size = laneVehicleSize(slot, p);
  final body = Rect.fromCenter(
    center: slot.center,
    width: size.width,
    height: size.height,
  );
  final glass = Rect.fromLTWH(
    body.left + body.width * _glassSide,
    body.top + _glassTop,
    body.width * _glassWidth,
    body.height * _glassHeight,
  );
  final rear = _kindOf(p) == VehicleKind.fireTruck
      ? body.height * _ladderRack
      : _cabRear;
  final cab = Rect.fromLTRB(
    body.left + body.width * _cabSide,
    glass.bottom + _cabGap,
    body.right - body.width * _cabSide,
    body.bottom - rear,
  );
  return (body: body, glass: glass, cab: cab);
}

/// Seats fill this share of their grid cell.
const double _seatFill = 0.8;
const double _seatRadius = 0.25;

/// Passengers are drawn at [_seatFill] of a seat, a seat of this many
/// pixels being scale 1.
const double _personSeatSize = 20;

/// Passengers sit a touch above the seat centre.
const double _personLift = 1;

/// Seat [index] of a parked vehicle whose open cabin is [cab]: its centre
/// and side length.
({Offset center, double size}) _seatAt(Rect cab, ParkedBus p, int index) {
  final rows = (p.capacity / Bus.seatsPerCell).ceil();
  final cw = cab.width / Bus.seatsPerCell;
  final ch = cab.height / rows;
  final c = Offset(
    cab.left + cw * (index % Bus.seatsPerCell + 0.5),
    cab.top + ch * (index ~/ Bus.seatsPerCell + 0.5),
  );
  return (center: c, size: min(cw, ch) * _seatFill);
}

/// Where seat [index] of a parked vehicle is, and how big its passenger is.
({Offset center, double scale}) laneSeat(Rect slot, ParkedBus p, int index) {
  final seat = _seatAt(_laneBody(slot, p).cab, p, index);
  return (
    center: seat.center.translate(0, -_personLift),
    scale: seat.size / _personSeatSize,
  );
}

// Shell shading.
const double _roundCorner = 0.3;
const double _squareCorner = 0.2; // bus and fire truck
const Offset _shadowOffset = Offset(1.5, 2.5);
const double _shadowSpread = 1;
const double _shellEdge = 1.5;
const double _shellEdgeDarken = -0.25;
const double _glassRadius = 3;
const double _cabRadius = 4;
const double _symbolSize = 0.7; // share of the glass height
const double _maxSymbolSize = 7;
const double _symbolLift = 0.5;

/// A parked vehicle: empty seats are plain, boarded ones hold a passenger.
/// Each kind has its own fixed size in the bay.
void paintLaneVehicle(
  Canvas canvas,
  Rect slot,
  ParkedBus p, {
  bool symbols = false,
}) {
  final kind = _kindOf(p);
  final color = colorFor(p.colorIndex);
  final (:body, :glass, :cab) = _laneBody(slot, p);
  final square = kind == VehicleKind.bus || kind == VehicleKind.fireTruck;
  final radius = Radius.circular(
    body.width * (square ? _squareCorner : _roundCorner),
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      body.shift(_shadowOffset).inflate(_shadowSpread),
      radius,
    ),
    Paint()..color = shadowColor,
  );
  final shell = RRect.fromRectAndRadius(body, radius);
  canvas.drawRRect(shell, Paint()..color = color);
  canvas.drawRRect(
    shell,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _shellEdge
      ..color = shade(color, _shellEdgeDarken),
  );

  canvas.drawRRect(
    RRect.fromRectAndRadius(glass, const Radius.circular(_glassRadius)),
    Paint()..color = glassColor,
  );
  _laneBadge(canvas, kind, body, glass);
  if (symbols) {
    paintSymbol(
      canvas,
      Offset(body.center.dx, glass.top - _symbolLift + glass.height / 2),
      min(glass.height * _symbolSize, _maxSymbolSize),
      symbolFor(p.colorIndex),
    );
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(cab, const Radius.circular(_cabRadius)),
    Paint()..color = cabinFloorColor,
  );
  for (var i = 0; i < p.capacity; i++) {
    final seat = _seatAt(cab, p, i);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: seat.center,
          width: seat.size,
          height: seat.size,
        ),
        Radius.circular(seat.size * _seatRadius),
      ),
      Paint()..color = seatColor,
    );
    if (i < p.boarded) {
      paintPassenger(
        canvas,
        seat.center.translate(0, -_personLift),
        p.colorIndex,
        scale: seat.size / _personSeatSize,
      );
    }
  }
}

// Seats-left badge on the top corner.
const double _badgeRadius = 8;
const double _badgeOverhang = 1;
const double _badgeFontSize = 11;

final _seatsText = TextPaint(
  style: const TextStyle(
    color: badgeTextColor,
    fontSize: _badgeFontSize,
    fontWeight: FontWeight.w900,
  ),
);

/// How many seats are still empty, as a small badge on the vehicle's top
/// corner, so a glance shows which vehicle is nearly ready to go.
void paintSeatsLeft(Canvas canvas, Rect slot, ParkedBus p) {
  final left = p.capacity - p.boarded;
  if (left <= 0) return;
  final body = _laneBody(slot, p).body;
  final c = Offset(body.right - _badgeOverhang, body.top + _badgeOverhang);
  canvas.drawCircle(c, _badgeRadius, Paint()..color = white);
  canvas.drawCircle(
    c,
    _badgeRadius,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _shellEdge
      ..color = shade(colorFor(p.colorIndex), _shellEdgeDarken),
  );
  _seatsText.render(
    canvas,
    '$left',
    Vector2(c.dx, c.dy),
    anchor: Anchor.center,
  );
}

// Service badges.
const double _lightBarWidth = 0.5;
const double _lightBarHeight = 3.2;
const double _lightBarDrop = 0.5;
const double _lightRadius = 1.5;
const double _trimInset = 2;
const double _trimRise = 2.5;
const double _trimWidth = 2;
const double _rackSide = 0.14;
const double _rackDepth = 0.14;
const double _rackRear = 3;
const double _rackRailWidth = 1.6;
const double _rackRungWidth = 1;
const int _rackRungs = 6;
const double _beaconSide = 0.18;
const double _beaconDrop = 1.2;
const double _beaconRadius = 1.8;

/// What tells a police car, fire truck or ambulance apart in the bay.
void _laneBadge(Canvas canvas, VehicleKind kind, Rect body, Rect glass) {
  switch (kind) {
    case VehicleKind.policeCar:
      final bar = Rect.fromCenter(
        center: Offset(body.center.dx, glass.bottom + _lightBarDrop),
        width: body.width * _lightBarWidth,
        height: _lightBarHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(bar.left, bar.top, bar.center.dx, bar.bottom),
          const Radius.circular(_lightRadius),
        ),
        Paint()..color = beaconRed,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(bar.center.dx, bar.top, bar.right, bar.bottom),
          const Radius.circular(_lightRadius),
        ),
        Paint()..color = beaconBlue,
      );
      _paintTrim(canvas, body, policeBlue);
    case VehicleKind.fireTruck:
      final rack = Rect.fromLTRB(
        body.left + body.width * _rackSide,
        body.bottom - body.height * _rackDepth,
        body.right - body.width * _rackSide,
        body.bottom - _rackRear,
      );
      final rail = Paint()
        ..color = ladderRailColor
        ..strokeWidth = _rackRailWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(rack.topLeft, rack.topRight, rail);
      canvas.drawLine(rack.bottomLeft, rack.bottomRight, rail);
      final rung = Paint()
        ..color = steelColor
        ..strokeWidth = _rackRungWidth;
      for (var i = 0; i < _rackRungs; i++) {
        final x = rack.left + rack.width * (i + 0.5) / _rackRungs;
        canvas.drawLine(Offset(x, rack.top), Offset(x, rack.bottom), rung);
      }
    case VehicleKind.ambulance:
      // Red and blue beacons either side of the windscreen and a red stripe.
      for (final (x, c) in [
        (body.left + body.width * _beaconSide, beaconRed),
        (body.right - body.width * _beaconSide, beaconBlue),
      ]) {
        canvas.drawCircle(
          Offset(x, glass.bottom + _beaconDrop),
          _beaconRadius,
          Paint()..color = c,
        );
      }
      _paintTrim(canvas, body, crossRed);
    case VehicleKind.sedan || VehicleKind.coaster || VehicleKind.bus:
      break;
  }
}

/// A coloured stripe across the back of the body.
void _paintTrim(Canvas canvas, Rect body, Color color) => canvas.drawLine(
  Offset(body.left + _trimInset, body.bottom - _trimRise),
  Offset(body.right - _trimInset, body.bottom - _trimRise),
  Paint()
    ..color = color
    ..strokeWidth = _trimWidth,
);
