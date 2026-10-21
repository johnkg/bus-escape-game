import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import 'ui_style.dart';
import 'widgets.dart';

/// Coins, level title and pause button across the top of the game.
class HudTop extends StatelessWidget {
  const HudTop({
    super.key,
    required this.levelNumber,
    this.title,
    this.timeLeft,
    required this.moves,
    required this.coins,
    required this.onPause,
  });

  final int levelNumber;

  /// Replaces "Level N" (the daily challenge has no number).
  final String? title;

  /// Whole seconds left on a timed level; null when the level is untimed.
  final ValueListenable<int?>? timeLeft;
  final int moves;
  final int coins;
  final VoidCallback onPause;

  static const double _coinPadV = 5;
  static const double _coinPadRight = 14;
  static const double _coinIconSize = 22;
  static const double _pauseSize = 42;
  static const double _pauseIconSize = 28;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: Gap.l,
      left: Gap.l,
      right: Gap.l,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            key: const Key('coin-chip'),
            padding: const EdgeInsets.fromLTRB(
              Gap.m,
              _coinPadV,
              _coinPadRight,
              _coinPadV,
            ),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(Radii.pill),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.monetization_on,
                  color: AppColors.gold,
                  size: _coinIconSize,
                ),
                const SizedBox(width: Gap.s),
                Text(
                  '$coins',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: FontSizes.label,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                OutlinedText(
                  title ?? 'Level $levelNumber',
                  fontSize: FontSizes.hud,
                ),
                Text(
                  'Moves $moves',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: FontSizes.caption,
                    fontWeight: FontWeight.w600,
                    shadows: textOverGame,
                  ),
                ),
                if (timeLeft != null)
                  ValueListenableBuilder<int?>(
                    valueListenable: timeLeft!,
                    builder: (context, left, _) => left == null
                        ? const SizedBox.shrink()
                        : _TimeChip(seconds: left),
                  ),
              ],
            ),
          ),
          Material(
            color: AppColors.go,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Radii.m),
              side: buttonRim,
            ),
            child: InkWell(
              key: const Key('pause-button'),
              borderRadius: BorderRadius.circular(Radii.m),
              onTap: onPause,
              child: const SizedBox(
                width: _pauseSize,
                height: _pauseSize,
                child: Icon(
                  Icons.pause,
                  color: Colors.white,
                  size: _pauseIconSize,
                ),
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

  /// Where the sign stands, beside the front of the queue.
  static const double _left = 14;
  static const double _top = 150;
  static const double _width = 84;
  static const double _border = 2;
  static const double _labelSpacing = 1;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _left,
      top: _top,
      child: Container(
        key: const Key('left-sign'),
        width: _width,
        padding: const EdgeInsets.symmetric(vertical: Gap.xs),
        decoration: BoxDecoration(
          color: AppColors.queueSign,
          borderRadius: BorderRadius.circular(Radii.s),
          border: Border.all(color: Colors.white, width: _border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontSize: FontSizes.title,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Text(
              'LEFT',
              style: TextStyle(
                color: Colors.white,
                fontSize: FontSizes.caption,
                fontWeight: FontWeight.w800,
                letterSpacing: _labelSpacing,
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
    return DialogCard(
      children: [
        const Text(
          'Paused',
          style: TextStyle(
            color: Colors.white,
            fontSize: FontSizes.heading,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: Gap.xxl),
        BigButton(label: 'Resume', onPressed: onResume),
        const SizedBox(height: Gap.l),
        BigButton(
          label: 'Restart',
          color: AppColors.secondary,
          onPressed: onRestart,
        ),
        const SizedBox(height: Gap.l),
        BigButton(label: 'Menu', color: AppColors.muted, onPressed: onMenu),
      ],
    );
  }
}

/// The countdown on a timed level; turns red for the last ten seconds.
class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.seconds});

  final int seconds;

  /// The chip turns red at this many seconds left.
  static const int _lowSeconds = 10;
  static const double _padH = 10;
  static const double _iconSize = 15;

  @override
  Widget build(BuildContext context) {
    final low = seconds <= _lowSeconds;
    final minutes = seconds ~/ Duration.secondsPerMinute;
    final secs = (seconds % Duration.secondsPerMinute).toString().padLeft(
      2,
      '0',
    );
    final text = '$minutes:$secs';
    return Container(
      key: const Key('time-chip'),
      margin: const EdgeInsets.only(top: Gap.xxs),
      padding: const EdgeInsets.symmetric(horizontal: _padH, vertical: Gap.xxs),
      decoration: BoxDecoration(
        color: low ? AppColors.warning : Colors.black54,
        borderRadius: BorderRadius.circular(Radii.m),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer, color: Colors.white, size: _iconSize),
          const SizedBox(width: Gap.xs),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: FontSizes.body,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
