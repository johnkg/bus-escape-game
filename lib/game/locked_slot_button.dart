import 'package:flame/components.dart';
import 'package:flame/events.dart';

import 'bus_escape_game.dart';
import 'layers.dart';

/// Invisible tap target over a locked lane slot.
class LockedSlotButton extends PositionComponent
    with TapCallbacks, HasGameReference<BusEscapeGame> {
  LockedSlotButton(this.slot) : super(priority: Layer.slotButton);

  final int slot;

  @override
  void onLoad() {
    final r = game.layout.laneSlotRect(slot);
    position = Vector2(r.left, r.top);
    size = Vector2(r.width, r.height);
  }

  @override
  void onTapDown(TapDownEvent event) => game.onUnlockRequested?.call();
}
