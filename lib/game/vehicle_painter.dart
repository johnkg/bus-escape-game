import 'dart:math';
import 'dart:ui';

import '../core/core.dart';
import 'paint_helpers.dart';
import 'palette.dart';

/// How far the roof sits above the base, as a fraction of a cell.
const double vehicleDepthFactor = 0.17;

/// Maps a vehicle-local (u along its length, v across) into the screen for
/// a vehicle heading [dir] inside [rect]. u = 0 is the tail, 1 the nose.
class _Frame {
  const _Frame(this.rect, this.dir);

  final Rect rect;
  final Direction dir;

  Offset at(double u, double v) => switch (dir) {
    Direction.east => Offset(
      rect.left + rect.width * u,
      rect.top + rect.height * v,
    ),
    Direction.west => Offset(
      rect.right - rect.width * u,
      rect.top + rect.height * v,
    ),
    Direction.south => Offset(
      rect.left + rect.width * v,
      rect.top + rect.height * u,
    ),
    Direction.north => Offset(
      rect.left + rect.width * v,
      rect.bottom - rect.height * u,
    ),
  };

  Rect box(double u0, double v0, double u1, double v1) =>
      Rect.fromPoints(at(u0, v0), at(u1, v1));
}

/// Default corner radius of small painted parts, in pixels.
const double _partRadius = 3;

void _fill(Canvas canvas, Rect r, Color c, [double radius = _partRadius]) =>
    fillRounded(canvas, r, c, radius);

/// A rounded rectangle on the roof, in vehicle-local (u, v) coordinates.
/// A null [color] means a lighter shade of the body.
class _Panel {
  const _Panel(
    this.u0,
    this.v0,
    this.u1,
    this.v1, {
    this.color,
    this.radius = _partRadius,
  });

  final double u0;
  final double v0;
  final double u1;
  final double v1;
  final Color? color;
  final double radius;
}

/// Everything that makes one vehicle kind look like itself in the jam.
class _VehicleStyle {
  const _VehicleStyle({
    required this.cornerFactor,
    required this.sideWindows,
    required this.wheels,
    required this.panels,
    this.headlightsAt,
    this.arrowAtTail = false,
    this.lockers = false,
    this.ladder = false,
  });

  /// Corner radius as a share of the short side.
  final double cornerFactor;

  /// Windows along the side panel (when the long side faces us).
  final int sideWindows;

  /// Wheel positions along the length (0 = tail, 1 = nose).
  final List<double> wheels;

  /// Glass and roof details, painted in order.
  final List<_Panel> panels;

  /// Where along the length the headlights sit, if it has any.
  final double? headlightsAt;

  /// Service vehicles keep their roof gear clear of the direction arrow.
  final bool arrowAtTail;

  /// Fire truck: equipment lockers instead of windows, ladder on the roof.
  final bool lockers;
  final bool ladder;
}

// Car-sized glass shared by the sedan, police car and ambulance.
const _windscreen = _Panel(0.56, 0.1, 0.72, 0.9, color: glassColor);
const _rearGlass = _Panel(0.2, 0.12, 0.32, 0.88, color: glassColor);
const _carNose = 0.93;
const _carWheels = [0.24, 0.76];
const _carCorner = 0.36;
const _carSideWindows = 3;

/// Thin parts such as light bars use smaller corners.
const double _thinRadius = 2;
const double _hatchRadius = 2.5;
const double _beaconRadius = 1.5;
const double _stripeRadius = 1;

