import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/feedback_service.dart';
import 'services/progress_service.dart';
import 'ui/app_theme.dart';
import 'ui/feedback_scope.dart';
import 'ui/menu_screen.dart';
import 'ui/monetization_scope.dart';
import 'ui/progress_scope.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Portrait only; matches the native manifests.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  final progress = await ProgressService.load();
  final sound = FlameSoundPlayer();
  await sound.preload();
  final feedback = FeedbackService(
    settings: progress,
    sound: sound,
    haptics: SystemHapticsPlayer(),
  );
  runApp(BusEscapeApp(progress: progress, feedback: feedback));
}

class BusEscapeApp extends StatelessWidget {
  /// [feedback] defaults to a silent service (tests, previews).
  BusEscapeApp({super.key, required this.progress, FeedbackService? feedback})
    : feedback = feedback ?? FeedbackService.silent(progress);

  final ProgressService progress;
  final FeedbackService feedback;

  @override
  Widget build(BuildContext context) {
    return ProgressScope(
      progress: progress,
      child: FeedbackScope(
        feedback: feedback,
        // No ads or purchases yet: the no-op services are the defaults.
        child: MonetizationScope(
          child: MaterialApp(
            title: 'Bus Escape',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            home: const MenuScreen(),
          ),
        ),
      ),
    );
  }
}
