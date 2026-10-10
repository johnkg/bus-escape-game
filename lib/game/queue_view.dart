import 'dart:ui';

import 'package:flame/components.dart';

import 'bus_escape_game.dart';
import 'layout.dart';
import 'palette.dart';
import 'symbols.dart';
import 'vehicle_painter.dart';

/// Waiting passengers as little people in a line from the depot door.
class QueueView extends PositionComponent with HasGameReference<BusEscapeGame> {
  QueueView() : super(priority: 5);

  @override
  void render(Canvas canvas) {
    final q = game.queueShown ?? game.session.state.queue;
    final n = q.length < GameLayout.queueVisible
        ? q.length
        : GameLayout.queueVisible;
    final layout = game.layout;
    // Back of the line first so the front person is drawn on top.
    for (var i = n - 1; i >= 0; i--) {
      final p = layout.queuePoint(i);
      canvas.drawOval(
        Rect.fromCenter(center: p.translate(0, 13), width: 14, height: 5),
        Paint()..color = const Color(0x22000000),
      );
      paintPerson(canvas, p, busColors[q[i] % busColors.length]);
      if (game.showSymbols) {
        paintSymbol(canvas, p.translate(0, 4), 8, symbolFor(q[i]));
      }
    }
  }
}
