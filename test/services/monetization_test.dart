import 'package:bus_escape_game/services/monetization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoopAdService', () {
    const ads = NoopAdService();

    test('never has an ad ready', () {
      expect(ads.isRewardedReady, isFalse);
    });

    test('rewarded ad request grants nothing', () async {
      expect(await ads.showRewarded(), AdResult.unavailable);
    });

    test('interstitial is a harmless no-op', () async {
      await ads.showInterstitial();
    });
  });

  group('NoopPurchaseService', () {
    const store = NoopPurchaseService();

    test('lists no products', () async {
      expect(await store.products(), isEmpty);
    });

    test('buying is unavailable, not a crash', () async {
      expect(await store.buy('anything'), PurchaseOutcome.unavailable);
    });

    test('restore is a harmless no-op', () async {
      await store.restore();
    });

    test('nothing is owned', () async {
      expect(store.owns('remove_ads'), isFalse);
    });
  });
}
