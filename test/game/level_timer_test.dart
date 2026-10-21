import 'package:bus_escape_game/game/level_timer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('untimed until started', () {
    final t = LevelTimer();
    expect(t.timeLeft.value, isNull);
    t.tick(100);
    expect(t.timeUp.value, isFalse);
    expect(t.fraction, 0);
  });

  test('counts down in whole seconds and runs out once', () {
    final t = LevelTimer()..start(10);
    expect(t.timeLeft.value, 10);
    t.tick(2.5);
    expect(t.timeLeft.value, 8);
    expect(t.fraction, closeTo(0.75, 1e-9));

    var expiring = 0;
    t.tick(
      8,
      onExpiring: () {
        expiring++;
        expect(t.timeUp.value, isFalse, reason: 'runs before timeUp flips');
      },
    );
    expect(t.timeLeft.value, 0);
    expect(t.timeUp.value, isTrue);
    t.tick(1, onExpiring: () => expiring++);
    expect(expiring, 1);
  });

  test('restarting resets the clock', () {
    final t = LevelTimer()..start(3);
    t.tick(5);
    expect(t.timeUp.value, isTrue);
    t.start(6);
    expect(t.timeUp.value, isFalse);
    expect(t.timeLeft.value, 6);
  });
}
