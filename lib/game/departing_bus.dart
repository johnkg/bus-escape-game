import 'dart:ui';

import 'package:flame/components.dart';

import '../core/core.dart';
import 'bus_escape_game.dart';
import 'lane_view.dart';

/// A full bus pulling away from the lane: slides up and fades out.
class DepartingBus extends PositionComponent
    with HasGameReference<BusEscapeGame> {
  DepartingBus({required this.slot, required this.bus}) : super(priority: 2);

  static const double duration = 0.45;

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
      rect.inflate(20),
      Paint()..color = Color.fromRGBO(0, 0, 0, 1 - p),
    );
    canvas.translate(0, -p * p * 100);
    paintLaneVehicle(canvas, rect, bus, symbols: game.showSymbols);
    canvas.restore();
  }
}
