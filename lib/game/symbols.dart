import 'dart:math';
import 'dart:ui';

import '../core/core.dart' show ambulanceColor, fireColor, policeColor;
import 'palette.dart';

/// One distinct shape per bus color so the game works without telling
/// colors apart (shown when the "Color symbols" setting is on).
enum SymbolShape {
  circle,
  square,
  triangle,
  diamond,
  star,
  hexagon,
  // The services each get a shape of their own.
  octagon,
  drop,
  cross,
}

SymbolShape symbolFor(int colorIndex) => switch (colorIndex) {
  policeColor => SymbolShape.octagon,
  fireColor => SymbolShape.drop,
  ambulanceColor => SymbolShape.cross,
  _ => SymbolShape.values[colorIndex % busColors.length],
};

/// Draws a white shape with a dark outline, centered on [c], about [size]
/// across.
void paintSymbol(Canvas canvas, Offset c, double size, SymbolShape shape) {
  final r = size / 2;
  final path = switch (shape) {
    SymbolShape.circle =>
      (Path()..addOval(Rect.fromCircle(center: c, radius: r))),
    SymbolShape.square =>
      (Path()..addRect(
        Rect.fromCenter(center: c, width: size * 0.85, height: size * 0.85),
      )),
    SymbolShape.triangle => _polygon(c, r * 1.1, 3, -pi / 2),
    SymbolShape.diamond => _polygon(c, r * 1.1, 4, -pi / 2),
    SymbolShape.star => _star(c, r * 1.15),
    SymbolShape.hexagon => _polygon(c, r, 6, 0),
    SymbolShape.octagon => _polygon(c, r * 1.05, 8, pi / 8),
    SymbolShape.drop => _drop(c, r),
    SymbolShape.cross => _cross(c, r * 1.1),
  };
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(1.5, size * 0.14)
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xAA000000),
  );
  canvas.drawPath(path, Paint()..color = const Color(0xFFFFFFFF));
}

Path _polygon(Offset c, double r, int sides, double start) {
  final path = Path();
  for (var i = 0; i < sides; i++) {
    final a = start + 2 * pi * i / sides;
    final p = Offset(c.dx + r * cos(a), c.dy + r * sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

Path _star(Offset c, double r) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final radius = i.isEven ? r : r * 0.45;
    final a = -pi / 2 + pi * i / 5;
    final p = Offset(c.dx + radius * cos(a), c.dy + radius * sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

Path _drop(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy - r * 1.15)
  ..cubicTo(c.dx + r, c.dy - r * 0.1, c.dx + r * 0.9, c.dy + r * 0.95, c.dx, c.dy + r * 0.95)
  ..cubicTo(c.dx - r * 0.9, c.dy + r * 0.95, c.dx - r, c.dy - r * 0.1, c.dx, c.dy - r * 1.15)
  ..close();

Path _cross(Offset c, double r) {
  final t = r * 0.38; // half the arm thickness
  return Path()
    ..moveTo(c.dx - t, c.dy - r)
    ..lineTo(c.dx + t, c.dy - r)
    ..lineTo(c.dx + t, c.dy - t)
    ..lineTo(c.dx + r, c.dy - t)
    ..lineTo(c.dx + r, c.dy + t)
    ..lineTo(c.dx + t, c.dy + t)
    ..lineTo(c.dx + t, c.dy + r)
    ..lineTo(c.dx - t, c.dy + r)
    ..lineTo(c.dx - t, c.dy + t)
    ..lineTo(c.dx - r, c.dy + t)
    ..lineTo(c.dx - r, c.dy - t)
    ..lineTo(c.dx - t, c.dy - t)
    ..close();
}
