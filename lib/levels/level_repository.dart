import '../core/core.dart';
import 'tutorial_levels.dart';

/// Single place to ask "give me level N": handmade tutorial first, then
/// procedural levels whose difficulty restarts at the bottom of the curve.
class LevelRepository {
  const LevelRepository._();

  static int get tutorialCount => TutorialLevels.all.length;

  static Level levelFor(int number) {
    if (number >= 1 && number <= tutorialCount) {
      return TutorialLevels.all[number - 1];
    }
    return LevelGenerator.generate(number, difficulty: number - tutorialCount);
  }
}
