import 'package:flutter/material.dart';

import 'progress_scope.dart';
import 'ui_style.dart';
import 'widgets.dart';

/// Lifetime numbers: levels, stars, daily streaks and coins.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const double _rowPadding = 10;

  @override
  Widget build(BuildContext context) {
    final p = ProgressScope.of(context);
    final rows = <(String, String)>[
      ('Levels cleared', '${p.clearedLevels}'),
      ('Stars earned', '${p.totalStars}'),
      ('Three-star levels', '${p.threeStarLevels}'),
      ('Furthest level', '${p.unlockedLevel}'),
      ('Daily challenges cleared', '${p.dailiesCleared}'),
      ('Current daily streak', '${p.dailyStreak(DateTime.now())}'),
      ('Best daily streak', '${p.bestDailyStreak}'),
      ('Coins', '${p.coins}'),
    ];
    return ScreenFrame(
      title: 'Stats',
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.xl,
          vertical: Gap.m,
        ),
        children: [
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: _rowPadding),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: FontSizes.label,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    key: Key('stat-$label'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: FontSizes.button,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
