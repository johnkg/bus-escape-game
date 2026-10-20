import 'package:flutter/material.dart';

import 'widgets.dart';

/// Coins, level title and pause button across the top of the game.
class HudTop extends StatelessWidget {
  const HudTop({
    super.key,
    required this.levelNumber,
    this.title,
    required this.moves,
    required this.coins,
    required this.onPause,
  });

  final int levelNumber;

  /// Replaces "Level N" (the daily challenge has no number).
  final String? title;
  final int moves;
  final int coins;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      left: 12,
      right: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('coin-chip'),
            padding: const EdgeInsets.fromLTRB(8, 5, 14, 5),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFF5C21B),
                  size: 22,
                ),
                const SizedBox(width: 6),
                Text(
                  '$coins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                OutlinedText(title ?? 'Level $levelNumber', fontSize: 24),
                Text(
                  'Moves $moves',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFF2E9E4F),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFF3D452), width: 2),
            ),
            child: InkWell(
              key: const Key('pause-button'),
              borderRadius: BorderRadius.circular(12),
              onTap: onPause,
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.pause, color: Colors.white, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The "N LEFT" sign beside the passenger queue.
class LeftSign extends StatelessWidget {
  const LeftSign({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 14,
      top: 150,
      child: Container(
        key: const Key('left-sign'),
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2F7DE1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'LEFT',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pause menu.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onRestart,
    required this.onMenu,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: const Color(0xFF34495E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Paused',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                BigButton(label: 'Resume', onPressed: onResume),
                const SizedBox(height: 12),
                BigButton(
                  label: 'Restart',
                  color: const Color(0xFF3498DB),
                  onPressed: onRestart,
                ),
                const SizedBox(height: 12),
                BigButton(
                  label: 'Menu',
                  color: const Color(0xFF7F8C8D),
                  onPressed: onMenu,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