const Map<VehicleKind, _VehicleStyle> _styles = {
  VehicleKind.sedan: _VehicleStyle(
    cornerFactor: _carCorner,
    sideWindows: _carSideWindows,
    wheels: _carWheels,
    panels: [
      _windscreen,
      _rearGlass,
      _Panel(0.34, 0.14, 0.54, 0.86), // roof panel
    ],
    headlightsAt: _carNose,
  ),
  VehicleKind.coaster: _VehicleStyle(
    cornerFactor: 0.28,
    sideWindows: 5,
    wheels: _carWheels,
    panels: [
      _Panel(0.88, 0.12, 0.97, 0.88, color: glassColor),
      _Panel(0.03, 0.14, 0.09, 0.86, color: glassColor),
      _Panel(0.3, 0.2, 0.46, 0.8, radius: _hatchRadius), // roof hatches
      _Panel(0.54, 0.2, 0.7, 0.8, radius: _hatchRadius),
    ],
    headlightsAt: 0.985,
  ),
  VehicleKind.bus: _VehicleStyle(
    cornerFactor: 0.22,
    sideWindows: 9,
    wheels: [0.14, 0.5, 0.86],
    panels: [
      _Panel(0.93, 0.12, 0.985, 0.88, color: glassColor),
      _Panel(0.015, 0.14, 0.05, 0.86, color: glassColor),
      _Panel(0.16, 0.2, 0.3, 0.8, radius: _hatchRadius), // roof units
      _Panel(0.4, 0.2, 0.54, 0.8, radius: _hatchRadius),
      _Panel(0.64, 0.2, 0.78, 0.8, radius: _hatchRadius),
    ],
    headlightsAt: 0.99,
  ),
  VehicleKind.policeCar: _VehicleStyle(
    cornerFactor: _carCorner,
    sideWindows: _carSideWindows,
    wheels: _carWheels,
    arrowAtTail: true,
    panels: [
      _windscreen,
      _rearGlass,
      _Panel(0.34, 0.12, 0.54, 0.88, color: policeBlue), // roof
      _Panel(0.4, 0.2, 0.48, 0.5, color: beaconRed, radius: _thinRadius),
      _Panel(0.4, 0.5, 0.48, 0.8, color: beaconBlue, radius: _thinRadius),
      _Panel(0.76, 0.42, 0.9, 0.58, color: policeBlue, radius: _thinRadius),
    ],
    headlightsAt: _carNose,
  ),
  VehicleKind.ambulance: _VehicleStyle(
    cornerFactor: _carCorner,
    sideWindows: _carSideWindows,
    wheels: _carWheels,
    arrowAtTail: true,
    panels: [
      _windscreen,
      _rearGlass,
      // Red cross on the roof.
      _Panel(0.3, 0.41, 0.55, 0.59, color: crossRed, radius: _beaconRadius),
      _Panel(0.38, 0.25, 0.47, 0.75, color: crossRed, radius: _beaconRadius),
      // Beacons.
      _Panel(0.76, 0.3, 0.82, 0.48, color: beaconRed, radius: _beaconRadius),
      _Panel(0.76, 0.52, 0.82, 0.7, color: beaconBlue, radius: _beaconRadius),
    ],
    headlightsAt: _carNose,
  ),
  VehicleKind.fireTruck: _VehicleStyle(
    cornerFactor: 0.2,
    sideWindows: 0,
    wheels: [0.18, 0.5, 0.84],
    arrowAtTail: true,
    lockers: true,
    ladder: true,
    panels: [
      _Panel(0.86, 0.12, 0.97, 0.88, color: glassColor), // cab glass
      _Panel(0.8, 0.3, 0.84, 0.7, color: beaconBlue, radius: _beaconRadius),
    ],
  ),
};

// Shared shading of every jam vehicle.
const double _sideDarken = -0.2;
const double _roofLighten = 0.04;
const double _roofEdgeDarken = -0.22;
const double _roofEdgeWidth = 1.5;
const double _roofInset = 0.13; // share of the short side
const double _roofInsetRadius = 0.2;
const double _roofInsetLighten = 0.1;
const double _detailLighten = 0.16;
const double _outlineDarken = -0.1;

/// Below this depth the side panel is too thin for windows and wheels.
const double _minSideDetailDepth = 4;

/// The direction arrow: its size as a share of the short side, and where it
/// sits on service vehicles.
const double _arrowScale = 0.5;
const double _tailArrowU = 0.3;
const double _centreV = 0.5;

