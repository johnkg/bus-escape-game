import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import 'progress_scope.dart';
import 'stats_screen.dart';
import 'ui_style.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressScope.of(context);
    return ScreenFrame(
      title: 'Settings',
      child: ListView(
        padding: const EdgeInsets.all(Gap.xl),
        children: [
          _Group(
            title: 'Sound & feel',
            children: [
              _Switch(
                icon: Icons.volume_up_rounded,
                title: 'Sound effects',
                value: p.soundOn,
                onChanged: p.setSoundOn,
              ),
              _Switch(
                icon: Icons.music_note_rounded,
                title: 'Music',
                value: p.musicOn,
                onChanged: p.setMusicOn,
              ),
              _Switch(
                icon: Icons.vibration_rounded,
                title: 'Haptics',
                value: p.hapticsOn,
                onChanged: p.setHapticsOn,
              ),
            ],
          ),
          const SizedBox(height: Gap.xxl),
          _Group(
            title: 'Accessibility',
            children: [
              _Switch(
                icon: Icons.category_rounded,
                title: 'Color symbols',
                subtitle: 'Show a shape on each bus and passenger',
                value: p.symbolsOn,
                onChanged: p.setSymbolsOn,
              ),
            ],
          ),
          const SizedBox(height: Gap.xxl),
          _Group(
            title: 'Progress',
            children: [
              ListTile(
                key: const Key('stats-tile'),
                leading: const Icon(
                  Icons.bar_chart_rounded,
                  color: AppColors.textMuted,
                ),
                title: const Text('Stats', style: _titleStyle),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textMuted,
                ),
                onTap: () => pushScreen(context, const StatsScreen()),
              ),
            ],
          ),
          const SizedBox(height: Gap.xxl),
          // Kept apart from the other settings: it cannot be undone.
          _Group(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.danger,
                ),
                title: Text(
                  'Reset progress',
                  style: _titleStyle.copyWith(color: AppColors.danger),
                ),
                subtitle: const Text(
                  'Clears levels, best scores and boosters',
                  style: _subtitleStyle,
                ),
                onTap: () => _confirmReset(context, p),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, ProgressService p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await p.reset();
  }
}

const TextStyle _titleStyle = TextStyle(
  color: Colors.white,
  fontSize: FontSizes.label,
  fontWeight: FontWeight.w700,
);

const TextStyle _subtitleStyle = TextStyle(color: AppColors.textMuted);

/// A titled clay card of settings rows.
class _Group extends StatelessWidget {
  const _Group({this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: Gap.m, bottom: Gap.s),
            child: Semantics(
              header: true,
              child: Text(
                title!.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontFamily: Fonts.display,
                  fontSize: FontSizes.small,
                  fontWeight: FontWeight.w600,
                  letterSpacing: _headerSpacing,
                ),
              ),
            ),
          ),
        ClayCard(
          padding: const EdgeInsets.symmetric(vertical: Gap.xs),
          child: Material(
            type: MaterialType.transparency,
            child: Column(children: children),
          ),
        ),
      ],
    );
  }

  static const double _headerSpacing = 1;
}

class _Switch extends StatelessWidget {
  const _Switch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: AppColors.textMuted),
      title: Text(title, style: _titleStyle),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: _subtitleStyle),
      value: value,
      onChanged: onChanged,
    );
  }
}
