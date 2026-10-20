import 'package:bus_escape_game/services/progress_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProgressService> load([Map<String, Object> initial = const {}]) async {
  SharedPreferences.setMockInitialValues(initial);
  return ProgressService.load();
}

void main() {
  test('defaults', () async {
    final p = await load();
    expect(p.unlockedLevel, 1);
    expect(p.bestMoves(1), isNull);
    expect(p.undoBoosters, 3);
    for (final b in Booster.values) {
      expect(p.boosterCount(b), 3, reason: b.name);
    }
    expect(p.hintBoosters, 3);
    expect(p.soundOn, isTrue);
    expect(p.musicOn, isTrue);
    expect(p.hapticsOn, isTrue);
    expect(p.symbolsOn, isFalse); // opt-in accessibility aid
  });

  test('winning a level unlocks the next and records best moves', () async {
    final p = await load();
    expect(await p.recordWin(1, 9), isFalse);
    expect(p.unlockedLevel, 2);
    expect(p.bestMoves(1), 9);
    await p.recordWin(1, 12); // worse: best stays
    expect(p.bestMoves(1), 9);
    await p.recordWin(1, 7); // better
    expect(p.bestMoves(1), 7);
  });

  test('replaying an earlier level never lowers progress', () async {
    final p = await load();
    await p.recordWin(1, 5);
    await p.recordWin(2, 5);
    await p.recordWin(1, 4);
    expect(p.unlockedLevel, 3);
  });

  test('progress survives a reload', () async {
    final p = await load();
    await p.recordWin(1, 5);
    await p.setSoundOn(false);
    final p2 = await ProgressService.load(); // same mock store
    expect(p2.unlockedLevel, 2);
    expect(p2.soundOn, isFalse);
  });

  test('boosters can be spent and refilled but not below zero', () async {
    final p = await load();
    expect(await p.useBooster(Booster.undo), isTrue);
    expect(p.undoBoosters, 2);
    await p.useBooster(Booster.undo);
    await p.useBooster(Booster.undo);
    expect(await p.useBooster(Booster.undo), isFalse);
    expect(p.undoBoosters, 0);
    await p.addBooster(Booster.undo, 2);
    expect(p.undoBoosters, 2);
  });

  test('reset clears progress but keeps settings', () async {
    final p = await load();
    await p.recordWin(1, 5);
    await p.setHapticsOn(false);
    await p.useBooster(Booster.sort);
    await p.reset();
    expect(p.unlockedLevel, 1);
    expect(p.bestMoves(1), isNull);
    for (final b in Booster.values) {
      expect(p.boosterCount(b), 3, reason: b.name);
    }
    expect(p.hapticsOn, isFalse);
  });

  test('first clear of every 5th level rewards one of each booster', () async {
    final p = await load();
    expect(await p.recordWin(4, 5), isFalse);
    expect(p.undoBoosters, 3);
    expect(await p.recordWin(5, 5), isTrue);
    expect(p.undoBoosters, 4);
    for (final b in Booster.values) {
      expect(p.boosterCount(b), 4, reason: b.name);
    }
    expect(p.hintBoosters, 4);
    // Replaying the same level gives nothing more.
    expect(await p.recordWin(5, 4), isFalse);
    expect(p.undoBoosters, 4);
  });

  test('symbols setting persists and survives a reset', () async {
    final p = await load();
    await p.setSymbolsOn(true);
    expect((await ProgressService.load()).symbolsOn, isTrue);
    await p.reset();
    expect(p.symbolsOn, isTrue);
  });

  test('stars: default 0, best kept, total summed', () async {
    final p = await load();
    expect(p.stars(1), 0);
    await p.recordWin(1, 5, stars: 2);
    expect(p.stars(1), 2);
    await p.recordWin(1, 5, stars: 1); // worse run keeps the best
    expect(p.stars(1), 2);
    await p.recordWin(1, 5, stars: 3);
    expect(p.stars(1), 3);
    await p.recordWin(2, 5, stars: 1);
    expect(p.totalStars, 4);
  });

  test('reset clears stars', () async {
    final p = await load();
    await p.recordWin(1, 5, stars: 3);
    await p.reset();
    expect(p.stars(1), 0);
    expect(p.totalStars, 0);
  });

  group('coins', () {
    test('start with a small purse', () async {
      final p = await load();
      expect(p.coins, ProgressService.startingCoins);
    });

    test('can be added and spent, never below zero', () async {
      final p = await load();
      await p.addCoins(50);
      expect(p.coins, ProgressService.startingCoins + 50);
      expect(await p.spendCoins(p.coins + 1), isFalse);
      expect(p.coins, ProgressService.startingCoins + 50);
      expect(await p.spendCoins(p.coins), isTrue);
      expect(p.coins, 0);
    });

    test('first clear pays by stars, replays pay only for improvement', () {
      expect(ProgressService.winCoins(previousStars: 0, stars: 1), 30);
      expect(ProgressService.winCoins(previousStars: 0, stars: 3), 50);
      expect(ProgressService.winCoins(previousStars: 1, stars: 3), 20);
      expect(ProgressService.winCoins(previousStars: 3, stars: 3), 0);
      expect(ProgressService.winCoins(previousStars: 3, stars: 1), 0);
    });

    test('survive a reload; reset gives the starting purse back', () async {
      final p = await load();
      await p.addCoins(25);
      expect(
        (await ProgressService.load()).coins,
        ProgressService.startingCoins + 25,
      );
      await p.reset();
      expect(p.coins, ProgressService.startingCoins);
    });
  });

  test('notifies listeners on change', () async {
    final p = await load();
    var n = 0;
    p.addListener(() => n++);
    await p.recordWin(1, 5);
    expect(n, greaterThan(0));
  });

  group('daily challenge', () {
    final mon = DateTime(2026, 10, 19);
    final tue = DateTime(2026, 10, 20);
    final thu = DateTime(2026, 10, 22);

    test('pays once a day and builds a streak on consecutive days', () async {
      final p = await load();
      expect(p.dailyDone(mon), isFalse);
      expect(p.dailyStreak(mon), 0);

      expect(await p.recordDaily(mon), ProgressService.dailyCoins(1));
      expect(p.dailyDone(mon), isTrue);
      expect(p.dailyStreak(mon), 1);
      expect(p.coins, ProgressService.startingCoins + 50);

      // A replay the same day pays nothing and keeps the streak.
      expect(await p.recordDaily(mon), 0);
      expect(p.dailyStreak(mon), 1);

      expect(await p.recordDaily(tue), ProgressService.dailyCoins(2));
      expect(p.dailyStreak(tue), 2);
    });

    test('a missed day resets the streak', () async {
      final p = await load();
      await p.recordDaily(mon);
      await p.recordDaily(tue);
      expect(p.dailyStreak(thu), 0);
      await p.recordDaily(thu);
      expect(p.dailyStreak(thu), 1);
    });

    test('does not touch level progress', () async {
      final p = await load();
      await p.recordDaily(mon);
      expect(p.unlockedLevel, 1);
      expect(p.totalStars, 0);
    });

    test('coin reward grows with the streak up to a week', () {
      expect(ProgressService.dailyCoins(1), 50);
      expect(ProgressService.dailyCoins(7), 110);
      expect(ProgressService.dailyCoins(30), 110);
    });
  });
}
