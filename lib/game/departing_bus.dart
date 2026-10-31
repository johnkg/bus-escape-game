import 'dart:ui';

import '../core/core.dart';
import 'layers.dart';
import 'paint_helpers.dart';
import 'parked_vehicle_painter.dart';
import 'timed_effect.dart';

/// A full bus pulling away from the lane: slides up and fades out.
class DepartingBus extends TimedEffect {
  DepartingBus({required this.slot, required this.bus})
    : super(lifetime: _seconds, priority: Layer.departing);

  static const double _seconds = 0.45;

  /// How far it drives up before it has faded out, and the margin of the
  /// fading layer around its bay.
  static const double _driveOff = 100;
  static const double _layerMargin = 20;

  final int slot;
  final ParkedBus bus;

  @override
  void render(Canvas canvas) {
    final p = progress;
    final rect = game.layout.laneSlotRect(slot);
    saveFadeLayer(canvas, rect.inflate(_layerMargin), 1 - p);
    canvas.translate(0, -p * p * _driveOff);
    paintLaneVehicle(canvas, rect, bus, symbols: game.showSymbols);
    canvas.restore();
  }
}
