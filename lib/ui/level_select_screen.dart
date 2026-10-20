import 'package:flutter/material.dart';

import '../levels/level_repository.dart';
import 'game_screen.dart';
import 'progress_scope.dart';
import 'widgets.dart';

class LevelSelectScreen extends StatelessWidget {
  const LevelSelectScreen({super.key});

  /// How many locked levels to show past the player's current one.
  static const int lookahead = 15;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final unlocked = progress.unlockedLevel;
    return ScreenFrame(
      title: 'Levels',
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: unlocked + lookahead,
        itemBuilder: (context, i) {
          final level = i + 1;
          final open = level <= unlocked;
          final stars = progress.stars(level);
          return Material(
            color: open
                ? (level == unlocked
                      ? const Color(0xFFF39C12)
                      : const Color(0xFF3498DB))
                : const Color(0xFF3F566D),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: open
                  ? () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(levelNumber: level),
                      ),
                    )
                  : null,
              child: Center(
                child: open
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$level',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (stars > 0) StarRow(stars: stars, size: 13),
                          if (LevelRepository.isTimed(level))
                            const Icon(
                              Icons.timer,
                              size: 14,
                              color: Colors.white70,
                            ),
                        ],
                      )
                    : const Icon(Icons.lock, color: Colors.white38),
              ),
            ),
          );
        },
      ),
    );
  }
}
