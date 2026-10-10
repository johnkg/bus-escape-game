import 'package:flutter/widgets.dart';

import '../services/progress_service.dart';

/// Makes [ProgressService] available to the widget tree and rebuilds
/// dependents when it changes.
class ProgressScope extends InheritedNotifier<ProgressService> {
  const ProgressScope({
    super.key,
    required ProgressService progress,
    required super.child,
  }) : super(notifier: progress);

  /// Like [of] but does not subscribe; for use in callbacks.
  static ProgressService read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'No ProgressScope above this context');
    return scope!.notifier!;
  }

  static ProgressService of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ProgressScope>();
    assert(scope != null, 'No ProgressScope above this context');
    return scope!.notifier!;
  }
}
