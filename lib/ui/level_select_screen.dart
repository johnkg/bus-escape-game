import 'package:flutter/material.dart';

import '../levels/level_repository.dart';
import '../services/progress_service.dart';
import 'game_screen.dart';
import 'progress_scope.dart';
import 'ui_style.dart';
import 'widgets.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  /// How many locked levels to show past the player's current one.
  static const int lookahead = 15;

  static const int _columns = 4;
  static const double _starSize = 14;
  static const double _timerSize = 14;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final unlocked = progress.unlockedLevel;
    return ScreenFrame(
      title: 'Levels',
      child: GridView.builder(
        padding: const EdgeInsets.all(Gap.xl),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _columns,
          mainAxisSpacing: Gap.l,
          crossAxisSpacing: Gap.l,
        ),
        itemCount: unlocked + lookahead,
        itemBuilder: (context, i) {
          final level = ProgressService.firstLevel + i;
          final open = level <= unlocked;
          final stars = progress.stars(level);
          return ClayButton(
            color: open
                ? (level == unlocked ? AppColors.accent : AppColors.secondary)
                : AppColors.panel,
            radius: Radii.xl,
            lip: Clay.smallLip,
            semanticLabel: open ? null : 'Level $level, locked',
            onPressed: open
                ? () => pushScreen(context, GameScreen(levelNumber: level))
                : null,
            child: Center(
              child: open
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClayLabel('$level', fontSize: FontSizes.heading),
                        if (stars > 0) StarRow(stars: stars, size: _starSize),
                        if (LevelRepository.isTimed(level))
                          const Icon(
                            Icons.timer_rounded,
                            size: _timerSize,
                            color: Colors.white,
                            semanticLabel: 'timed',
                          ),
                      ],
                    )
                  : const Icon(Icons.lock_rounded, color: Colors.white),
            ),
          );
        },
      ),
    );
  }
}
