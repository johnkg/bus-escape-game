import 'package:flutter/material.dart';

import 'widgets.dart';

/// Win/lose card shown over the game.
class ResultOverlay extends StatelessWidget {
  const ResultOverlay({
    super.key,
    required this.won,
    required this.stars,
    required this.onNext,
    required this.onRetry,
    required this.onMenu,
    this.rewarded = false,
    this.coins = 0,
    this.daily = false,
    this.streak = 0,
    this.undoButton,
    this.extraSlotButton,
  });

  final bool won;

  /// 1-3 when won.
  final int stars;
  final VoidCallback onNext;
  final VoidCallback onRetry;
  final VoidCallback onMenu;

  /// Won a level that gifts boosters.
  final bool rewarded;

  /// Coins earned by this win.
  final int coins;

  /// The daily challenge: no next level, and the streak is shown.
  final bool daily;
  final int streak;

  /// Shown on the lose card so a run can be rescued.
  final Widget? undoButton;
  final Widget? extraSlotButton;

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
                Text(
                  won ? (daily ? 'Daily clear!' : 'Level clear!') : 'Lane full!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                if (won) ...[
                  StarRow(stars: stars, size: 40),
                  const SizedBox(height: 6),
                  Text(
                    switch (stars) {
                      3 => 'Perfect!',
                      2 => 'No boosters. Avoid blocked taps for 3 stars.',
                      _ => 'No boosters or hints for more stars.',
                    },
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (coins > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '+$coins coins',
                        style: const TextStyle(
                          color: Color(0xFFF5C21B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (daily && streak > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '$streak-day streak. Come back tomorrow!',
                        style: const TextStyle(color: Color(0xFFF5C21B)),
                      ),
                    ),
                  if (rewarded)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text(
                        'Bonus: +1 of every booster',
                        style: TextStyle(color: Color(0xFFF5C21B)),
                      ),
                    ),
                ] else
                  const Text(
                    'No bus could take the next passenger.',
                    style: TextStyle(color: Colors.white70),
                  ),
                const SizedBox(height: 24),
                if (!won && extraSlotButton != null) ...[
                  extraSlotButton!,
                  const SizedBox(height: 12),
                ],
                if (!won && undoButton != null) ...[
                  undoButton!,
                  const SizedBox(height: 12),
                ],
                if (won && !daily) ...[
                  BigButton(label: 'Next level', onPressed: onNext),
                  const SizedBox(height: 12),
                ],
                BigButton(
                  label: won ? 'Replay' : 'Retry',
                  color: won
                      ? const Color(0xFF3498DB)
                      : const Color(0xFFF39C12),
                  onPressed: onRetry,
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
