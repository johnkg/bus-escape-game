import '../core/core.dart';

class DepartedBus {
  const DepartedBus(this.slot, this.bus);

  final int slot;

  /// Snapshot of the bus at the moment it filled up (full).
  final ParkedBus bus;
}

/// What a single tap changed in the lane; drives the animations.
class LaneDelta {
  const LaneDelta({
    required this.slot,
    required this.before,
    required this.boardedSlots,
    required this.departed,
    this.boardCounts = const {},
    this.boardingOrder = const [],
  });

  /// Slot the exiting bus parked in.
  final int slot;

  /// Lane right after the bus parked but before anyone boarded.
  final List<ParkedBus?> before;

  /// Slots (ascending) where at least one passenger boarded.
  final List<int> boardedSlots;
  final List<DepartedBus> departed;

  /// Passengers who boarded, per slot.
  final Map<int, int> boardCounts;

  /// Who boards which vehicle, in the order the passengers leave the queue.
  final List<({int busId, int color})> boardingOrder;
}

/// [exited] is the vehicle that just left the jam, or null when nothing
/// parked (the Sort booster); then [LaneDelta.slot] is -1.
///
/// [queue] is the queue boarding starts from; it defaults to the queue
/// before the move (the Sort booster reorders it first).
LaneDelta laneDelta(
  GameState before,
  GameState after,
  Bus? exited, {
  List<int>? queue,
}) {
  final parked = [...before.lane];
  var slot = -1;
  if (exited != null) {
    slot = before.lane.indexOf(null);
    parked[slot] = ParkedBus(
      id: exited.id,
      colorIndex: exited.colorIndex,
      capacity: exited.capacity,
    );
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

  final boarded = <int>[];
  final departed = <DepartedBus>[];
  final counts = <int, int>{};
  for (var i = 0; i < parked.length; i++) {
    final b = parked[i];
    final a = after.lane[i];
    if (b == null) continue;
    if (a == null) {
      boarded.add(i);
      counts[i] = b.capacity - b.boarded;
      departed.add(DepartedBus(i, b.withBoarded(b.capacity)));
    } else if (a.boarded > b.boarded) {
      boarded.add(i);
      counts[i] = a.boarded - b.boarded;
    }
  }
  return LaneDelta(
    slot: slot,
    before: parked,
    boardedSlots: boarded,
    departed: departed,
    boardCounts: counts,
    boardingOrder: order,
  );
}
