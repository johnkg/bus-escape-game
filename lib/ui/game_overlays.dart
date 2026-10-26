import 'package:flutter/material.dart';

import '../game/layout.dart';
import 'ui_style.dart';

/// The booster row along the bottom of the game, plus the "tap a vehicle"
/// banner while Clear is armed.
class BoosterBar extends StatelessWidget {
  const BoosterBar({
    super.key,
    required this.clearArmed,
    required this.tilesFor,
  });

  final ValueNotifier<bool> clearArmed;
  final List<Widget> Function(bool clearArmed) tilesFor;

  /// The Clear banner floats this far above the booster row.
  static const double _bannerLift = 40;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: clearArmed,
      builder: (context, armed, _) => Stack(
        children: [
          if (armed)
            Positioned(
              key: const Key('clear-banner'),
              top: GameLayout.boosterTop - _bannerLift,
              left: Gap.xxl,
              right: Gap.xxl,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: Gap.s),
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  borderRadius: BorderRadius.circular(Radii.l),
                  border: Border.all(color: AppColors.frame, width: Clay.rim),
                ),
                child: const Text(
                  'Tap any vehicle to airlift it  (tap Clear to cancel)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: FontSizes.small,
                    fontWeight: FontWeight.w800,
                    shadows: labelShadows,
                  ),
                ),
              ),
            ),
          Positioned(
            left: Gap.m,
            right: Gap.m,
            top: GameLayout.boosterTop,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: tilesFor(armed),
            ),
          ),
        ],
      ),
    );
  }
}

/// Teaching text and first-time tips, between the HUD and the board.
class HintBanner extends StatelessWidget {
  const HintBanner({super.key, required this.text, this.onTap});

  final String text;
  final VoidCallback? onTap;

  /// Just below the HUD.
  static const double _top = 96;
  static const double _padV = 5;
  static const double _lineHeight = 1.15;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: _top,
      left: Gap.xxl,
      right: Gap.xxl,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.l,
            vertical: _padV,
          ),
          decoration: BoxDecoration(
            color: AppColors.panel,
            borderRadius: BorderRadius.circular(Radii.l),
            border: Border.all(color: AppColors.cardRim, width: Clay.rim / 2),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: FontSizes.small,
              fontWeight: FontWeight.w700,
              height: _lineHeight,
            ),
          ),
        ),
      ),
    );
  }
}
