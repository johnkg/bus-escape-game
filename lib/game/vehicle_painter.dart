import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import '../core/core.dart';
import 'palette.dart';

Color shade(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}

/// How far the roof sits above the base, as a fraction of a cell.
const double vehicleDepthFactor = 0.17;

const Color _glass = Color(0xE63A526B);
const Color _policeBlue = Color(0xFF2B4C9B);
const Color _lightRed = Color(0xFFFF4A4A);
const Color _lightBlue = Color(0xFF4AA3FF);
const Color _yellow = Color(0xFFFFD23F);

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

void _fill(Canvas canvas, Rect r, Color c, [double radius = 3]) => canvas
    .drawRRect(RRect.fromRectAndRadius(r, Radius.circular(radius)), Paint()..color = c);

/// Draws one of the five vehicles with a little fake depth: a ground shadow,
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
  final color = colorFor(colorIndex);
  final short = min(footprint.width, footprint.height);
  final cornerFactor = switch (kind) {
    VehicleKind.sedan || VehicleKind.policeCar => 0.36,
    VehicleKind.coaster => 0.28,
    VehicleKind.bus => 0.22,
    VehicleKind.fireTruck => 0.2,
  };
  final radius = Radius.circular(short * cornerFactor);

  final roofRect = footprint.translate(0, -depth / 2);
  final baseRect = footprint.translate(0, depth / 2);

  // Shadow on the ground.
  canvas.drawRRect(
    RRect.fromRectAndRadius(baseRect.translate(1.5, 2.5).inflate(1), radius),
    Paint()..color = const Color(0x33000000),
  );

  // Side panel (darker): windows, wheels.
  final base = RRect.fromRectAndRadius(baseRect, radius);
  canvas.drawRRect(base, Paint()..color = shade(color, -0.2));
  if (dir.isHorizontal && depth >= 4) {
    _paintSide(canvas, baseRect, kind, depth, short);
  }

  // Roof.
  final roof = RRect.fromRectAndRadius(roofRect, radius);
  canvas.drawRRect(roof, Paint()..color = shade(color, 0.04));
  canvas.drawRRect(
    roof,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = shade(color, -0.22),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      roofRect.deflate(short * 0.13),
      Radius.circular(short * 0.2),
    ),
    Paint()..color = shade(color, 0.1),
  );

  final f = _Frame(roofRect, dir);
  _paintRoofDetails(canvas, f, kind, color);
  if (showArrow) {
    final c = switch (kind) {
      VehicleKind.policeCar || VehicleKind.fireTruck => f.at(0.3, 0.5),
      _ => roofRect.center,
    };
    _paintArrow(canvas, c, short * 0.5, dir);
  }
  return roofRect;
}

void _paintSide(
  Canvas canvas,
  Rect baseRect,
  VehicleKind kind,
  double depth,
  double short,
) {
  final n = switch (kind) {
    VehicleKind.sedan || VehicleKind.policeCar => 3,
    VehicleKind.coaster => 5,
    VehicleKind.bus => 9,
    VehicleKind.fireTruck => 0,
  };
  if (n > 0) {
    final slot = (baseRect.width - short * 0.5) / n;
    for (var i = 0; i < n; i++) {
      final x = baseRect.left + short * 0.25 + i * slot + slot * 0.12;
      _fill(
        canvas,
        Rect.fromLTWH(
          x,
          baseRect.bottom - depth * 0.85,
          slot * 0.76,
          depth * 0.55,
        ),
        const Color(0xFFCFE6F7),
        1.5,
      );
    }
  } else {
    // Fire truck: equipment lockers.
    for (var i = 0; i < 3; i++) {
      final w = (baseRect.width - short) / 3;
      _fill(
        canvas,
        Rect.fromLTWH(
          baseRect.left + short * 0.15 + i * w + w * 0.1,
          baseRect.bottom - depth * 0.85,
          w * 0.8,
          depth * 0.55,
        ),
        const Color(0x55000000),
        1.5,
      );
    }
  }
  // Wheels peeking out at the bottom edge.
  final wheels = switch (kind) {
    VehicleKind.bus => const [0.14, 0.5, 0.86],
    VehicleKind.fireTruck => const [0.18, 0.5, 0.84],
    _ => const [0.24, 0.76],
  };
  final r = depth * 0.42;
  for (final u in wheels) {
    final c = Offset(baseRect.left + baseRect.width * u, baseRect.bottom - r * 0.2);
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF2A2F36));
    canvas.drawCircle(c, r * 0.4, Paint()..color = const Color(0xFF9AA4AE));
  }
}

