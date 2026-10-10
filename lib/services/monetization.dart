// Interfaces for ads and in-app purchases, with no-op implementations.
//
// Nothing here talks to a real SDK yet. Real implementations (AdMob,
// in_app_purchase, ...) can replace the no-ops without touching game code.

enum AdResult {
  /// The player watched the ad to the end and should be rewarded.
  rewarded,

  /// The player closed the ad early.
  dismissed,

  /// No ad could be shown (none loaded, offline, ads disabled).
  unavailable,
}

abstract class AdService {
  bool get isRewardedReady;

  Future<AdResult> showRewarded();

  /// Full-screen ad between levels. Must never block gameplay if it fails.
  Future<void> showInterstitial();
}

class Product {
  const Product({required this.id, required this.title, required this.price});

  final String id;
  final String title;

  /// Localized price string from the store, e.g. "$1.99".
  final String price;
}

enum PurchaseOutcome { success, cancelled, unavailable }

abstract class PurchaseService {
  Future<List<Product>> products();

  Future<PurchaseOutcome> buy(String productId);

  Future<void> restore();

  /// Whether a non-consumable product (e.g. "remove_ads") is owned.
  bool owns(String productId);
}

class NoopAdService implements AdService {
  const NoopAdService();

  @override
  bool get isRewardedReady => false;

  @override
  Future<AdResult> showRewarded() async => AdResult.unavailable;

  @override
  Future<void> showInterstitial() async {}
}

class NoopPurchaseService implements PurchaseService {
  const NoopPurchaseService();

  @override
  Future<List<Product>> products() async => const [];

  @override
  Future<PurchaseOutcome> buy(String productId) async =>
      PurchaseOutcome.unavailable;

  @override
  Future<void> restore() async {}

  @override
  bool owns(String productId) => false;
}
