import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import 'game_screen.dart';
import 'level_select_screen.dart';
import 'progress_scope.dart';
import 'settings_screen.dart';
import 'ui_style.dart';
import 'widgets.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  static const double _logoSize = 72;
  static const double _logoBadge = 120;
  static const double _trophySize = 18;
  static const double _coinSize = 22;
  static const double _sideButtonWidth = 122;
  static const double _titleStroke = 8;

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    final today = DateTime.now();
    final streak = progress.dailyStreak(today);
    final dailyDone = progress.dailyDone(today);
    return ScreenFrame(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.xl, Gap.l, Gap.xl, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _Chip(
                  icon: Icons.monetization_on,
                  iconColor: AppColors.gold,
                  iconSize: _coinSize,
                  text: '${progress.coins}',
                  semanticLabel: '${progress.coins} coins',
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const ClayCard(
                  color: AppColors.accent,
                  radius: _logoBadge / 2,
                  padding: EdgeInsets.zero,
                  child: SizedBox(
                    width: _logoBadge,
                    height: _logoBadge,
                    child: Icon(
                      Icons.directions_bus_filled_rounded,
                      size: _logoSize,
                      color: Colors.white,
                      shadows: labelShadows,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                // Long-press the title to practise any level (progress is
                // kept).
                GestureDetector(
                  key: const Key('menu-title'),
                  onLongPress: () => _jumpToLevel(context),
                  child: Semantics(
                    header: true,
                    child: const OutlinedText(
                      'Bus Escape',
                      fontSize: FontSizes.hero,
                      strokeWidth: _titleStroke,
                    ),
                  ),
                ),
                const SizedBox(height: Gap.huge),
                BigButton(
                  label: 'Play',
                  subtitle: 'Level ${progress.unlockedLevel}',
                  icon: Icons.play_arrow_rounded,
                  onPressed: () => pushScreen(
                    context,
                    GameScreen(levelNumber: progress.unlockedLevel),
                  ),
                ),
                const SizedBox(height: Gap.xl),
                BigButton(
                  key: const Key('daily-button'),
                  label: 'Daily Challenge',
                  icon: Icons.calendar_today_rounded,
                  color: AppColors.go,
                  trailing: dailyDone
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          semanticLabel: 'done today',
                          shadows: labelShadows,
                        )
                      : null,
                  onPressed: () =>
                      pushScreen(context, GameScreen(daily: DateTime.now())),
                ),
                if (streak > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: Gap.m),
                    child: _Chip(
                      icon: streak >= ProgressService.streakRewardEvery
                          ? Icons.emoji_events_rounded
                          : Icons.local_fire_department_rounded,
                      iconColor: AppColors.gold,
                      iconSize: _trophySize,
                      text: '$streak-day streak',
                    ),
                  ),
                const SizedBox(height: Gap.xl),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SideButton(
                      label: 'Levels',
                      icon: Icons.grid_view_rounded,
                      color: AppColors.secondary,
                      onPressed: () =>
                          pushScreen(context, const LevelSelectScreen()),
                    ),
                    const SizedBox(width: Gap.xl),
                    _SideButton(
                      label: 'Settings',
                      icon: Icons.settings_rounded,
                      color: AppColors.muted,
                      onPressed: () =>
                          pushScreen(context, const SettingsScreen()),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Half-width menu button with an icon above its label.
class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  static const double _height = 76;
  static const double _iconSize = 28;

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      color: color,
      onPressed: onPressed,
      width: MenuScreen._sideButtonWidth,
      height: _height,
      radius: Radii.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: _iconSize,
            shadows: labelShadows,
          ),
          ClayLabel(label, fontSize: FontSizes.label),
        ],
      ),
    );
  }
}

/// A small dark pill with an icon and a value (coins, streak).
class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.iconColor,
    required this.iconSize,
    required this.text,
    this.semanticLabel,
  });

  final IconData icon;
  final Color iconColor;
  final double iconSize;
  final String text;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Gap.l,
          vertical: Gap.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.ink,
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
              style: const TextStyle(
                color: Colors.white,
                fontFamily: Fonts.display,
                fontSize: FontSizes.label,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
  await pushScreen(context, GameScreen(levelNumber: level, practice: true));
}

/// Asks for a level number. Practice runs never touch saved progress.
class _JumpDialog extends StatefulWidget {
  const _JumpDialog();

  @override
  State<_JumpDialog> createState() => _JumpDialogState();
}

class _JumpDialogState extends State<_JumpDialog> {
  final _controller = TextEditingController();

  /// Highest level the practice box accepts.
  static const int _maxLevel = 9999;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    final n = int.tryParse(_controller.text.trim());
    if (n != null && n >= ProgressService.firstLevel && n <= _maxLevel) {
      Navigator.of(context).pop(n);
    }
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
          hintText: 'Level number (${ProgressService.firstLevel}-$_maxLevel)',
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
