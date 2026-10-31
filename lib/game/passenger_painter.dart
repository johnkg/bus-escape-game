import 'dart:math';
import 'dart:ui';

import '../core/core.dart';
import 'paint_helpers.dart';
import 'palette.dart';

/// Passenger figure dimensions at scale 1, in pixels, measured from the
/// centre of the body.
abstract final class _Person {
  static const double headRise = 5.5;
  static const double headRadius = 5;
  static const double faceRadius = 4.2;
  static const double bodyDrop = 4;
  static const double bodyWidth = 11;
  static const double bodyHeight = 13;
  static const double bodyRadius = 4;
  static const double outline = 1;
  static const double outlineDarken = -0.2;

  // Police cap (crown and peak) and badge.
  static const double capRise = 3.2;
  static const double capWidth = 10;
  static const double capHeight = 4.2;
  static const double capRadius = 2;
  static const double peakRise = 1.2;
  static const double peakWidth = 11;
  static const double peakHeight = 1.6;
  static const double peakRadius = 1;
  static const Offset badge = Offset(2.5, 2.5);
  static const double badgeRadius = 1.3;

  // Paramedic cap and firefighter helmet: a half dome over the head.
  static const double domeRise = 0.6;
  static const double domeWidth = 11;
  static const double domeHeight = 10;
  static const double crossRise = 3;
  static const double crossArm = 1.6;
  static const double crossWidth = 1.3;
  static const double helmetBandRise = 0.5;
  static const double helmetBandWidth = 12;
  static const double helmetBandHeight = 1.4;
  static const double helmetBandRadius = 0.7;

  // Chest band (paramedic red, firefighter reflective yellow).
  static const double bandDrop = 5.5;
  static const double bandWidth = 11;
  static const double bandHeight = 2;
  static const double bandRadius = 0.8;
}

/// A little passenger standing at [c] (center of the body). Ordinary
/// passengers are a blob in their color; police wear a cap and a badge,
/// paramedics a white cap with a red cross, firefighters a helmet and a
/// reflective stripe.
void paintPassenger(
  Canvas canvas,
  Offset c,
  int colorIndex, {
  double scale = 1,
}) {
  if (!isServiceColor(colorIndex)) {
    _paintPerson(canvas, c, colorFor(colorIndex), scale: scale);
    return;
  }
  final police = colorIndex == policeColor;
  final paramedic = colorIndex == ambulanceColor;
  final bodyColor = police
      ? policeBlue
      : paramedic
      ? paramedicTeal
      : firefighterCoat;
  _paintPerson(canvas, c, bodyColor, scale: scale);
  final head = c.translate(0, -_Person.headRise * scale);
  canvas.drawCircle(
    head,
    _Person.faceRadius * scale,
    Paint()..color = skinColor,
  );
  if (police) {
    // Cap with a peak and a gold badge.
    fillRounded(
      canvas,
      Rect.fromCenter(
        center: head.translate(0, -_Person.capRise * scale),
        width: _Person.capWidth * scale,
        height: _Person.capHeight * scale,
      ),
      policeCapColor,
      _Person.capRadius * scale,
    );
    fillRounded(
      canvas,
      Rect.fromCenter(
        center: head.translate(0, -_Person.peakRise * scale),
        width: _Person.peakWidth * scale,
        height: _Person.peakHeight * scale,
      ),
      policeCapColor,
      _Person.peakRadius * scale,
    );
    canvas.drawCircle(
      c + _Person.badge * scale,
      _Person.badgeRadius * scale,
      Paint()..color = hiVisYellow,
    );
  } else if (paramedic) {
    // White cap with a small red cross, and a red band on the chest.
    _paintDome(canvas, head, scale, white);
    final cap = head.translate(0, -_Person.crossRise * scale);
    final arm = _Person.crossArm * scale;
    final cross = Paint()
      ..color = crossRed
      ..strokeWidth = _Person.crossWidth * scale;
    canvas.drawLine(cap.translate(-arm, 0), cap.translate(arm, 0), cross);
    canvas.drawLine(cap.translate(0, -arm), cap.translate(0, arm), cross);
    _paintChestBand(canvas, c, scale, crossRed);
  } else {
    // Helmet and reflective stripe.
    _paintDome(canvas, head, scale, hiVisYellow);
    fillRounded(
      canvas,
      Rect.fromCenter(
        center: head.translate(0, -_Person.helmetBandRise * scale),
        width: _Person.helmetBandWidth * scale,
        height: _Person.helmetBandHeight * scale,
      ),
      crossRed,
      _Person.helmetBandRadius * scale,
    );
    _paintChestBand(canvas, c, scale, hiVisYellow);
  }
}

void _paintDome(Canvas canvas, Offset head, double scale, Color color) =>
    canvas.drawArc(
      Rect.fromCenter(
        center: head.translate(0, -_Person.domeRise * scale),
        width: _Person.domeWidth * scale,
        height: _Person.domeHeight * scale,
      ),
      pi,
      pi,
      true,
      Paint()..color = color,
    );

void _paintChestBand(Canvas canvas, Offset c, double scale, Color color) =>
    fillRounded(
      canvas,
      Rect.fromCenter(
        center: c.translate(0, _Person.bandDrop * scale),
        width: _Person.bandWidth * scale,
        height: _Person.bandHeight * scale,
      ),
      color,
      _Person.bandRadius * scale,
    );

/// A plain little figure in [color] standing at [c] (center of the body).
void _paintPerson(Canvas canvas, Offset c, Color color, {double scale = 1}) {
  final dark = shade(color, _Person.outlineDarken);
  final outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = _Person.outline
    ..color = dark;
  final body = RRect.fromRectAndRadius(
    Rect.fromCenter(
      center: c.translate(0, _Person.bodyDrop * scale),
      width: _Person.bodyWidth * scale,
      height: _Person.bodyHeight * scale,
    ),
    Radius.circular(_Person.bodyRadius * scale),
  );
  canvas.drawRRect(body, Paint()..color = color);
  canvas.drawRRect(body, outline);
  final head = c.translate(0, -_Person.headRise * scale);
  canvas.drawCircle(head, _Person.headRadius * scale, Paint()..color = color);
  canvas.drawCircle(head, _Person.headRadius * scale, outline);
}
