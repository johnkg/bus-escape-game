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

/// Where a passenger's symbol sits on its body, and how big it is.
const double _personSymbolDrop = 4;
const double _personSymbolSize = 8;

/// The color symbol on a passenger standing at [c].
void paintPersonSymbol(Canvas canvas, Offset c, int colorIndex) => paintSymbol(
  canvas,
  c.translate(0, _personSymbolDrop),
  _personSymbolSize,
  symbolFor(colorIndex),
);

/// Draws a white shape with a dark outline, centered on [c], about [size]
/// across.
void paintSymbol(Canvas canvas, Offset c, double size, SymbolShape shape) {
  final r = size / 2;
  final path = switch (shape) {
    SymbolShape.circle =>
      (Path()..addOval(Rect.fromCircle(center: c, radius: r))),
    SymbolShape.square =>
      (Path()..addRect(
        Rect.fromCenter(
          center: c,
          width: size * _squareSide,
          height: size * _squareSide,
        ),
      )),
    SymbolShape.triangle => _polygon(c, r * _pointyScale, 3, -pi / 2),
    SymbolShape.diamond => _polygon(c, r * _pointyScale, 4, -pi / 2),
    SymbolShape.star => _star(c, r * _starScale),
    SymbolShape.hexagon => _polygon(c, r, 6, 0),
    SymbolShape.octagon => _polygon(c, r * _octagonScale, 8, pi / 8),
    SymbolShape.drop => _drop(c, r),
    SymbolShape.cross => _cross(c, r * _pointyScale),
  };
  canvas.drawPath(
    path,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(_minOutline, size * _outlineShare)
      ..strokeJoin = StrokeJoin.round
      ..color = symbolOutline,
  );
  canvas.drawPath(path, Paint()..color = white);
}

// Shapes with corners are drawn a little larger so they look as big as the
// circle; outlines scale with the symbol but never get too thin.
const double _squareSide = 0.85;
const double _pointyScale = 1.1;
const double _starScale = 1.15;
const double _octagonScale = 1.05;
const double _outlineShare = 0.14;
const double _minOutline = 1.5;
const int _starPoints = 5;
const double _starInner = 0.45;

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
  for (var i = 0; i < _starPoints * 2; i++) {
    final radius = i.isEven ? r : r * _starInner;
    final a = -pi / 2 + pi * i / _starPoints;
    final p = Offset(c.dx + radius * cos(a), c.dy + radius * sin(a));
    i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
  }
  return path..close();
}

// Drop outline: a point on top and a round bottom, in radii.
const double _dropTip = 1.15;
const double _dropShoulder = 0.1;
const double _dropBelly = 0.9;
const double _dropBottom = 0.95;

Path _drop(Offset c, double r) => Path()
  ..moveTo(c.dx, c.dy - r * _dropTip)
  ..cubicTo(
    c.dx + r,
    c.dy - r * _dropShoulder,
    c.dx + r * _dropBelly,
    c.dy + r * _dropBottom,
    c.dx,
    c.dy + r * _dropBottom,
  )
  ..cubicTo(
    c.dx - r * _dropBelly,
    c.dy + r * _dropBottom,
    c.dx - r,
    c.dy - r * _dropShoulder,
    c.dx,
    c.dy - r * _dropTip,
  )
  ..close();

/// Half the thickness of a cross arm, in radii.
const double _crossHalfArm = 0.38;

Path _cross(Offset c, double r) {
  final t = r * _crossHalfArm;
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
