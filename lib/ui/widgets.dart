import 'package:flutter/material.dart';

import '../core/core.dart' show GameSession;
import '../game/palette.dart' show shade;

import 'ui_style.dart';

/// Shared screen frame: gradient backdrop, centered phone-width column and
/// an optional title bar with a back button.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.child, this.title, this.onBack});

  final Widget child;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.backdropTop, AppColors.backdropBottom],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxScreenWidth),
              child: Column(
                children: [
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Gap.l,
                        Gap.l,
                        Gap.xl,
                        Gap.xs,
                      ),
                      child: Row(
                        children: [
                          ClayIconButton(
                            icon: Icons.arrow_back_rounded,
                            semanticLabel: 'Back',
                            color: AppColors.panel,
                            onPressed:
                                onBack ?? () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: Gap.l),
                          Text(
                            title!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: Fonts.display,
                              fontSize: FontSizes.heading,
                              fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

/// A chunky raised button: a glossy face on a darker lip, sinking into the
/// lip while pressed. The building block of every button in the UI.
class ClayButton extends StatefulWidget {
  const ClayButton({
    super.key,
    required this.color,
    required this.onPressed,
    required this.child,
    this.radius = Radii.xl,
    this.lip = Clay.lip,
    this.rimColor,
    this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.semanticLabel,
  });

  final Color color;

  /// Null shows the button disabled.
  final VoidCallback? onPressed;
  final Widget child;
  final double radius;
  final double lip;

  /// Defaults to a lighter tint of [color].
  final Color? rimColor;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;

  /// Read by screen readers when [child] has no text (icon buttons).
  final String? semanticLabel;

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final down = _pressed && enabled;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final lipColor = shade(widget.color, Clay.lipShade);
    final radius = BorderRadius.circular(widget.radius);
    final sink = down ? widget.lip : 0.0;
    final face = AnimatedContainer(
      duration: reduceMotion
          ? Duration.zero
          : (down ? Clay.pressIn : Clay.pressOut),
      curve: Curves.easeOut,
      width: widget.width,
      height: widget.height,
      padding: widget.padding,
      alignment: widget.width != null || widget.height != null
          ? Alignment.center
          : null,
      transform: Matrix4.translationValues(0, sink, 0),
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [shade(widget.color, Clay.highlightShade), widget.color],
        ),
        border: Border.all(
          color: widget.rimColor ?? shade(widget.color, Clay.rimShade),
          width: Clay.rim,
        ),
        boxShadow: [
          BoxShadow(color: lipColor, offset: Offset(0, widget.lip - sink)),
          BoxShadow(
            color: AppColors.shadow,
            offset: Offset(0, widget.lip - sink + Clay.shadowDrop),
            blurRadius: Clay.shadowBlur,
          ),
        ],
      ),
      child: widget.child,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: Opacity(
        opacity: enabled ? 1 : disabledOpacity,
        child: MouseRegion(
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: enabled ? (_) => _setPressed(true) : null,
            onTapUp: enabled ? (_) => _setPressed(false) : null,
            onTapCancel: () => _setPressed(false),
            onTap: widget.onPressed,
            // The lip sits below the face; keep it inside the hit box.
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.lip),
              child: face,
            ),
          ),
        ),
      ),
    );
  }
}

/// A square clay button holding one icon.
class ClayIconButton extends StatelessWidget {
  const ClayIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = AppColors.go,
    this.size = minTouchTarget,
    this.rimColor,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color color;
  final double size;
  final Color? rimColor;

  static const double _iconScale = 0.6;

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      color: color,
      rimColor: rimColor,
      onPressed: onPressed,
      width: size,
      height: size,
      radius: Radii.m,
      lip: Clay.smallLip,
      semanticLabel: semanticLabel,
      child: Icon(
        icon,
        color: Colors.white,
        size: size * _iconScale,
        shadows: labelShadows,
      ),
    );
  }
}

/// White button text in the display face, with a soft drop shadow.
class ClayLabel extends StatelessWidget {
  const ClayLabel(this.text, {super.key, this.fontSize = FontSizes.button});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) => FittedBox(
    // Long labels and large system text shrink instead of wrapping.
    fit: BoxFit.scaleDown,
    child: Text(
      text,
      maxLines: 1,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontFamily: Fonts.display,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        shadows: labelShadows,
      ),
    ),
  );
}

/// The wide main-action button, with an optional leading icon and a small
/// line of text under the label.
class BigButton extends StatelessWidget {
  const BigButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.accent,
    this.icon,
    this.subtitle,
    this.trailing,
    this.width = defaultWidth,
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;
  final IconData? icon;
  final String? subtitle;

  /// Shown at the right edge, e.g. a done check.
  final Widget? trailing;
  final double width;

  static const double defaultWidth = 260;
  static const double height = 58;
  static const double _tallHeight = 70;
  static const double _iconSize = 28;

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      color: color,
      onPressed: onPressed,
      width: width,
      height: subtitle == null ? height : _tallHeight,
      radius: Radii.card,
      padding: const EdgeInsets.symmetric(horizontal: Gap.xl),
      child: Row(
        children: [
          if (icon != null)
            Icon(
              icon,
              color: Colors.white,
              size: _iconSize,
              shadows: labelShadows,
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClayLabel(label),
                if (subtitle != null)
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: FontSizes.small,
                        fontWeight: FontWeight.w700,
                        shadows: labelShadows,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Balance the icon so the label stays centred.
          if (trailing != null)
            SizedBox(width: _iconSize, child: trailing)
          else if (icon != null)
            const SizedBox(width: _iconSize),
        ],
      ),
    );
  }
}

