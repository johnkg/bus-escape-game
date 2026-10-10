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

LaneDelta tap(GameState s, int id) {
  final b = s.busById(id)!;
  return laneDelta(s, Rules.tap(s, id).state, b);
}

void main() {
  test('plain exit: parks in first free slot, nothing boards', () {
    final s = start([bus(0, 0, 0)], [1, 1]);
    final d = tap(s, 0);
    expect(d.slot, 0);
    expect(d.boardedSlots, isEmpty);
    expect(d.departed, isEmpty);
    expect(d.before[0]?.boarded, 0);
  });

  test('partial boarding into the new bus', () {
    final s = start([bus(0, 0, 0)], [0, 0]);
    final d = tap(s, 0);
    expect(d.boardedSlots, [0]);
    expect(d.departed, isEmpty);
  });

  test('new bus fills up and departs in the same move', () {
    final s = start([bus(0, 0, 0)], [0, 0, 0, 0]);
    final d = tap(s, 0);
    expect(d.boardedSlots, [0]);
    expect(d.departed.map((e) => e.slot), [0]);
    expect(d.departed.single.bus.isFull, isTrue);
  });

  test('passengers waiting at the front board an earlier-parked bus', () {
    var s = start([bus(0, 0, 0), bus(1, 0, 1), bus(2, 1, 2)], [1, 0, 0]);
    s = Rules.tap(s, 0).state;
    s = Rules.tap(s, 1).state;
    final d = tap(s, 2);
    expect(d.slot, 2);
    expect(d.boardedSlots, [0, 2]); // leftmost bus gets the colour-0 pair
    expect(d.departed, isEmpty);
    // The pre-boarding snapshot still shows the old counts.
    expect(d.before[0]?.boarded, 0);
  });

  test('an earlier-parked bus fills up and departs', () {
    var s = start([bus(0, 0, 0), bus(1, 1, 1)], [1, 0, 0, 0, 0]);
    s = Rules.tap(s, 0).state;
    final d = tap(s, 1);
    expect(d.departed.map((e) => e.slot), [0]);
    expect(d.boardedSlots, [0, 1]);
    expect(d.before[0]?.boarded, 0);
  });

  test('sort: no vehicle parks, earlier-parked bus fills and departs', () {
    var s = start([bus(0, 0, 0), bus(1, 1, 1)], [1, 0, 0, 0, 0, 1, 1, 1]);
    s = Rules.tap(s, 0).state;
    final after = Rules.sortQueue(s)!;
    final d = laneDelta(s, after, null);
    expect(d.slot, -1);
    expect(d.boardedSlots, [0]);
    expect(d.departed.map((e) => e.slot), [0]);
    expect(d.before[0]?.boarded, 0);
    expect(eventsForSort(s, after), [GameEvent.board, GameEvent.depart]);
  });
}
