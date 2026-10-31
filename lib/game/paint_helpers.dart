import 'dart:ui';

import 'palette.dart';

/// Fills [rect] with [color], its corners rounded by [radius].
void fillRounded(Canvas canvas, Rect rect, Color color, double radius) =>
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      Paint()..color = color,
    );

/// Offset and spread of the shadow every vehicle casts on the ground.
const Offset _groundShadowOffset = Offset(1.5, 2.5);
const double _groundShadowSpread = 1;

/// The soft shadow under a vehicle whose body is [body].
void paintGroundShadow(Canvas canvas, Rect body, Radius radius) =>
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body.shift(_groundShadowOffset).inflate(_groundShadowSpread),
        radius,
      ),
      Paint()..color = shadowColor,
    );

/// Starts a layer over [bounds] drawn at [opacity]; pair with
/// `canvas.restore()`.
void saveFadeLayer(Canvas canvas, Rect bounds, double opacity) =>
    canvas.saveLayer(bounds, Paint()..color = Color.fromRGBO(0, 0, 0, opacity));
