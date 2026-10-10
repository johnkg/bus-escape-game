import 'package:flutter/material.dart';

import '../services/progress_service.dart';
import 'progress_scope.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = ProgressScope.of(context);
    return ScreenFrame(
      title: 'Settings',
      child: ListView(
        children: [
          SwitchListTile(
            title: const Text(
              'Sound effects',
              style: TextStyle(color: Colors.white),
            ),
            value: p.soundOn,
            onChanged: p.setSoundOn,
          ),
          SwitchListTile(
            title: const Text('Music', style: TextStyle(color: Colors.white)),
            value: p.musicOn,
            onChanged: p.setMusicOn,
          ),
          SwitchListTile(
            title: const Text('Haptics', style: TextStyle(color: Colors.white)),
            value: p.hapticsOn,
            onChanged: p.setHapticsOn,
          ),
          SwitchListTile(
            title: const Text(
              'Color symbols',
              style: TextStyle(color: Colors.white),
            ),
            subtitle: const Text(
              'Show a shape on each bus and passenger',
              style: TextStyle(color: Colors.white54),
            ),
            value: p.symbolsOn,
            onChanged: p.setSymbolsOn,
          ),
          const Divider(color: Colors.white24),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
            title: const Text(
              'Reset progress',
              style: TextStyle(color: Colors.redAccent),
            ),
            subtitle: const Text(
              'Clears levels, best scores and boosters',
              style: TextStyle(color: Colors.white54),
            ),
            onTap: () => _confirmReset(context, p),
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
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) await p.reset();
  }
}
