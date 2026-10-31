import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/core.dart';
import '../game/bus_escape_game.dart';
import '../game/layout.dart';
import '../levels/level_repository.dart';
import '../services/feedback_service.dart';
import '../services/progress_service.dart';
import 'feedback_scope.dart';
import 'first_time_tips.dart';
import 'game_overlays.dart';
import 'game_hud.dart';
import 'progress_scope.dart';
import 'result_overlay.dart';
import 'ui_style.dart';
import 'widgets.dart';

/// Hosts the Flame game in a centered portrait box (letterboxed on wide
/// screens) with the Flutter HUD, boosters and result dialog on top.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.levelNumber = 0,
    this.daily,
    this.practice = false,
  });

  final int levelNumber;

  /// Plays the daily challenge for this date instead of a numbered level.
  final DateTime? daily;

  /// Plays a numbered level without recording progress, stars or coins
  /// (the menu's hidden level jump).
  final bool practice;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late BusEscapeGame _game;
  bool _showResult = false;
  bool _recorded = false;
  _WinSummary _win = _WinSummary();
  String? _tip;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _startGame();
  }

  void _startGame() {
    final feedback = FeedbackScope.read(context);
    final progress = ProgressScope.read(context);
    feedback.syncMusic(); // first game screen follows a tap, so audio may start
    _game = BusEscapeGame(
      level: widget.daily != null
          ? LevelRepository.dailyLevel(widget.daily!)
          : LevelRepository.levelFor(widget.levelNumber),
      feedback: feedback,
      symbolsEnabled: () => progress.symbolsOn,
    );
    _game.stateNotifier.addListener(_onStateChanged);
    _game.timeUp.addListener(_onTimeUp);
    final limit = widget.daily == null
        ? LevelRepository.timeLimitFor(widget.levelNumber, _game.level)
        : null;
    if (limit != null) _game.startTimer(limit);
    _tip = _firstTimeTips(progress, timed: limit != null);
    _showResult = false;
    _recorded = false;
    _win = _WinSummary();
    _paused = false;
    _game.onUnlockRequested = _unlockSlot;
    _game.onAirlift = () => progress.useBooster(Booster.clear);
  }

  /// A short note for anything the player has not met before: a timed level
  /// or a service vehicle. Each is shown once, ever.
  String? _firstTimeTips(ProgressService progress, {required bool timed}) {
    final tips = firstTimeTipsFor(_game.level, timed: timed);
    final fresh = tips.entries.where((e) => !progress.tipSeen(e.key)).toList();
    if (fresh.isEmpty) return null;
    for (final e in fresh) {
      progress.markTipSeen(e.key);
    }
    return fresh.map((e) => e.value).join('\n');
  }

  void _onTimeUp() {
    if (!_game.timeUp.value || !mounted) return;
    setState(() => _showResult = true);
  }

  void _onStateChanged() {
    final s = _game.stateNotifier.value;
    if (_tip != null && s.moves > 0) setState(() => _tip = null);
    if (s.status == GameStatus.playing) {
      // A booster rescued a lost game: take the dialog away again.
      if (_recorded || _showResult) {
        setState(() {
          _recorded = false;
          _showResult = false;
        });
      }
      return;
    }
    if (_recorded) return;
    _recorded = true;
    if (s.status == GameStatus.won) _recordWin(s.moves, _game.session.stars);
    // Let the last animation finish before covering the board.
    final game = _game;
    Future<void>.delayed(game.resultDelay, () {
      if (mounted &&
          identical(game, _game) &&
          game.session.state.status != GameStatus.playing) {
        setState(() => _showResult = true);
      }
    });
  }

  Future<void> _recordWin(int moves, int stars) async {
    final progress = ProgressScope.read(context);
    if (widget.practice) {
      setState(() => _win.stars = stars);
      return;
    }
    final date = widget.daily;
    if (date != null) {
      setState(() => _win.stars = stars);
      final result = await progress.recordDaily(date);
      if (mounted) {
        setState(() {
          _win.coins = result.coins;
          _win.rewarded = result.boosters;
          _win.streak = progress.dailyStreak(date);
        });
      }
      return;
    }
    final previous = progress.stars(widget.levelNumber);
    var coins = ProgressService.winCoins(previousStars: previous, stars: stars);
    final fast = _game.timeFraction >= ProgressService.fastFinishShare;
    if (fast && coins > 0) coins += ProgressService.fastFinishCoins;
    setState(() {
      _win.stars = stars;
      _win.coins = coins;
      _win.fast = fast && coins > 0;
    });
    final rewarded = await progress.recordWin(
      widget.levelNumber,
      moves,
      stars: stars,
    );
    if (coins > 0) await progress.addCoins(coins);
    if (mounted) setState(() => _win.rewarded = rewarded);
  }

  Future<void> _useUndo() async {
    final progress = ProgressScope.read(context);
    if (progress.boosterCount(Booster.undo) <= 0 || !_game.undo()) return;
    FeedbackScope.read(context).emit(GameEvent.undo);
    await progress.useBooster(Booster.undo);
  }

  /// Runs [apply] if a [booster] is left and spends it when [apply]
  /// succeeds; otherwise tells the player [whyNot].
  Future<void> _useBooster(
    Booster booster,
    bool Function() apply,
    String whyNot,
  ) async {
    final progress = ProgressScope.read(context);
    if (progress.boosterCount(booster) <= 0) return;
    if (!apply()) {
      _snack(whyNot);
      return;
    }
    await progress.useBooster(booster);
  }

  Future<void> _useHint() => _useBooster(
    Booster.hint,
    () => _game.useHint() != null,
    'No safe move left. Try Undo.',
  );

  static const Duration _snackDuration = Duration(seconds: 2);

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), duration: _snackDuration));
  }

  Future<void> _useRefresh() =>
      _useBooster(Booster.refresh, _game.refresh, "Can't reshuffle right now.");

  /// Clear is armed first; the booster is only spent once a vehicle is lifted.
  void _toggleClear() {
    final progress = ProgressScope.read(context);
    if (!_game.clearArmed.value && progress.boosterCount(Booster.clear) <= 0) {
      return;
    }
    _game.toggleClear();
  }

  Future<void> _useSort() => _useBooster(
    Booster.sort,
    _game.sortQueue,
    'Nobody in the queue matches a parked vehicle.',
  );

  /// Tapping a locked lane slot (or the lose card button) buys it with coins.
  Future<void> _unlockSlot() async {
    final progress = ProgressScope.read(context);
    if (!_game.canAddSlot) return;
    if (!await progress.spendCoins(ProgressService.slotUnlockCost)) {
      if (mounted) {
        _snack('Not enough coins (${ProgressService.slotUnlockCost} needed).');
      }
      return;
    }
    if (_game.addExtraSlot()) {
      if (mounted) FeedbackScope.read(context).emit(GameEvent.booster);
    } else {
      await progress.addCoins(ProgressService.slotUnlockCost); // refund
    }
  }

  void _setPaused(bool paused) {
    setState(() => _paused = paused);
    paused ? _game.pauseEngine() : _game.resumeEngine();
  }

  void _retry() {
    _game.stateNotifier.removeListener(_onStateChanged);
    _game.timeUp.removeListener(_onTimeUp);
    setState(_startGame);
  }

  void _goTo(int level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) =>
            GameScreen(levelNumber: level, practice: widget.practice),
      ),
    );
  }

  @override
  void dispose() {
    _game.stateNotifier.removeListener(_onStateChanged);
    _game.timeUp.removeListener(_onTimeUp);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: AspectRatio(
            aspectRatio: GameLayout.width / GameLayout.height,
            child: Stack(
              children: [
                GameWidget(key: ValueKey(_game), game: _game),
                // Overlay lives in the same 390x844 design space as the board
                // so HUD and dialogs scale together with it.
                FittedBox(
                  child: SizedBox(
                    width: GameLayout.width,
                    height: GameLayout.height,
                    child: ValueListenableBuilder<GameState>(
                      valueListenable: _game.stateNotifier,
                      builder: (context, s, _) => Stack(
                        children: [
                          HudTop(
                            levelNumber: widget.levelNumber,
                            title: widget.daily != null
                                ? 'Daily Challenge'
                                : widget.practice
                                ? 'Practice ${widget.levelNumber}'
                                : null,
                            timeLeft: _game.timeLeft,
                            moves: s.moves,
                            coins: progress.coins,
                            onPause: () => _setPaused(true),
                          ),
                          ValueListenableBuilder<int>(
                            valueListenable: _game.passengersLeft,
                            builder: (context, left, _) =>
                                LeftSign(count: left),
                          ),
                          if (_game.level.hint != null)
                            HintBanner(text: _game.level.hint!),
                          if (_tip != null)
                            HintBanner(
                              key: const Key('tip-banner'),
                              text: _tip!,
                              onTap: () => setState(() => _tip = null),
                            ),
                          BoosterBar(
                            clearArmed: _game.clearArmed,
                            tilesFor: (armed) => [
                              for (final booster in Booster.values)
                                _boosterTile(progress, booster, armed: armed),
                            ],
                          ),
                          if (_showResult)
                            ResultOverlay(
                              won: s.status == GameStatus.won,
                              stars: _win.stars,
                              rewarded: _win.rewarded,
                              coins: _win.coins,
                              daily: widget.daily != null,
                              timedOut: _game.timeUp.value,
                              fast: _win.fast,
                              streak: _win.streak,
                              onNext: () => _goTo(widget.levelNumber + 1),
                              onRetry: _retry,
                              onMenu: () =>
                                  Navigator.of(context)
                                      .popUntil((r) => r.isFirst),
                              undoButton: _game.timeUp.value
                                  ? null
                                  : _undoButton(
                                      progress,
                                      const Key('result-undo'),
                                    ),
                              extraSlotButton:
                                  _game.canAddSlot && !_game.timeUp.value
                                  ? BigButton(
                                      key: const Key('result-unlock'),
                                      label:
                                          'Unlock slot (${ProgressService.slotUnlockCost})',
                                      color: AppColors.go,
                                      onPressed: _unlockSlot,
                                    )
                                  : null,
                            ),
                          if (_paused)
                            PauseOverlay(
                              onResume: () => _setPaused(false),
                              onRestart: _retry,
                              onMenu: () =>
                                  Navigator.of(context)
                                      .popUntil((r) => r.isFirst),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _undoButton(ProgressService progress, Key key) => BoosterButton(
    key: key,
    icon: _boosterIcons[Booster.undo]!,
    label: _boosterLabel(Booster.undo),
    count: progress.boosterCount(Booster.undo),
    enabled: _game.canUndo,
    onPressed: _useUndo,
  );

  /// One tile of the booster bar. Clear is [armed] while it waits for the
  /// player to pick a vehicle.
  Widget _boosterTile(
    ProgressService progress,
    Booster booster, {
    required bool armed,
  }) => BoosterTile(
    key: Key('booster-${booster.name}'),
    icon: _boosterIcons[booster]!,
    label: _boosterLabel(booster),
    count: progress.boosterCount(booster),
    armed: booster == Booster.clear && armed,
    enabled: switch (booster) {
      Booster.undo => _game.canUndo,
      Booster.hint => _game.canHint,
      Booster.refresh => _game.canRefresh,
      Booster.clear => _game.canClear,
      Booster.sort => _game.canSort,
    },
    onPressed: switch (booster) {
      Booster.undo => _useUndo,
      Booster.hint => _useHint,
      Booster.refresh => _useRefresh,
      Booster.clear => _toggleClear,
      Booster.sort => _useSort,
    },
  );

  static const Map<Booster, IconData> _boosterIcons = {
    Booster.undo: Icons.undo,
    Booster.hint: Icons.lightbulb_outline,
    Booster.refresh: Icons.shuffle,
    Booster.clear: Icons.flight,
    Booster.sort: Icons.sort,
  };

  /// "Undo", "Hint", ... from the booster's name.
  static String _boosterLabel(Booster booster) =>
      booster.name[0].toUpperCase() + booster.name.substring(1);
}

/// What the result card shows after a win; filled in as the win is saved.
class _WinSummary {
  int stars = 0;

  /// Coins earned by this win.
  int coins = 0;

  /// Daily challenge streak after this win.
  int streak = 0;

  /// Won a timed level with plenty of clock left.
  bool fast = false;

  /// The win gifted one of every booster.
  bool rewarded = false;
}
