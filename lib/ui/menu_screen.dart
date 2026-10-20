import 'package:flutter/material.dart';

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
          const Text(
            'Bus Escape',
            style: TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
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
              child: Text(
                '${progress.dailyStreak(DateTime.now())}-day streak',
                style: const TextStyle(color: Color(0xFFF5C21B)),
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
