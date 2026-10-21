import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/core.dart' show GameSession, dayNumber;

enum Booster { undo, hint, refresh, clear, sort }

/// Persistent progress, boosters and settings, backed by shared_preferences.
class ProgressService extends ChangeNotifier {
  ProgressService._(this._prefs);

  static const int startingBoosters = 3;

  static Future<ProgressService> load() async =>
      ProgressService._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  // Storage keys. Changing any of them loses players' saved progress.
  static const _unlockedKey = 'unlocked';
  static String _bestKey(int level) => 'best_$level';
  static const _starsPrefix = 'stars_';
  static String _starsKey(int level) => '$_starsPrefix$level';
  static String _boosterKey(Booster b) => 'booster_${b.name}';
  static String _tipKey(String id) => 'tip_$id';
  static const _coinsKey = 'coins';
  static const _dailyLastKey = 'daily_last';
  static const _dailyStreakKey = 'daily_streak';
  static const _dailyBestKey = 'daily_best';
  static const _dailyTotalKey = 'daily_total';
  static const _soundKey = 'sound';
  static const _musicKey = 'music';
  static const _hapticsKey = 'haptics';
  static const _symbolsKey = 'symbols';

  /// Settings survive [reset].
  static const _settingKeys = [_soundKey, _musicKey, _hapticsKey, _symbolsKey];

  static const int firstLevel = 1;

  /// Highest level the player may start.
  int get unlockedLevel => _prefs.getInt(_unlockedKey) ?? firstLevel;

  /// Best star rating earned on [level] (0 = not cleared).
  int stars(int level) => _prefs.getInt(_starsKey(level)) ?? 0;

  int get totalStars => _prefs
      .getKeys()
      .where((k) => k.startsWith(_starsPrefix))
      .fold(0, (sum, k) => sum + (_prefs.getInt(k) ?? 0));

  int? bestMoves(int level) => _prefs.getInt(_bestKey(level));

  /// Levels with at least one star.
  int get clearedLevels => _starCounts().where((n) => n > 0).length;

  /// Levels cleared with all three stars.
  int get threeStarLevels =>
      _starCounts().where((n) => n >= GameSession.maxStars).length;

  Iterable<int> _starCounts() => _prefs
      .getKeys()
      .where((k) => k.startsWith(_starsPrefix))
      .map((k) => _prefs.getInt(k) ?? 0);

  /// First-time tips (a new vehicle type, a timed level) are shown once.
  bool tipSeen(String id) => _prefs.getBool(_tipKey(id)) ?? false;

  Future<void> markTipSeen(String id) => _prefs.setBool(_tipKey(id), true);

  /// Every Nth level, the first clear gifts one of each booster.
  static const int rewardEvery = 5;

  /// Records a win. Returns true if it earned the booster reward.
  Future<bool> recordWin(int level, int moves, {int stars = 1}) async {
    final best = bestMoves(level);
    final firstClear = best == null;
    if (best == null || moves < best) {
      await _prefs.setInt(_bestKey(level), moves);
    }
    if (level + 1 > unlockedLevel) {
      await _prefs.setInt(_unlockedKey, level + 1);
    }
    if (stars > this.stars(level)) {
      await _prefs.setInt(_starsKey(level), stars);
    }
    final rewarded = firstClear && level % rewardEvery == 0;
    if (rewarded) await _giftEveryBooster();
    notifyListeners();
    return rewarded;
  }

  /// One more of each booster (level and streak rewards).
  Future<void> _giftEveryBooster() async {
    for (final b in Booster.values) {
      await _prefs.setInt(_boosterKey(b), boosterCount(b) + 1);
    }
  }

  int boosterCount(Booster b) =>
      _prefs.getInt(_boosterKey(b)) ?? startingBoosters;
  int get undoBoosters => boosterCount(Booster.undo);
  int get hintBoosters => boosterCount(Booster.hint);
  int get refreshBoosters => boosterCount(Booster.refresh);
  int get clearBoosters => boosterCount(Booster.clear);
  int get sortBoosters => boosterCount(Booster.sort);

  /// Spends one booster; false if none are left.
  Future<bool> useBooster(Booster b) async {
    final n = boosterCount(b);
    if (n <= 0) return false;
    await _prefs.setInt(_boosterKey(b), n - 1);
    notifyListeners();
    return true;
  }

  Future<void> addBooster(Booster b, int amount) async {
    await _prefs.setInt(_boosterKey(b), boosterCount(b) + amount);
    notifyListeners();
  }

  /// True once the challenge for [date] has been cleared.
  bool dailyDone(DateTime date) =>
      _prefs.getInt(_dailyLastKey) == dayNumber(date);

