import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'progress_scope.dart';
import 'settings_screen.dart';
import 'ui_style.dart';
import 'widgets.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const double _logoSize = 96;
  static const double _trophySize = 18;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final today = DateTime.now();
    final streak = progress.dailyStreak(today);
    return ScreenFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.directions_bus_filled,
            size: _logoSize,
            color: AppColors.accent,
          ),
          const SizedBox(height: Gap.l),
          // Long-press the title to practise any level (progress is kept).
          GestureDetector(
            key: const Key('menu-title'),
            onLongPress: () => _jumpToLevel(context),
            child: const Text(
              'Bus Escape',
              style: TextStyle(
                color: Colors.white,
                fontSize: FontSizes.hero,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: Gap.huge),
          BigButton(
            label: 'Play  •  Level ${progress.unlockedLevel}',
            onPressed: () => pushScreen(
              context,
              GameScreen(levelNumber: progress.unlockedLevel),
            ),
          ),
          const SizedBox(height: Gap.xl),
          BigButton(
            key: const Key('daily-button'),
            label: progress.dailyDone(today)
                ? 'Daily Challenge  ✓'
                : 'Daily Challenge',
            color: AppColors.go,
            onPressed: () =>
                pushScreen(context, GameScreen(daily: DateTime.now())),
          ),
          if (streak > 0)
            Padding(
              padding: const EdgeInsets.only(top: Gap.s),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (streak >= ProgressService.streakRewardEvery)
                    const Padding(
                      padding: EdgeInsets.only(right: Gap.xs),
                      child: Icon(
                        Icons.emoji_events,
                        color: AppColors.gold,
                        size: _trophySize,
                      ),
                    ),
                  Text(
                    '$streak-day streak',
                    style: const TextStyle(color: AppColors.gold),
                  ),
                ],
              ),
            ),
          const SizedBox(height: Gap.xl),
          BigButton(
            label: 'Levels',
            color: AppColors.secondary,
            onPressed: () => pushScreen(context, const LevelSelectScreen()),
          ),
          const SizedBox(height: Gap.xl),
          BigButton(
            label: 'Settings',
            color: AppColors.muted,
            onPressed: () => pushScreen(context, const SettingsScreen()),
          ),
        ],
      ),
    );
  }
}

Future<void> _jumpToLevel(BuildContext context) async {
  final level = await showDialog<int>(
    context: context,
    builder: (_) => const _JumpDialog(),
  );
  if (level == null || !context.mounted) return;
  await pushScreen(context, GameScreen(levelNumber: level, practice: true));
}

/// Asks for a level number. Practice runs never touch saved progress.
class _JumpDialog extends StatefulWidget {
  const _JumpDialog();

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  final _controller = TextEditingController();

  /// Highest level the practice box accepts.
  static const int _maxLevel = 9999;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    final n = int.tryParse(_controller.text.trim());
    if (n != null && n >= ProgressService.firstLevel && n <= _maxLevel) {
      Navigator.of(context).pop(n);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Practice a level'),
      content: TextField(
        key: const Key('jump-field'),
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          hintText: 'Level number (${ProgressService.firstLevel}-$_maxLevel)',
          helperText: 'Progress, stars and coins are not saved.',
        ),
        onSubmitted: (_) => _start(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const Key('jump-go'),
          onPressed: _start,
          child: const Text('Start'),
        ),
      ],
    );
  }
}
