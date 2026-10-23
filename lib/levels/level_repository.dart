import '../core/core.dart';
import 'tutorial_levels.dart';

/// Single place to ask "give me level N": handmade tutorial first, then
/// procedural levels whose difficulty restarts at the bottom of the curve.
class LevelRepository {
  const LevelRepository._();

  static int get tutorialCount => TutorialLevels.all.length;

  /// Every fifth level after the tutorial (13, 18, 23, ...) races a clock.
  static const int timedEvery = 5;
  static const int _timedRemainder = 3;

  /// The clock: a base allowance plus time for each vehicle on the board.
  static const double _timeBaseSeconds = 20;
  static const double _timePerVehicleSeconds = 6;

  static bool isTimed(int number) =>
      number > tutorialCount && number % timedEvery == _timedRemainder;

  /// Seconds on the clock for [number], or null for an untimed level.
  static double? timeLimitFor(int number, Level level) => isTimed(number)
      ? _timeBaseSeconds + _timePerVehicleSeconds * level.buses.length
      : null;

  /// Level ids for daily challenges start here, clear of the numbered levels.
  static const int dailyBase = 100000;

  /// Daily difficulty climbs through the week, from [_dailyEasiest] on day
  /// one by [_dailyStep] a day (10, 15, ... 40).
  static const int _dailyEasiest = 10;
  static const int _dailyStep = 5;
  static const int _daysPerWeek = 7;

  /// The challenge for [date]: the same for every player.
  static Level dailyLevel(DateTime date) {
    final day = dayNumber(date);
    return LevelGenerator.generate(
      dailyBase + day,
      difficulty: _dailyEasiest + (day % _daysPerWeek) * _dailyStep,
    );
  }

  static Level levelFor(int number) {
    if (number >= 1 && number <= tutorialCount) {
      return TutorialLevels.all[number - 1];
    }
    return LevelGenerator.generate(number, difficulty: number - tutorialCount);
  }
}