  /// Consecutive days with a cleared challenge, ending today or yesterday.
  /// A missed day resets it.
  int dailyStreak(DateTime today) {
    final last = _prefs.getInt(_dailyLastKey);
    if (last == null || last < dayNumber(today) - 1) return 0;
    return _prefs.getInt(_dailyStreakKey) ?? 0;
  }

  /// Coins for clearing the daily challenge: [_dailyBaseCoins], plus
  /// [_dailyStreakCoins] per day of streak up to [_dailyStreakCap] days.
  static const int _dailyBaseCoins = 50;
  static const int _dailyStreakCoins = 10;
  static const int _dailyStreakCap = 7;

  static int dailyCoins(int streak) =>
      _dailyBaseCoins +
      _dailyStreakCoins * (streak.clamp(1, _dailyStreakCap) - 1);

  /// Every Nth day of a streak also gifts one of each booster.
  static const int streakRewardEvery = 7;

  int get bestDailyStreak => _prefs.getInt(_dailyBestKey) ?? 0;
  int get dailiesCleared => _prefs.getInt(_dailyTotalKey) ?? 0;

  /// Records a cleared daily challenge. Returns the coins paid and whether
  /// the streak earned the booster gift; both are zero/false if [date] was
  /// already cleared (replays pay nothing).
  Future<({int coins, bool boosters})> recordDaily(DateTime date) async {
    if (dailyDone(date)) return (coins: 0, boosters: false);
    final day = dayNumber(date);
    final streak = _prefs.getInt(_dailyLastKey) == day - 1
        ? (_prefs.getInt(_dailyStreakKey) ?? 0) + 1
        : 1;
    await _prefs.setInt(_dailyLastKey, day);
    await _prefs.setInt(_dailyStreakKey, streak);
    if (streak > bestDailyStreak) await _prefs.setInt(_dailyBestKey, streak);
    await _prefs.setInt(_dailyTotalKey, dailiesCleared + 1);
    final coins = dailyCoins(streak);
    await _prefs.setInt(_coinsKey, this.coins + coins);
    final boosters = streak % streakRewardEvery == 0;
    if (boosters) await _giftEveryBooster();
    notifyListeners();
    return (coins: coins, boosters: boosters);
  }

  static const int startingCoins = 300;

  /// Cost of unlocking one extra lane slot.
  static const int slotUnlockCost = 100;

  int get coins => _prefs.getInt(_coinsKey) ?? startingCoins;

  Future<void> addCoins(int amount) async {
    await _prefs.setInt(_coinsKey, coins + amount);
    notifyListeners();
  }

  /// Spends [amount] coins; false (and nothing spent) if short.
  Future<bool> spendCoins(int amount) async {
    if (amount > coins) return false;
    await _prefs.setInt(_coinsKey, coins - amount);
    notifyListeners();
    return true;
  }

  /// Coins for finishing a level: [_firstClearCoins] plus [_coinsPerStar]
  /// per star on a first clear, afterwards only [_coinsPerStar] per newly
  /// gained star.
  static const int _firstClearCoins = 20;
  static const int _coinsPerStar = 10;

  static int winCoins({required int previousStars, required int stars}) {
    if (previousStars == 0) return _firstClearCoins + _coinsPerStar * stars;
    return stars > previousStars ? _coinsPerStar * (stars - previousStars) : 0;
  }

  /// Timed levels: finishing with at least [fastFinishShare] of the clock
  /// left pays [fastFinishCoins] on top of a paying win.
  static const double fastFinishShare = 0.5;
  static const int fastFinishCoins = 10;

  bool get soundOn => _prefs.getBool(_soundKey) ?? true;
  bool get musicOn => _prefs.getBool(_musicKey) ?? true;
  bool get hapticsOn => _prefs.getBool(_hapticsKey) ?? true;

  /// Accessibility: draw a distinct shape on every bus and passenger.
  bool get symbolsOn => _prefs.getBool(_symbolsKey) ?? false;

  Future<void> setSoundOn(bool v) => _setBool(_soundKey, v);
  Future<void> setMusicOn(bool v) => _setBool(_musicKey, v);
  Future<void> setHapticsOn(bool v) => _setBool(_hapticsKey, v);
  Future<void> setSymbolsOn(bool v) => _setBool(_symbolsKey, v);

  Future<void> _setBool(String key, bool v) async {
    await _prefs.setBool(key, v);
    notifyListeners();
  }

  /// Clears levels, best scores and boosters. Settings are kept.
  Future<void> reset() async {
    final settings = {
      for (final k in _settingKeys)
        if (_prefs.containsKey(k)) k: _prefs.getBool(k)!,
    };
    await _prefs.clear();
    for (final e in settings.entries) {
      await _prefs.setBool(e.key, e.value);
    }
    notifyListeners();
  }
}
