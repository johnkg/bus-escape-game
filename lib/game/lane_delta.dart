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
  });

  /// Slot the exiting bus parked in.
  final int slot;

  /// Lane right after the bus parked but before anyone boarded.
  final List<ParkedBus?> before;

  /// Slots (ascending) where at least one passenger boarded.
  final List<int> boardedSlots;
  final List<DepartedBus> departed;
}

/// [exited] is the vehicle that just left the jam, or null when nothing
/// parked (the Sort booster); then [LaneDelta.slot] is -1.
LaneDelta laneDelta(GameState before, GameState after, Bus? exited) {
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

  final boarded = <int>[];
  final departed = <DepartedBus>[];
  for (var i = 0; i < parked.length; i++) {
    final b = parked[i];
    final a = after.lane[i];
    if (b == null) continue;
    if (a == null) {
      boarded.add(i);
      departed.add(DepartedBus(i, b.withBoarded(b.capacity)));
    } else if (a.boarded > b.boarded) {
      boarded.add(i);
    }
  }
  return LaneDelta(
    slot: slot,
    before: parked,
    boardedSlots: boarded,
    departed: departed,
  );
}