void _paintRoofDetails(Canvas canvas, _Frame f, VehicleKind kind, Color color) {
  final light = shade(color, 0.16);
  final dark = shade(color, -0.1);
  switch (kind) {
    case VehicleKind.sedan:
      _fill(canvas, f.box(0.56, 0.1, 0.72, 0.9), _glass, 3); // windscreen
      _fill(canvas, f.box(0.2, 0.12, 0.32, 0.88), _glass, 3); // rear glass
      _fill(canvas, f.box(0.34, 0.14, 0.54, 0.86), light, 3); // roof panel
      _headlights(canvas, f, 0.93);
    case VehicleKind.coaster:
      _fill(canvas, f.box(0.88, 0.12, 0.97, 0.88), _glass, 3);
      _fill(canvas, f.box(0.03, 0.14, 0.09, 0.86), _glass, 3);
      _fill(canvas, f.box(0.3, 0.2, 0.46, 0.8), light, 2.5); // hatch
      _fill(canvas, f.box(0.54, 0.2, 0.7, 0.8), light, 2.5);
      _headlights(canvas, f, 0.985);
    case VehicleKind.bus:
      _fill(canvas, f.box(0.93, 0.12, 0.985, 0.88), _glass, 3);
      _fill(canvas, f.box(0.015, 0.14, 0.05, 0.86), _glass, 3);
      _fill(canvas, f.box(0.16, 0.2, 0.3, 0.8), light, 2.5); // roof units
      _fill(canvas, f.box(0.4, 0.2, 0.54, 0.8), light, 2.5);
      _fill(canvas, f.box(0.64, 0.2, 0.78, 0.8), light, 2.5);
      _headlights(canvas, f, 0.99);
    case VehicleKind.policeCar:
      _fill(canvas, f.box(0.56, 0.1, 0.72, 0.9), _glass, 3);
      _fill(canvas, f.box(0.2, 0.12, 0.32, 0.88), _glass, 3);
      _fill(canvas, f.box(0.34, 0.12, 0.54, 0.88), _policeBlue, 3); // roof
      _fill(canvas, f.box(0.4, 0.2, 0.48, 0.5), _lightRed, 2); // light bar
      _fill(canvas, f.box(0.4, 0.5, 0.48, 0.8), _lightBlue, 2);
      _fill(canvas, f.box(0.76, 0.42, 0.9, 0.58), _policeBlue, 2); // hood
      _headlights(canvas, f, 0.93);
    case VehicleKind.fireTruck:
      _fill(canvas, f.box(0.86, 0.12, 0.97, 0.88), _glass, 3); // cab glass
      _fill(canvas, f.box(0.8, 0.3, 0.84, 0.7), _lightBlue, 1.5); // beacon
      // Ladder on top: two rails and rungs.
      final rail = Paint()
        ..color = const Color(0xFFCFD6DD)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(f.at(0.08, 0.3), f.at(0.74, 0.3), rail);
      canvas.drawLine(f.at(0.08, 0.7), f.at(0.74, 0.7), rail);
      final rung = Paint()
        ..color = const Color(0xFF9AA4AE)
        ..strokeWidth = 1.4;
      for (var i = 0; i < 7; i++) {
        final u = 0.12 + i * 0.1;
        canvas.drawLine(f.at(u, 0.3), f.at(u, 0.7), rung);
      }
      _fill(canvas, f.box(0.76, 0.12, 0.79, 0.88), _yellow, 1); // stripe
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          f.box(0.04, 0.12, 0.78, 0.88),
          const Radius.circular(3),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = dark,
      );
  }
}