/// Draws one of the vehicles with a little fake depth: a ground shadow,
/// a darker side panel (with windows and wheels when the long side faces
/// us), and the roof with glass, kind-specific details and, optionally, a
/// direction arrow.
///
/// [footprint] is the vehicle's top-down rectangle. Returns the roof rect
/// so callers can add overlays (symbols, hint glow).
Rect paintVehicle(
  Canvas canvas,
  Rect footprint,
  int colorIndex,
  Direction dir, {
  required int length,
  required double depth,
  bool showArrow = true,
}) {
  final kind = VehicleKind.of(length: length, colorIndex: colorIndex);
  final style = _styles[kind]!;
  final color = colorFor(colorIndex);
  final short = min(footprint.width, footprint.height);
  final radius = Radius.circular(short * style.cornerFactor);

  final roofRect = footprint.translate(0, -depth / 2);
  final baseRect = footprint.translate(0, depth / 2);

  paintGroundShadow(canvas, baseRect, radius);

  // Side panel (darker): windows, wheels.
  final base = RRect.fromRectAndRadius(baseRect, radius);
  canvas.drawRRect(base, Paint()..color = shade(color, _sideDarken));
  if (dir.isHorizontal && depth >= _minSideDetailDepth) {
    _paintSide(canvas, baseRect, style, depth, short);
  }

  // Roof.
  final roof = RRect.fromRectAndRadius(roofRect, radius);
  canvas.drawRRect(roof, Paint()..color = shade(color, _roofLighten));
  canvas.drawRRect(
    roof,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _roofEdgeWidth
      ..color = shade(color, _roofEdgeDarken),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      roofRect.deflate(short * _roofInset),
      Radius.circular(short * _roofInsetRadius),
    ),
    Paint()..color = shade(color, _roofInsetLighten),
  );

  final f = _Frame(roofRect, dir);
  _paintRoofDetails(canvas, f, style, color);
  if (showArrow) {
    final c = style.arrowAtTail ? f.at(_tailArrowU, _centreV) : roofRect.center;
    _paintArrow(canvas, c, short * _arrowScale, dir);
  }
  return roofRect;
}

// Side panel layout, as shares of the short side, the depth or a slot.
const double _sideEndMargin = 0.25;
const double _windowGap = 0.12;
const double _windowWidth = 0.76;
const double _windowTop = 0.85;
const double _windowHeight = 0.55;
const double _windowRadius = 1.5;
const int _lockerCount = 3;
const double _lockerEndMargin = 0.15;
const double _lockerGap = 0.1;
const double _lockerWidth = 0.8;
const double _wheelRadius = 0.42;
const double _wheelSink = 0.2;
const double _hubRadius = 0.4;

void _paintSide(
  Canvas canvas,
  Rect baseRect,
  _VehicleStyle style,
  double depth,
  double short,
) {
  final n = style.sideWindows;
  if (!style.lockers) {
    final slot = (baseRect.width - short * _sideEndMargin * 2) / n;
    for (var i = 0; i < n; i++) {
      final x =
          baseRect.left + short * _sideEndMargin + i * slot + slot * _windowGap;
      _fill(
        canvas,
        Rect.fromLTWH(
          x,
          baseRect.bottom - depth * _windowTop,
          slot * _windowWidth,
          depth * _windowHeight,
        ),
        sideWindowColor,
        _windowRadius,
      );
    }
  } else {
    for (var i = 0; i < _lockerCount; i++) {
      final w = (baseRect.width - short) / _lockerCount;
      _fill(
        canvas,
        Rect.fromLTWH(
          baseRect.left + short * _lockerEndMargin + i * w + w * _lockerGap,
          baseRect.bottom - depth * _windowTop,
          w * _lockerWidth,
          depth * _windowHeight,
        ),
        outlineShadow,
        _windowRadius,
      );
    }
  }
  // Wheels peeking out at the bottom edge.
  final r = depth * _wheelRadius;
  for (final u in style.wheels) {
    final c = Offset(
      baseRect.left + baseRect.width * u,
      baseRect.bottom - r * _wheelSink,
    );
    canvas.drawCircle(c, r, Paint()..color = tyreColor);
    canvas.drawCircle(c, r * _hubRadius, Paint()..color = steelColor);
  }
}

