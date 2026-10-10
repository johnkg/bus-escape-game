import 'package:flutter/widgets.dart';

import '../services/monetization.dart';

/// Provides ad and purchase services. Defaults to no-ops everywhere.
class MonetizationScope extends InheritedWidget {
  const MonetizationScope({
    super.key,
    this.ads = const NoopAdService(),
    this.purchases = const NoopPurchaseService(),
    required super.child,
  });

  final AdService ads;
  final PurchaseService purchases;

  static MonetizationScope of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MonetizationScope>();
    assert(scope != null, 'No MonetizationScope above this context');
    return scope!;
  }

  @override
  bool updateShouldNotify(MonetizationScope old) =>
      ads != old.ads || purchases != old.purchases;
}