void _headlights(Canvas canvas, _Frame f, double u) {
  const c = Color(0xFFFFF3B0);
  _fill(canvas, f.box(u - 0.035, 0.08, u, 0.28), c, 1.2);
  _fill(canvas, f.box(u - 0.035, 0.72, u, 0.92), c, 1.2);
}

void _paintArrow(Canvas canvas, Offset c, double size, Direction dir) {
  final angle = switch (dir) {
    Direction.east => 0.0,
    Direction.south => pi / 2,
    Direction.west => pi,
    Direction.north => -pi / 2,
  };
  final s = size;
  final path = Path()
    ..moveTo(-s * 0.5, -s * 0.13)
    ..lineTo(s * 0.08, -s * 0.13)
    ..lineTo(s * 0.08, -s * 0.36)
    ..lineTo(s * 0.55, 0)
    ..lineTo(s * 0.08, s * 0.36)
    ..lineTo(s * 0.08, s * 0.13)
    ..lineTo(-s * 0.5, s * 0.13)
    ..close();
  canvas.save();
  canvas.translate(c.dx, c.dy);
  canvas.rotate(angle);
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0x55000000),
  );
  canvas.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
  canvas.restore();
}

/// A little passenger standing at [c] (center of the body). Ordinary
/// passengers are a blob in their color; police wear a cap and a badge,
/// firefighters a helmet and a reflective stripe.
void paintPassenger(
  Canvas canvas,
  Offset c,
  int colorIndex, {
  double scale = 1,
}) {
  if (!isServiceColor(colorIndex)) {
    paintPerson(canvas, c, colorFor(colorIndex), scale: scale);
    return;
  }
  final police = colorIndex == policeColor;
  final bodyColor = police ? _policeBlue : const Color(0xFF3A3F47);
  paintPerson(canvas, c, bodyColor, scale: scale);
  final head = c.translate(0, -5.5 * scale);
  // Face.
  canvas.drawCircle(head, 4.2 * scale, Paint()..color = const Color(0xFFF1C9A0));
  if (police) {
    // Cap with a peak and a gold badge.
    _fill(
      canvas,
      Rect.fromCenter(
        center: head.translate(0, -3.2 * scale),
        width: 10 * scale,
        height: 4.2 * scale,
      ),
      const Color(0xFF1B2F66),
      2 * scale,
    );
    _fill(
      canvas,
      Rect.fromCenter(
        center: head.translate(0, -1.2 * scale),
        width: 11 * scale,
        height: 1.6 * scale,
      ),
      const Color(0xFF1B2F66),
      1 * scale,
    );
    canvas.drawCircle(
      c.translate(2.5 * scale, 2.5 * scale),
      1.3 * scale,
      Paint()..color = _yellow,
    );
  } else {
    // Helmet and reflective stripe.
    canvas.drawArc(
      Rect.fromCenter(
        center: head.translate(0, -0.6 * scale),
        width: 11 * scale,
        height: 10 * scale,
      ),
      pi,
      pi,
      true,
      Paint()..color = _yellow,
    );
    _fill(
      canvas,
      Rect.fromCenter(
        center: head.translate(0, -0.5 * scale),
        width: 12 * scale,
        height: 1.4 * scale,
      ),
      const Color(0xFFD13B3B),
      0.7 * scale,
    );
    _fill(
      canvas,
      Rect.fromCenter(
        center: c.translate(0, 5.5 * scale),
        width: 11 * scale,
        height: 2 * scale,
      ),
      _yellow,
      0.8 * scale,
    );
  }
}

/// A little stick-figure passenger standing at [c] (center of the body).
void paintPerson(Canvas canvas, Offset c, Color color, {double scale = 1}) {
  final dark = shade(color, -0.2);
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: c.translate(0, 4 * scale),
      width: 11 * scale,
      height: 13 * scale,
    ),
    Radius.circular(4 * scale),
  );
  canvas.drawRRect(body, Paint()..color = color);
  canvas.drawRRect(
    body,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = dark,
  );
  final head = c.translate(0, -5.5 * scale);
  canvas.drawCircle(head, 5 * scale, Paint()..color = color);
  canvas.drawCircle(
    head,
    5 * scale,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = dark,
  );
}
