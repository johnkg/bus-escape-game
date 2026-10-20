import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'progress_scope.dart';
import 'settings_screen.dart';
import 'widgets.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return ScreenFrame(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.directions_bus_filled,
            size: 96,
            color: Color(0xFFF39C12),
          ),
          const SizedBox(height: 12),
          // Long-press the title to practise any level (progress is kept).
          GestureDetector(
            key: const Key('menu-title'),
            onLongPress: () => _jumpToLevel(context),
            child: const Text(
              'Bus Escape',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 48),
          BigButton(
            label: 'Play  •  Level ${progress.unlockedLevel}',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GameScreen(levelNumber: progress.unlockedLevel),
              ),
            ),
          ),
          const SizedBox(height: 16),
          BigButton(
            key: const Key('daily-button'),
            label: progress.dailyDone(DateTime.now())
                ? 'Daily Challenge  ✓'
                : 'Daily Challenge',
            color: const Color(0xFF2E9E4F),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GameScreen(daily: DateTime.now()),
              ),
            ),
          ),
          if (progress.dailyStreak(DateTime.now()) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (progress.dailyStreak(DateTime.now()) >=
                      ProgressService.streakRewardEvery)
                    const Padding(
                      padding: EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.emoji_events,
                        color: Color(0xFFF5C21B),
                        size: 18,
                      ),
                    ),
                  Text(
                    '${progress.dailyStreak(DateTime.now())}-day streak',
                    style: const TextStyle(color: Color(0xFFF5C21B)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          BigButton(
            label: 'Levels',
            color: const Color(0xFF3498DB),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const LevelSelectScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          BigButton(
            label: 'Settings',
            color: const Color(0xFF7F8C8D),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
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
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => GameScreen(levelNumber: level, practice: true),
    ),
  );
}

/// Asks for a level number. Practice runs never touch saved progress.
class _JumpDialog extends StatefulWidget {
  const _JumpDialog();

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    final n = int.tryParse(_controller.text.trim());
    if (n != null && n >= 1 && n <= 9999) Navigator.of(context).pop(n);
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
          hintText: 'Level number (1-9999)',
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