void _paintRoofDetails(
  Canvas canvas,
  _Frame f,
  _VehicleStyle style,
  Color color,
) {
  final light = shade(color, _detailLighten);
  for (final p in style.panels) {
    _fill(canvas, f.box(p.u0, p.v0, p.u1, p.v1), p.color ?? light, p.radius);
  }
  if (style.ladder) _paintLadder(canvas, f, shade(color, _outlineDarken));
  final nose = style.headlightsAt;
  if (nose != null) _headlights(canvas, f, nose);
}

// Fire truck ladder, in vehicle-local coordinates.
const double _ladderTail = 0.08;
const double _ladderHead = 0.74;
const double _ladderLeft = 0.3;
const double _ladderRight = 0.7;
const double _railWidth = 2.2;
const double _rungWidth = 1.4;
const int _rungCount = 7;
const double _firstRung = 0.12;
const double _rungSpacing = 0.1;
const _hiVisStripe = _Panel(
  0.76,
  0.12,
  0.79,
  0.88,
  color: hiVisYellow,
  radius: _stripeRadius,
);
const _ladderBay = _Panel(0.04, 0.12, 0.78, 0.88);
const double _ladderBayEdge = 1;

void _paintLadder(Canvas canvas, _Frame f, Color outline) {
  final rail = Paint()
    ..color = ladderRailColor
    ..strokeWidth = _railWidth
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    f.at(_ladderTail, _ladderLeft),
    f.at(_ladderHead, _ladderLeft),
    rail,
  );
  canvas.drawLine(
    f.at(_ladderTail, _ladderRight),
    f.at(_ladderHead, _ladderRight),
    rail,
  );
  final rung = Paint()
    ..color = steelColor
    ..strokeWidth = _rungWidth;
  for (var i = 0; i < _rungCount; i++) {
    final u = _firstRung + i * _rungSpacing;
    canvas.drawLine(f.at(u, _ladderLeft), f.at(u, _ladderRight), rung);
  }
  const s = _hiVisStripe;
  _fill(canvas, f.box(s.u0, s.v0, s.u1, s.v1), s.color!, s.radius);
  const b = _ladderBay;
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      f.box(b.u0, b.v0, b.u1, b.v1),
      const Radius.circular(_partRadius),
    ),
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ladderBayEdge
      ..color = outline,
  );
}

// Headlights: a short strip at each front corner.
const double _headlightLength = 0.035;
const double _headlightInner = 0.08;
const double _headlightOuter = 0.28;
const double _headlightRadius = 1.2;

void _headlights(Canvas canvas, _Frame f, double u) {
  final tail = u - _headlightLength;
  _fill(
    canvas,
    f.box(tail, _headlightInner, u, _headlightOuter),
    headlightColor,
    _headlightRadius,
  );
  _fill(
    canvas,
    f.box(tail, 1 - _headlightOuter, u, 1 - _headlightInner),
    headlightColor,
    _headlightRadius,
  );
}

// Direction arrow outline, as shares of its size (pointing east).
const double _arrowTail = 0.5;
const double _arrowShaft = 0.13;
const double _arrowNeck = 0.08;
const double _arrowHead = 0.36;
const double _arrowTip = 0.55;
const double _arrowOutline = 2;

void _paintArrow(Canvas canvas, Offset c, double size, Direction dir) {
  final angle = switch (dir) {
    Direction.east => 0.0,
    Direction.south => pi / 2,
    Direction.west => pi,
    Direction.north => -pi / 2,
  };
  final s = size;
  final path = Path()
    ..moveTo(-s * _arrowTail, -s * _arrowShaft)
    ..lineTo(s * _arrowNeck, -s * _arrowShaft)
    ..lineTo(s * _arrowNeck, -s * _arrowHead)
    ..lineTo(s * _arrowTip, 0)
    ..lineTo(s * _arrowNeck, s * _arrowHead)
    ..lineTo(s * _arrowNeck, s * _arrowShaft)
    ..lineTo(-s * _arrowTail, s * _arrowShaft)
    ..close();
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _arrowOutline
      ..strokeJoin = StrokeJoin.round
      ..color = outlineShadow,
  );
  canvas.drawPath(path, Paint()..color = white);
  canvas.restore();
}