/// Clay booster button with a count badge; greyed out when unavailable.
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
    return ClayButton(
      color: AppColors.secondary,
      onPressed: active ? onPressed : null,
      lip: Clay.smallLip,
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.xl,
        vertical: _verticalPadding,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, shadows: labelShadows),
          const SizedBox(width: Gap.m),
          ClayLabel(label, fontSize: FontSizes.label),
          const SizedBox(width: Gap.m),
          CountBadge(count: count, color: AppColors.ink),
        ],
      ),
    );
  }
}

/// A round number badge.
class CountBadge extends StatelessWidget {
  const CountBadge({super.key, required this.count, required this.color});

  final int count;
  final Color color;

  static const double size = 22;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: size, minHeight: size),
      padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size / 2),
        border: Border.all(color: Colors.white, width: Clay.rim / 2),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          color: Colors.white,
          fontFamily: Fonts.display,
          fontSize: FontSizes.caption,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// A small dark pill with an icon and a value (coins, streak, clock).
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.text,
    this.iconColor = Colors.white,
    this.iconSize = defaultIconSize,
    this.fontSize = FontSizes.label,
    this.color = AppColors.ink,
    this.semanticLabel,
  });

  static const double defaultIconSize = 22;

  final IconData icon;
  final String text;
  final Color iconColor;
  final double iconSize;
  final double fontSize;
  final Color color;

  /// Read by screen readers instead of [text], when the icon carries meaning.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.l,
          vertical: Gap.xs,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(color: AppColors.cardRim, width: Clay.rim / 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: iconSize),
            const SizedBox(width: Gap.s),
            Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontFamily: Fonts.display,
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
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
    return Semantics(
      label: '$stars of ${GameSession.maxStars} stars',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < GameSession.maxStars; i++)
              Icon(
                i < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                size: size,
                color: i < stars ? AppColors.star : Colors.white54,
                shadows: i < stars ? labelShadows : null,
              ),
          ],
        ),
      ),
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
    this.color = Colors.white,
  });

  static const double defaultStroke = 4;

  final String text;
  final double fontSize;
  final double strokeWidth;
  final Color color;

  static const double _letterSpacing = 0.5;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: Fonts.display,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
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
        Text(text, style: base.copyWith(color: color)),
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

  static const double _width = 64;
  static const double _buttonWidth = 58;
  static const double _buttonHeight = 52;
  static const double _iconSize = 30;
  static const double _badgeOverhang = -7;
  static const double _labelStroke = 3;

  @override
  Widget build(BuildContext context) {
    final active = enabled && (count > 0 || armed);
    return SizedBox(
      width: _width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              ClayButton(
                color: armed ? AppColors.accent : AppColors.go,
                rimColor: AppColors.frame,
                onPressed: active ? onPressed : null,
                width: _buttonWidth,
                height: _buttonHeight,
                radius: Radii.l,
                lip: Clay.smallLip,
                semanticLabel: '$label, $count left',
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: _iconSize,
                  shadows: labelShadows,
                ),
              ),
              Positioned(
                top: _badgeOverhang,
                right: _badgeOverhang,
                child: ExcludeSemantics(
                  child: CountBadge(count: count, color: AppColors.goDark),
                ),
              ),
            ],
          ),
          const SizedBox(height: Gap.xxs),
          ExcludeSemantics(
            child: OutlinedText(
              label,
              fontSize: FontSizes.small,
              strokeWidth: _labelStroke,
            ),
          ),
        ],
      ),
    );
  }
}

/// A raised clay panel: lighter rim, soft shadow.
class ClayCard extends StatelessWidget {
  const ClayCard({
    super.key,
    required this.child,
    this.color = AppColors.card,
    this.padding = const EdgeInsets.all(Gap.xl),
    this.radius = Radii.card,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.cardRim, width: Clay.rim),
        boxShadow: [
          BoxShadow(
            color: shade(color, Clay.lipShade),
            offset: const Offset(0, Clay.lip),
          ),
          const BoxShadow(
            color: AppColors.shadow,
            offset: Offset(0, Clay.lip + Clay.shadowDrop),
            blurRadius: Clay.shadowBlur,
          ),
        ],
      ),
      child: child,
    );
  }
}

/// A dimmed backdrop with a centred card that pops in, for the pause and
/// result menus.
class DialogCard extends StatelessWidget {
  const DialogCard({super.key, required this.children});

  final List<Widget> children;

  static const double _padding = 28;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return ColoredBox(
      color: AppColors.scrim,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: reduceMotion ? 1 : 0, end: 1),
          duration: Clay.popIn,
          curve: Curves.easeOutBack,
          builder: (context, t, child) => Opacity(
            opacity: t.clamp(0.0, 1.0),
            child: Transform.scale(
              scale: Clay.popFrom + (1 - Clay.popFrom) * t,
              child: child,
            ),
          ),
          child: ClayCard(
            padding: const EdgeInsets.all(_padding),
            child: Column(mainAxisSize: MainAxisSize.min, children: children),
          ),
        ),
      ),
    );
  }
}

/// Title text for dialog cards.
class DialogTitle extends StatelessWidget {
  const DialogTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: Fonts.display,
        fontSize: FontSizes.heading,
        fontWeight: FontWeight.w700,
        shadows: labelShadows,
      ),
    ),
  );
}

/// Opens [screen] on top of the current one.
Future<void> pushScreen(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
