import '../core/core.dart';
import '../services/feedback_service.dart';

/// Which sounds/haptics a successful tap should trigger, in order.
List<GameEvent> eventsForMove(GameState before, GameState after) => [
  GameEvent.busExit,
  ..._afterEvents(before, after, vehicleParked: true),
];

/// Same for the Sort booster: nothing exits, so it starts with boarding.
List<GameEvent> eventsForSort(GameState before, GameState after) =>
    _afterEvents(before, after, vehicleParked: false);

List<GameEvent> _afterEvents(
  GameState before,
  GameState after, {
  required bool vehicleParked,
}) {
  final events = <GameEvent>[];

  if (after.queue.length < before.queue.length) events.add(GameEvent.board);

  // A vehicle that left the grid took a slot; compare occupancy.
  final parkedBefore =
      before.lane.where((p) => p != null).length + (vehicleParked ? 1 : 0);
  final parkedAfter = after.lane.where((p) => p != null).length;
  if (parkedAfter < parkedBefore) events.add(GameEvent.depart);

  switch (after.status) {
    case GameStatus.won:
      events.add(GameEvent.win);
    case GameStatus.lost:
      events.add(GameEvent.lose);
    case GameStatus.playing:
      break;
  }
  return events;
}
