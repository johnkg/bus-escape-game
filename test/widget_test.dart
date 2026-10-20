import 'package:bus_escape_game/core/core.dart';
import 'package:bus_escape_game/game/bus_escape_game.dart';
import 'package:bus_escape_game/game/departing_bus.dart';
import 'package:bus_escape_game/main.dart';
import 'package:bus_escape_game/services/feedback_service.dart';
import 'package:bus_escape_game/services/progress_service.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProgressService> loadProgress(
  WidgetTester tester, [
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  return (await tester.runAsync(ProgressService.load))!;
}

void main() {
  testWidgets('menu shows the current level and starts the game', (
    tester,
  ) async {
    final progress = await loadProgress(tester, {'unlocked': 3});
    await tester.pumpWidget(BusEscapeApp(progress: progress));
    expect(find.text('Play  •  Level 3'), findsOneWidget);

    await tester.tap(find.text('Play  •  Level 3'));
    // Flame ticks forever, so pumpAndSettle would never return here.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GameWidget<BusEscapeGame>), findsOneWidget);
    expect(find.text('Level 3'), findsWidgets); // outlined text draws twice
    expect(find.text('Moves 0'), findsOneWidget);
  });

  testWidgets('daily challenge starts from the menu and leaves levels alone', (
    tester,
  ) async {
    final progress = await loadProgress(tester, {'unlocked': 3});
    await tester.pumpWidget(BusEscapeApp(progress: progress));
    await tester.tap(find.byKey(const Key('daily-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(GameWidget<BusEscapeGame>), findsOneWidget);
    expect(find.text('Daily Challenge'), findsWidgets);
    expect(progress.unlockedLevel, 3);
  });

  testWidgets('a timed level shows a clock and ends when it runs out', (
    tester,
  ) async {
    final progress = await loadProgress(tester, {'unlocked': 13});
    final game = await pumpGameScreen(tester, progress, 13);
    expect(game.timeLeft.value, isNotNull);
    expect(find.byKey(const Key('time-chip')), findsOneWidget);

    game.update(game.timeLeft.value! + 1.0);
    await tester.pump();
    expect(game.timeUp.value, isTrue);
    expect(find.text("Time's up!"), findsOneWidget);
    expect(find.byKey(const Key('result-undo')), findsNothing);

    // Taps do nothing once the clock has run out.
    final before = game.session.state.moves;
    game.tapBus(game.session.state.buses.first.id);
    expect(game.session.state.moves, before);
  });

  testWidgets('untimed levels have no clock', (tester) async {
    final progress = await loadProgress(tester, {'unlocked': 12});
    final game = await pumpGameScreen(tester, progress, 12);
    expect(game.timeLeft.value, isNull);
    expect(find.byKey(const Key('time-chip')), findsNothing);
  });

  testWidgets('long-pressing the title jumps to a level without saving', (
    tester,
  ) async {
    final progress = await loadProgress(tester);
    await tester.pumpWidget(BusEscapeApp(progress: progress));
    await tester.longPress(find.byKey(const Key('menu-title')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('jump-field')), '13');
    await tester.tap(find.byKey(const Key('jump-go')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final game = tester
        .widget<GameWidget<BusEscapeGame>>(
          find.byType(GameWidget<BusEscapeGame>),
        )
        .game!;
    expect(game.timeLeft.value, isNotNull); // level 13 is a timed level
    expect(find.text('Practice 13'), findsWidgets);

    // Running the clock out must not touch saved progress.
    game.update(game.timeLeft.value! + 1.0);
    await tester.pump();
    expect(progress.unlockedLevel, 1);
    expect(progress.coins, ProgressService.startingCoins);
  });

  testWidgets('settings opens the stats screen', (tester) async {
    final progress = await loadProgress(tester, {'stars_1': 3, 'stars_2': 1});
    await tester.pumpWidget(BusEscapeApp(progress: progress));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('stats-tile')));
    await tester.pumpAndSettle();
    expect(find.text('Levels cleared'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('stat-Levels cleared'))).data,
      '2',
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('stat-Three-star levels'))).data,
      '1',
    );
  });

  testWidgets('a first-time tip shows once for a timed level', (tester) async {
    final progress = await loadProgress(tester, {'unlocked': 13});
    await pumpGameScreen(tester, progress, 13);
    expect(find.byKey(const Key('tip-banner')), findsOneWidget);
    expect(find.textContaining('Timed level!'), findsOneWidget);
    expect(progress.tipSeen('timed'), isTrue);

    // Tap the banner to dismiss it.
    await tester.tap(find.byKey(const Key('tip-banner')));
    await tester.pump();
    expect(find.byKey(const Key('tip-banner')), findsNothing);
  });

  testWidgets('a tip already seen is not shown again', (tester) async {
    final progress = await loadProgress(tester, {
      'unlocked': 13,
      'tip_timed': true,
    });
    await pumpGameScreen(tester, progress, 13);
    expect(find.byKey(const Key('tip-banner')), findsNothing);
  });

  testWidgets('level select locks levels beyond progress', (tester) async {
    final progress = await loadProgress(tester, {'unlocked': 2});
    await tester.pumpWidget(BusEscapeApp(progress: progress));
    await tester.tap(find.text('Levels'));
    await tester.pumpAndSettle();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsNothing);
    expect(find.byIcon(Icons.lock), findsWidgets);
  });

  testWidgets('level select shows earned stars', (tester) async {
    final progress = await loadProgress(tester, {
      'unlocked': 3,
      'stars_1': 3,
      'stars_2': 1,
    });
    await tester.pumpWidget(BusEscapeApp(progress: progress));
    await tester.tap(find.text('Levels'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.star), findsNWidgets(4)); // 3 + 1 earned
    expect(find.byIcon(Icons.star_border), findsNWidgets(2)); // 0 + 2 missing
  });

  testWidgets('settings toggles persist and reset clears progress', (
    tester,
  ) async {
    final progress = await loadProgress(tester, {'unlocked': 5});
    await tester.pumpWidget(BusEscapeApp(progress: progress));
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sound effects'));
    await tester.pumpAndSettle();
    expect(progress.soundOn, isFalse);

    await tester.tap(find.text('Color symbols'));
    await tester.pumpAndSettle();
    expect(progress.symbolsOn, isTrue);

    await tester.tap(find.text('Reset progress'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(progress.unlockedLevel, 1);
    expect(progress.soundOn, isFalse); // settings kept
  });

  boosterTests();
  feedbackTests();
  animationTests();
  hudTests();
  newBoosterTests();
}

Future<BusEscapeGame> pumpGameScreen(
  WidgetTester tester,
  ProgressService progress,
  int level,
) async {
  await tester.pumpWidget(BusEscapeApp(progress: progress));
  await tester.tap(find.textContaining('Play'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
  return tester
      .widget<GameWidget<BusEscapeGame>>(find.byType(GameWidget<BusEscapeGame>))
      .game!;
}

void boosterTests() {
  group('boosters', () {
    testWidgets('tapping a locked slot buys it with coins', (tester) async {
      final progress = await loadProgress(tester);
      final game = await pumpGameScreen(tester, progress, 1);
      final before = game.session.state.lane.length;
      final coins = progress.coins;

      game.onUnlockRequested!();
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.session.state.lane.length, before + 1);
      expect(progress.coins, coins - ProgressService.slotUnlockCost);
      expect(game.layout.lockedSlots, GameSession.maxExtraSlots - 1);
    });

    testWidgets('a locked slot stays locked when coins are short', (
      tester,
    ) async {
      final progress = await loadProgress(tester, {'coins': 40});
      final game = await pumpGameScreen(tester, progress, 1);
      final before = game.session.state.lane.length;

      game.onUnlockRequested!();
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.session.state.lane.length, before);
      expect(progress.coins, 40);
    });

    testWidgets('undo is disabled until a move is made, then restores it', (
      tester,
    ) async {
      final progress = await loadProgress(tester);
      final game = await pumpGameScreen(tester, progress, 1);

      await tester.tap(find.byKey(const Key('booster-undo')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(progress.undoBoosters, 3); // nothing to undo, nothing spent

      final first = Solver.solve(game.level.toState()).order!.first;
      game.tapBus(first);
      await tester.pump(const Duration(milliseconds: 800));
      expect(game.session.state.moves, 1);

      await tester.tap(find.byKey(const Key('booster-undo')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.session.state.moves, 0);
      expect(game.session.state.buses.length, game.level.buses.length);
      expect(progress.undoBoosters, 2);
    });

    testWidgets('hint highlights a good bus, spends a booster, costs stars', (
      tester,
    ) async {
      final progress = await loadProgress(tester);
      final game = await pumpGameScreen(tester, progress, 1);
      final expected = Hints.nextBus(game.session.state);

      await tester.tap(find.byKey(const Key('booster-hint')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.hintedBusId, expected);
      expect(progress.hintBoosters, 2);

      for (final id in Solver.solve(game.session.state).order!) {
        game.tapBus(id);
        await runFor(tester, 1.5);
      }
      expect(game.session.state.status, GameStatus.won);
      expect(game.session.stars, 1); // help used
      // Passengers now board one by one, so the result dialog waits longer.
      await runFor(tester, 6); // let the result dialog timer finish
    });

    testWidgets('hint button does nothing at zero hints', (tester) async {
      final progress = await loadProgress(tester, {'booster_hint': 0});
      final game = await pumpGameScreen(tester, progress, 1);

      await tester.tap(find.byKey(const Key('booster-hint')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.hintedBusId, isNull);
      expect(progress.hintBoosters, 0);
    });

    testWidgets('undo does nothing at zero boosters', (tester) async {
      final progress = await loadProgress(tester, {'booster_undo': 0});
      final game = await pumpGameScreen(tester, progress, 1);
      game.tapBus(Solver.solve(game.level.toState()).order!.first);
      await runFor(tester, 1.2);

      await tester.tap(find.byKey(const Key('booster-undo')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(game.session.state.moves, 1); // still there
      expect(progress.undoBoosters, 0);
    });
  });
}

class _RecordingSound implements SoundPlayer {
  final List<String> played = [];
  int musicStarts = 0;

  @override
  Future<void> playSfx(String file) async => played.add(file);

  @override
  Future<void> startMusic() async => musicStarts++;

  @override
  Future<void> stopMusic() async {}
}

void feedbackTests() {
  testWidgets('taps and music reach the sound player', (tester) async {
    final progress = await loadProgress(tester, {'unlocked': 2});
    final sound = _RecordingSound();
    await tester.pumpWidget(
      BusEscapeApp(
        progress: progress,
        feedback: FeedbackService(
          settings: progress,
          sound: sound,
          haptics: const NoopHapticsPlayer(),
        ),
      ),
    );
    await tester.tap(find.textContaining('Play'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(sound.musicStarts, 1);

    final game = tester
        .widget<GameWidget<BusEscapeGame>>(
          find.byType(GameWidget<BusEscapeGame>),
        )
        .game!;
    // Tutorial level 2: bus 0 (red) is blocked by bus 1 (blue).
    game.tapBus(0);
    expect(sound.played, ['blocked.wav']);
    game.tapBus(1);
    expect(sound.played.last, 'exit.wav');
  });
}

/// Advances time in small frames, like a real run (one huge frame would not
/// give chained timers a chance to tick).
Future<void> runFor(WidgetTester tester, double seconds) async {
  for (var t = 0.0; t < seconds; t += 0.05) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void hudTests() {
  testWidgets('HUD shows coins and passengers left', (tester) async {
    final progress = await loadProgress(tester);
    final game = await pumpGameScreen(tester, progress, 1);
    expect(find.byKey(const Key('left-sign')), findsOneWidget);
    expect(find.text('${game.level.queue.length}'), findsOneWidget);
    expect(find.text('${ProgressService.startingCoins}'), findsOneWidget);
  });

  testWidgets('pause menu opens, resumes and restarts', (tester) async {
    final progress = await loadProgress(tester);
    final game = await pumpGameScreen(tester, progress, 1);

    await tester.tap(find.byKey(const Key('pause-button')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Paused'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Paused'), findsNothing);

    await tester.tap(find.byKey(const Key('pause-button')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Restart'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Paused'), findsNothing);
    expect(game.session.state.moves, 0);
  });
}

void newBoosterTests() {
  group('refresh / clear / sort', () {
    testWidgets('all five booster buttons show their counts', (tester) async {
      final progress = await loadProgress(tester);
      await pumpGameScreen(tester, progress, 1);
      for (final k in ['undo', 'hint', 'refresh', 'clear', 'sort']) {
        expect(find.byKey(Key('booster-$k')), findsOneWidget, reason: k);
      }
    });

    testWidgets('refresh reshuffles the jam and spends one', (tester) async {
      final progress = await loadProgress(tester, {'unlocked': 25});
      final game = await pumpGameScreen(tester, progress, 25);
      final before = {
        for (final b in game.session.state.buses) b.id: (b.row, b.col, b.dir),
      };

      await tester.tap(find.byKey(const Key('booster-refresh')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(progress.refreshBoosters, 2);
      expect(game.session.helpUsed, 1);
      expect(game.session.state.buses.length, before.length);
      final moved = game.session.state.buses
          .where((b) => before[b.id] != (b.row, b.col, b.dir))
          .length;
      expect(moved, greaterThan(before.length ~/ 3));
    });

    testWidgets('clear: arm, airlift a blocked bus, then spend the booster', (
      tester,
    ) async {
      final progress = await loadProgress(tester, {'unlocked': 2});
      final game = await pumpGameScreen(tester, progress, 2);
      // Tutorial 2: bus 0 (red) is boxed in by bus 1.
      expect(
        Rules.canExit(game.session.state, game.session.state.busById(0)!),
        isFalse,
      );

      await tester.tap(find.byKey(const Key('booster-clear')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('clear-banner')), findsOneWidget);
      expect(progress.clearBoosters, 3); // not spent yet

      game.tapBus(0);
      await runFor(tester, 1.2);

      expect(game.session.state.busById(0), isNull); // lifted out
      expect(progress.clearBoosters, 2);
      expect(find.byKey(const Key('clear-banner')), findsNothing);
    });

    testWidgets('clear can be cancelled without spending', (tester) async {
      final progress = await loadProgress(tester, {'unlocked': 2});
      final game = await pumpGameScreen(tester, progress, 2);

      await tester.tap(find.byKey(const Key('booster-clear')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('booster-clear')));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('clear-banner')), findsNothing);
      game.tapBus(0); // blocked: just shakes
      await tester.pump(const Duration(milliseconds: 300));
      expect(game.session.state.busById(0), isNotNull);
      expect(progress.clearBoosters, 3);
    });

    testWidgets('sort fills a parked vehicle; disabled when pointless', (
      tester,
    ) async {
      final progress = await loadProgress(tester, {'unlocked': 2});
      final game = await pumpGameScreen(tester, progress, 2);

      // Nothing parked yet, so Sort has nobody to help.
      await tester.tap(find.byKey(const Key('booster-sort')));
      await tester.pump(const Duration(milliseconds: 100));
      expect(progress.sortBoosters, 3);

      // Airlift the red bus: it parks, but blue passengers are in front.
      game.clearArmed.value = true;
      game.tapBus(0);
      await runFor(tester, 1.2);
      final queueBefore = game.session.state.queue.length;

      await tester.tap(find.byKey(const Key('booster-sort')));
      await runFor(tester, 1.5);

      expect(progress.sortBoosters, 2);
      expect(game.session.state.queue.length, queueBefore - 4); // 4 reds
    });
  });
}

void animationTests() {
  group('animations', () {
    testWidgets('win: confetti fires, result card waits for the show', (
      tester,
    ) async {
      final progress = await loadProgress(tester); // Play -> tutorial level 1
      final game = await pumpGameScreen(tester, progress, 1);
      final order = Solver.solve(game.level.toState()).order!;

      for (final id in order) {
        game.tapBus(id);
        await runFor(tester, 2.5);
      }
      expect(game.session.state.status, GameStatus.won);
      expect(game.confettiBursts, 1);
      expect(find.text('Level clear!'), findsNothing); // still celebrating

      await runFor(tester, 3);
      expect(find.text('Level clear!'), findsOneWidget);
      // A clean run: no blocked taps, no boosters.
      expect(progress.stars(1), 3);
      expect(progress.coins, ProgressService.startingCoins + 50);
      expect(find.text('+50 coins'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsNWidgets(3));
    });

    testWidgets('lose: the screen shakes', (tester) async {
      final progress = await loadProgress(tester, {'unlocked': 4});
      final game = await pumpGameScreen(tester, progress, 4);
      // Tutorial 4: send every colour except the one the queue needs.
      final wrong = [
        for (final b in game.level.buses)
          if (b.colorIndex != game.level.queue.first) b.id,
      ];
      for (final id in wrong) {
        game.tapBus(id);
        await runFor(tester, 1.5);
      }
      expect(game.session.state.status, GameStatus.lost);
      expect(game.shakes, 1);
      await runFor(tester, 3);
      expect(find.text('Lane full!'), findsOneWidget);
    });

    testWidgets('undo cancels animations and sounds still pending', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final progress = (await tester.runAsync(ProgressService.load))!;
      final sound = _RecordingSound();
      await tester.pumpWidget(
        BusEscapeApp(
          progress: progress,
          feedback: FeedbackService(
            settings: progress,
            sound: sound,
            haptics: const NoopHapticsPlayer(),
          ),
        ),
      );
      await tester.tap(find.textContaining('Play'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      final game = tester
          .widget<GameWidget<BusEscapeGame>>(
            find.byType(GameWidget<BusEscapeGame>),
          )
          .game!;

      // The first solution move of level 1 fills a bus (board + depart).
      game.tapBus(Solver.solve(game.level.toState()).order!.first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(game.undo(), isTrue);
      await runFor(tester, 3);

      expect(sound.played, ['exit.wav']);
      expect(game.world.children.whereType<DepartingBus>(), isEmpty);
    });
  });
}
