import 'package:flutter/material.dart';

import '../core/core.dart' show GameSession;

import 'ui_style.dart';

/// Shared screen frame: dark background, centered phone-width column.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.child, this.title, this.onBack});

  final Widget child;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: maxScreenWidth),
            child: Column(
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(Gap.m, Gap.m, Gap.xl, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed:
                              onBack ?? () => Navigator.of(context).pop(),
                        ),
                        Text(
                          title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: FontSizes.title,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  static const double width = 240;
  static const double height = 54;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.xl),
          ),
          textStyle: const TextStyle(
            fontSize: FontSizes.button,
            fontWeight: FontWeight.bold,
          ),
        ),
        onPressed: onPressed,
        child: Text(label),
      ),
    );
  }
}

/// Round booster button with a count badge; greyed out when unavailable.
class BoosterButton extends StatelessWidget {
  const BoosterButton({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool enabled;
  final VoidCallback onPressed;

  static const double _verticalPadding = 10;

  @override
  Widget build(BuildContext context) {
    final active = enabled && count > 0;
    return Opacity(
      opacity: active ? 1 : disabledOpacity,
      child: Material(
        color: AppColors.secondary,
        borderRadius: BorderRadius.circular(Radii.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.xl),
          onTap: active ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.xl,
              vertical: _verticalPadding,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: Gap.m),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: FontSizes.label,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: Gap.m),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.m,
                    vertical: Gap.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(Radii.badge),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: FontSizes.body,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Three stars, [stars] of them filled.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = defaultSize});

  static const double defaultSize = 14;

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < GameSession.maxStars; i++)
          Icon(
            i < stars ? Icons.star : Icons.star_border,
            size: size,
            color: i < stars ? AppColors.star : Colors.white54,
          ),
      ],
    );
  }
}

/// White text with a dark outline, readable over any background.
class OutlinedText extends StatelessWidget {
  const OutlinedText(
    this.text, {
    super.key,
    this.fontSize = FontSizes.button,
    this.strokeWidth = defaultStroke,
  });

  static const double defaultStroke = 4;

  final String text;
  final double fontSize;
  final double strokeWidth;

  static const double _letterSpacing = 0.5;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: _letterSpacing,
    );
    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = strokeWidth
              ..strokeJoin = StrokeJoin.round
              ..color = AppColors.ink,
          ),
        ),
        Text(text, style: base.copyWith(color: Colors.white)),
      ],
    );
  }
}

/// Square booster button with its name underneath and a count badge, like
/// the booster row in the reference game.
class BoosterTile extends StatelessWidget {
  const BoosterTile({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
    required this.enabled,
    required this.onPressed,
    this.armed = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool enabled;
  final VoidCallback onPressed;

  /// Highlighted while the booster waits for a follow-up tap (Clear).
  final bool armed;

  static const double _disabledOpacity = 0.45;
  static const double _width = 60;
  static const double _buttonWidth = 56;
  static const double _buttonHeight = 52;
  static const double _iconSize = 30;
  static const double _badgeSize = 22;
  static const double _badgeOverhang = -6;

  @override
  Widget build(BuildContext context) {
    final active = enabled && (count > 0 || armed);
    return Opacity(
      opacity: active ? 1 : _disabledOpacity,
      child: SizedBox(
        width: _width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: armed ? AppColors.accent : AppColors.go,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Radii.l),
                    side: buttonRim,
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(Radii.l),
                    onTap: active ? onPressed : null,
                    child: SizedBox(
                      width: _buttonWidth,
                      height: _buttonHeight,
                      child: Icon(icon, color: Colors.white, size: _iconSize),
                    ),
                  ),
                ),
                Positioned(
                  top: _badgeOverhang,
                  right: _badgeOverhang,
                  child: Container(
                    width: _badgeSize,
                    height: _badgeSize,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.goDark,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: FontSizes.caption,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Gap.xs),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: FontSizes.caption,
                fontWeight: FontWeight.w800,
                shadows: textOverGame,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A dimmed backdrop with a centred card, for the pause and result menus.
class DialogCard extends StatelessWidget {
  const DialogCard({super.key, required this.children});

  final List<Widget> children;

  static const double _padding = 28;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Card(
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.card),
          ),
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// Opens [screen] on top of the current one.
Future<void> pushScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
