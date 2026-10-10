import 'dart:math';
import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

import '../core/core.dart';

Color shade(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}

/// How far the roof sits above the base, as a fraction of a cell.
const double vehicleDepthFactor = 0.17;

/// Draws a car (length 2) or bus (length 3) with a little fake depth: a
/// shadow, a darker side panel with windows below the roof, a lighter roof
/// with glass at both ends, and a direction arrow.
///
/// [footprint] is the vehicle's top-down rectangle. Returns the roof rect
/// so callers can add overlays (symbols, hint glow).
Rect paintVehicle(
  Canvas canvas,
  Rect footprint,
  Color color,
  Direction dir, {
  required int length,
  required double depth,
  bool showArrow = true,
}) {
  final isCar = length <= 2;
  final short = min(footprint.width, footprint.height);
  final radius = Radius.circular(short * (isCar ? 0.34 : 0.26));

  final roofRect = footprint.translate(0, -depth / 2);
  final baseRect = footprint.translate(0, depth / 2);

  // Shadow on the ground.
  canvas.drawRRect(
    RRect.fromRectAndRadius(baseRect.translate(1.5, 2.5).inflate(1), radius),
    Paint()..color = const Color(0x33000000),
  );

  // Side panel (darker), with windows when the long side faces us.
  final base = RRect.fromRectAndRadius(baseRect, radius);
  canvas.drawRRect(base, Paint()..color = shade(color, -0.2));
  if (dir.isHorizontal && depth >= 4) {
    final n = length * 2;
    final slot = (baseRect.width - short * 0.5) / n;
    for (var i = 0; i < n; i++) {
      final x = baseRect.left + short * 0.25 + i * slot + slot * 0.12;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            baseRect.bottom - depth * 0.85,
            slot * 0.76,
            depth * 0.55,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = const Color(0xFFCFE6F7),
      );
    }
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
  // Soft highlight panel on the roof.
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      roofRect.deflate(short * 0.13),
      Radius.circular(short * 0.2),
    ),
    Paint()..color = shade(color, 0.1),
  );

  _paintGlass(canvas, roofRect, dir, short);
  if (showArrow) _paintArrow(canvas, roofRect.center, short * 0.5, dir);
  return roofRect;
}

void _paintGlass(Canvas canvas, Rect roof, Direction dir, double short) {
  final glass = Paint()..color = const Color(0xE63A526B);
  final front = short * 0.2;
  final rear = short * 0.14;
  const m = 3.5; // margin from the roof edge
  final pad = short * 0.14;
  Rect nose;
  Rect tail;
  switch (dir) {
    case Direction.east:
      nose = Rect.fromLTRB(
        roof.right - front - m,
        roof.top + pad,
        roof.right - m,
        roof.bottom - pad,
      );
      tail = Rect.fromLTRB(
        roof.left + m,
        roof.top + pad,
        roof.left + rear + m,
        roof.bottom - pad,
      );
    case Direction.west:
      nose = Rect.fromLTRB(
        roof.left + m,
        roof.top + pad,
        roof.left + front + m,
        roof.bottom - pad,
      );
      tail = Rect.fromLTRB(
        roof.right - rear - m,
        roof.top + pad,
        roof.right - m,
        roof.bottom - pad,
      );
    case Direction.south:
      nose = Rect.fromLTRB(
        roof.left + pad,
        roof.bottom - front - m,
        roof.right - pad,
        roof.bottom - m,
      );
      tail = Rect.fromLTRB(
        roof.left + pad,
        roof.top + m,
        roof.right - pad,
        roof.top + rear + m,
      );
    case Direction.north:
      nose = Rect.fromLTRB(
        roof.left + pad,
        roof.top + m,
        roof.right - pad,
        roof.top + front + m,
      );
      tail = Rect.fromLTRB(
        roof.left + pad,
        roof.bottom - rear - m,
        roof.right - pad,
        roof.bottom - m,
      );
  }
  const r = Radius.circular(3);
  canvas.drawRRect(RRect.fromRectAndRadius(nose, r), glass);
  canvas.drawRRect(RRect.fromRectAndRadius(tail, r), glass);
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
