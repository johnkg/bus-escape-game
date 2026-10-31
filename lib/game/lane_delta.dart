import '../core/core.dart';

/// What a single tap changed in the lane; drives the animations.
class LaneDelta {
  const LaneDelta({
    required this.slot,
    required this.before,
    required this.boardingOrder,
  });

  /// Slot the exiting bus parked in.
  final int slot;

  /// Lane right after the bus parked but before anyone boarded.
  final List<ParkedBus?> before;

  /// Who boards which vehicle, in the order the passengers leave the queue.
  final List<({int busId, int color})> boardingOrder;
}

/// [exited] is the vehicle that just left the jam, or null when nothing
/// parked (the Sort booster); then [LaneDelta.slot] is -1.
///
/// [queue] is the queue boarding starts from; it defaults to the queue
/// before the move (the Sort booster reorders it first).
LaneDelta laneDelta(GameState before, Bus? exited, {List<int>? queue}) {
  final parked = [...before.lane];
  var slot = -1;
  if (exited != null) {
    slot = before.lane.indexOf(null);
    parked[slot] = ParkedBus.fromBus(exited);
  }

  // Replays boarding: each passenger takes the leftmost matching vehicle
  // with a free seat, until the front of the queue matches nothing.
  final free = [for (final p in parked) p == null ? 0 : p.capacity - p.boarded];
  final order = <({int busId, int color})>[];
  for (final color in queue ?? before.queue) {
    final i = [for (var k = 0; k < parked.length; k++) k].indexWhere(
      (k) => parked[k] != null && parked[k]!.colorIndex == color && free[k] > 0,
    );
    if (i < 0) break;
    free[i]--;
    order.add((busId: parked[i]!.id, color: color));
  }
  return LaneDelta(slot: slot, before: parked, boardingOrder: order);
}
