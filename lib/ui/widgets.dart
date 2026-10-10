import 'package:flutter/material.dart';

import '../game/palette.dart';

/// Shared screen frame: dark background, centered phone-width column.
class ScreenFrame extends StatelessWidget {
  const ScreenFrame({super.key, required this.child, this.title, this.onBack});

  final Widget child;
  final String? title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
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
                            fontSize: 22,
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
    this.color = const Color(0xFFF39C12),
  });

  final String label;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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

  @override
  Widget build(BuildContext context) {
    final active = enabled && count > 0;
    return Opacity(
      opacity: active ? 1 : 0.4,
      child: Material(
        color: const Color(0xFF3498DB),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: active ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
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
  const StarRow({super.key, required this.stars, this.size = 14});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star : Icons.star_border,
            size: size,
            color: i < stars ? const Color(0xFFF1C40F) : Colors.white54,
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
    this.fontSize = 20,
    this.strokeWidth = 4,
  });

  final String text;
  final double fontSize;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 0.5,
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
              ..color = const Color(0xFF1F2D3A),
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

  @override
  Widget build(BuildContext context) {
    final active = enabled && (count > 0 || armed);
    return Opacity(
      opacity: active ? 1 : 0.45,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: armed
                      ? const Color(0xFFF39C12)
                      : const Color(0xFF2E9E4F),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFF3D452), width: 2),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: active ? onPressed : null,
                    child: SizedBox(
                      width: 56,
                      height: 52,
                      child: Icon(icon, color: Colors.white, size: 30),
                    ),
                  ),
                ),
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(blurRadius: 3, color: Colors.black87)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
