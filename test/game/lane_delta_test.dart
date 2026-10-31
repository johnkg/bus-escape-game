import 'package:bus_escape_game/core/core.dart';
import 'package:bus_escape_game/game/lane_delta.dart';
import 'package:bus_escape_game/game/tap_events.dart';
import 'package:bus_escape_game/services/feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';

Bus bus(int id, int color, int row) => Bus(
  id: id,
  colorIndex: color,
  row: row,
  col: 0,
  length: 2,
  dir: Direction.east,
);

GameState start(List<Bus> buses, List<int> queue, {int slots = 5}) => Level(
  id: 1,
  rows: 4,
  cols: 4,
  buses: buses,
  queue: queue,
  laneSlots: slots,
).toState();

LaneDelta tap(GameState s, int id) => laneDelta(s, s.busById(id)!);

/// (bus id, passenger color) for each passenger, in boarding order.
List<(int, int)> boarding(LaneDelta d) => [
  for (final step in d.boardingOrder) (step.busId, step.color),
];

void main() {
  test('plain exit: parks in first free slot, nothing boards', () {
    final s = start([bus(0, 0, 0)], [1, 1]);
    final d = tap(s, 0);
    expect(d.slot, 0);
    expect(boarding(d), isEmpty);
    expect(d.before[0]?.boarded, 0);
  });

  test('partial boarding into the new bus', () {
    final s = start([bus(0, 0, 0)], [0, 0]);
    expect(boarding(tap(s, 0)), [(0, 0), (0, 0)]);
  });

  test('boarding stops once the new bus is full', () {
    final s = start([bus(0, 0, 0)], [0, 0, 0, 0, 0]);
    expect(boarding(tap(s, 0)), List.filled(4, (0, 0)));
  });

  test('passengers waiting at the front board an earlier-parked bus', () {
    var s = start([bus(0, 0, 0), bus(1, 0, 1), bus(2, 1, 2)], [1, 0, 0]);
    s = Rules.tap(s, 0).state;
    s = Rules.tap(s, 1).state;
    final d = tap(s, 2);
    expect(d.slot, 2);
    // The leftmost colour-0 bus gets the colour-0 pair.
    expect(boarding(d), [(2, 1), (0, 0), (0, 0)]);
    // The pre-boarding snapshot still shows the old counts.
    expect(d.before[0]?.boarded, 0);
  });

  test('an earlier-parked bus fills up and departs', () {
    var s = start([bus(0, 0, 0), bus(1, 1, 1)], [1, 0, 0, 0, 0]);
    s = Rules.tap(s, 0).state;
    final d = tap(s, 1);
    expect(boarding(d), [(1, 1), (0, 0), (0, 0), (0, 0), (0, 0)]);
    expect(d.before[0]?.boarded, 0);
  });

  test('sort: no vehicle parks, earlier-parked bus fills and departs', () {
    var s = start([bus(0, 0, 0), bus(1, 1, 1)], [1, 0, 0, 0, 0, 1, 1, 1]);
    s = Rules.tap(s, 0).state;
    final after = Rules.sortQueue(s)!;
    final d = laneDelta(s, null, queue: Rules.sortedQueue(s));
    expect(d.slot, -1);
    expect(boarding(d), List.filled(4, (0, 0)));
    expect(d.before[0]?.boarded, 0);
    expect(eventsForSort(s, after), [GameEvent.board, GameEvent.depart]);
  });

  test('passengers board in queue order, not in vehicle order', () {
    // Vehicle 0 (colour 0) is parked first; the queue starts with colour 1.
    var s = start([bus(0, 0, 0), bus(1, 1, 1)], [1, 0, 1, 0]);
    s = Rules.tap(s, 0).state;
    final d = tap(s, 1);
    expect(boarding(d), [(1, 1), (0, 0), (1, 1), (0, 0)]);
  });
}
