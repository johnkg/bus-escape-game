import 'package:flutter/material.dart';

import 'progress_scope.dart';
import 'ui_style.dart';
import 'widgets.dart';

/// Lifetime numbers: levels, stars, daily streaks and coins.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  static const int _columns = 2;
  static const double _tileAspect = 1.25;
  static const double _iconSize = 26;
  static const double _valueLineHeight = 1;

  /// Long labels ("Daily challenges cleared") wrap onto a second line.
  static const int _labelLines = 2;

  @override
  Widget build(BuildContext context) {
    final p = ProgressScope.of(context);
    final rows = <(IconData, String, String)>[
      (Icons.flag_rounded, 'Levels cleared', '${p.clearedLevels}'),
      (Icons.star_rounded, 'Stars earned', '${p.totalStars}'),
      (Icons.auto_awesome_rounded, 'Three-star levels', '${p.threeStarLevels}'),
      (Icons.trending_up_rounded, 'Furthest level', '${p.unlockedLevel}'),
      (
        Icons.calendar_today_rounded,
        'Daily challenges cleared',
        '${p.dailiesCleared}',
      ),
      (
        Icons.local_fire_department_rounded,
        'Current daily streak',
        '${p.dailyStreak(DateTime.now())}',
      ),
      (Icons.emoji_events_rounded, 'Best daily streak', '${p.bestDailyStreak}'),
      (Icons.monetization_on, 'Coins', '${p.coins}'),
    ];
    return ScreenFrame(
      title: 'Stats',
      child: GridView.count(
        padding: const EdgeInsets.all(Gap.xl),
        crossAxisCount: _columns,
        mainAxisSpacing: Gap.xl,
        crossAxisSpacing: Gap.xl,
        childAspectRatio: _tileAspect,
        children: [
          for (final (icon, label, value) in rows)
            MergeSemantics(
              child: ClayCard(
                padding: const EdgeInsets.all(Gap.l),
                radius: Radii.xl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppColors.gold, size: _iconSize),
                    const Spacer(),
                    Text(
                      value,
                      key: Key('stat-$label'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: Fonts.display,
                        fontSize: FontSizes.heading,
                        fontWeight: FontWeight.w700,
                        height: _valueLineHeight,
                      ),
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      label,
                      maxLines: _labelLines,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: FontSizes.small,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
