import 'package:bus_escape_game/core/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('levels up to 300 generate and win', () {
    final sw = Stopwatch()..start();
    var maxMs = 0;
    for (var n = 1; n <= 300; n++) {
      final t = sw.elapsedMilliseconds;
      final level = LevelGenerator.generate(n);
      final session = GameSession(level);
      for (final id in Solver.orderFor(level)!) {
        session.tap(id);
      }
      expect(session.state.status, GameStatus.won);
      final d = sw.elapsedMilliseconds - t;
      if (d > maxMs) maxMs = d;
    }
    // ignore: avoid_print
    print('total ${sw.elapsedMilliseconds}ms, slowest level ${maxMs}ms');
    expect(maxMs, lessThan(3000));
  });
}
