import 'package:flutter/widgets.dart';

import '../services/feedback_service.dart';

/// Provides the [FeedbackService] (sound + haptics) to the widget tree.
class FeedbackScope extends InheritedWidget {
  const FeedbackScope({
    super.key,
    required this.feedback,
    required super.child,
  });

  final FeedbackService feedback;

  static FeedbackService read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<FeedbackScope>();
    assert(scope != null, 'No FeedbackScope above this context');
    return scope!.feedback;
  }

  @override
  bool updateShouldNotify(FeedbackScope oldWidget) =>
      feedback != oldWidget.feedback;
}
