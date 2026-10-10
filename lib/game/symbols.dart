import 'dart:math';
import 'dart:ui';

import 'palette.dart';

/// One distinct shape per bus color so the game works without telling
/// colors apart (shown when the "Color symbols" setting is on).
enum SymbolShape { circle, square, triangle, diamond, star, hexagon }

SymbolShape symbolFor(int colorIndex) =>
    SymbolShape.values[colorIndex %
        busColors.length %
        SymbolShape.values.length];

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
