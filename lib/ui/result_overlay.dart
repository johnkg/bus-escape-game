import 'package:flutter/material.dart';

import '../core/core.dart' show GameSession;
import '../services/progress_service.dart';
import 'ui_style.dart';
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
    this.timedOut = false,
    this.fast = false,
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

  /// Lost because the clock ran out.
  final bool timedOut;

  /// Won a timed level with at least half the clock left.
  final bool fast;
  final int streak;

  /// Shown on the lose card so a run can be rescued.
  final Widget? undoButton;
  final Widget? extraSlotButton;

  @override
  Widget build(BuildContext context) {
    return DialogCard(
      children: [
        Text(
          won
              ? (daily ? 'Daily clear!' : 'Level clear!')
              : (timedOut ? "Time's up!" : 'Lane full!'),
          style: const TextStyle(
            color: Colors.white,
            fontSize: FontSizes.heading,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: Gap.l),
        if (won) ...[
          StarRow(stars: stars, size: _starSize),
          const SizedBox(height: Gap.s),
          Text(
            switch (stars) {
              GameSession.maxStars => 'Perfect!',
              GameSession.cleanStars =>
                'No boosters. Avoid blocked taps for 3 stars.',
              _ => 'No boosters or hints for more stars.',
            },
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70),
          ),
          if (coins > 0)
            Padding(
              padding: const EdgeInsets.only(top: Gap.m),
              child: Text(
                '+$coins coins',
                style: const TextStyle(
                  color: AppColors.gold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (fast)
            const _Bonus('Fast finish: +${ProgressService.fastFinishCoins} coins'),
          if (daily && streak > 0)
            _Bonus('$streak-day streak. Come back tomorrow!'),
          if (rewarded) const _Bonus('Bonus: +1 of every booster'),
        ] else
          Text(
            timedOut
                ? 'The clock ran out. Be quicker next time!'
                : 'No bus could take the next passenger.',
            style: const TextStyle(color: Colors.white70),
          ),
        const SizedBox(height: Gap.xxxl),
        if (!won && extraSlotButton != null) ...[
          extraSlotButton!,
          const SizedBox(height: Gap.l),
        ],
        if (!won && undoButton != null) ...[
          undoButton!,
          const SizedBox(height: Gap.l),
        ],
        if (won && !daily) ...[
          BigButton(label: 'Next level', onPressed: onNext),
          const SizedBox(height: Gap.l),
        ],
        BigButton(
          label: won ? 'Replay' : 'Retry',
          color: won ? AppColors.secondary : AppColors.accent,
          onPressed: onRetry,
        ),
        const SizedBox(height: Gap.l),
        BigButton(label: 'Menu', color: AppColors.muted, onPressed: onMenu),
      ],
    );
  }

  static const double _starSize = 40;
}

/// One gold line of extra rewards under the coins.
class _Bonus extends StatelessWidget {
  const _Bonus(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Gap.xs),
    child: Text(text, style: const TextStyle(color: AppColors.gold)),
  );
}
