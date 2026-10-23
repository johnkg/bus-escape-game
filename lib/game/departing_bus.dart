import 'dart:ui';

import 'package:flame/components.dart';

import '../core/core.dart';
import 'bus_escape_game.dart';
import 'parked_vehicle_painter.dart';
import 'layers.dart';

/// A full bus pulling away from the lane: slides up and fades out.
class DepartingBus extends PositionComponent
    with HasGameReference<BusEscapeGame> {
  DepartingBus({required this.slot, required this.bus})
    : super(priority: Layer.departing);

  static const double duration = 0.45;

  /// How far it drives up before it has faded out, and the margin of the
  /// fading layer around its bay.
  static const double _driveOff = 100;
  static const double _layerMargin = 20;

  final int slot;
  final ParkedBus bus;
  double _t = 0;

  @override
  void update(double dt) {
    _t += dt;
    if (_t >= duration) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final p = (_t / duration).clamp(0.0, 1.0);
    final rect = game.layout.laneSlotRect(slot);
    canvas.saveLayer(
      rect.inflate(_layerMargin),
      Paint()..color = Color.fromRGBO(0, 0, 0, 1 - p),
    );
    canvas.translate(0, -p * p * _driveOff);
    paintLaneVehicle(canvas, rect, bus, symbols: game.showSymbols);
    canvas.restore();
  }
}
