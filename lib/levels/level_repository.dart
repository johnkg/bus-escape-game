import '../core/core.dart';
import 'tutorial_levels.dart';

/// Single place to ask "give me level N": handmade tutorial first, then
/// procedural levels whose difficulty restarts at the bottom of the curve.
class LevelRepository {
  const LevelRepository._();

  static int get tutorialCount => TutorialLevels.all.length;

  /// Every fifth level after the tutorial (13, 18, 23, ...) races a clock.
  static bool isTimed(int number) => number > tutorialCount && number % 5 == 3;

  /// Seconds on the clock for [number], or null for an untimed level.
  static double? timeLimitFor(int number, Level level) =>
      isTimed(number) ? 20 + 6.0 * level.buses.length : null;

  /// Level ids for daily challenges start here, clear of the numbered levels.
  static const int dailyBase = 100000;

  /// The challenge for [date]: the same for every player, with a difficulty
  /// that climbs through the week (10 on day one, 40 on day seven).
  static Level dailyLevel(DateTime date) {
    final day = dayNumber(date);
    return LevelGenerator.generate(dailyBase + day, difficulty: 10 + (day % 7) * 5);
  }

  static Level levelFor(int number) {
    if (number >= 1 && number <= tutorialCount) {
      return TutorialLevels.all[number - 1];
    }
    return LevelGenerator.generate(number, difficulty: number - tutorialCount);
  }
}
