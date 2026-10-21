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
  bool _rewarded = false;
  int _stars = 0;
  int _coinsEarned = 0;
  int _streak = 0;
  bool _fast = false;
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
    _rewarded = false;
    _stars = 0;
    _coinsEarned = 0;
    _streak = 0;
    _fast = false;
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
      setState(() => _stars = stars);
      return;
    }
    final date = widget.daily;
    if (date != null) {
      setState(() => _stars = stars);
      final result = await progress.recordDaily(date);
      if (mounted) {
        setState(() {
          _coinsEarned = result.coins;
          _rewarded = result.boosters;
          _streak = progress.dailyStreak(date);
        });
      }
      return;
    }
    final previous = progress.stars(widget.levelNumber);
    var coins = ProgressService.winCoins(previousStars: previous, stars: stars);
    final fast = _game.timeFraction >= ProgressService.fastFinishShare;
    if (fast && coins > 0) coins += ProgressService.fastFinishCoins;
    setState(() {
      _stars = stars;
      _coinsEarned = coins;
      _fast = fast && coins > 0;
    });
    final rewarded = await progress.recordWin(
      widget.levelNumber,
      moves,
      stars: stars,
    );
    if (coins > 0) await progress.addCoins(coins);
    if (mounted) setState(() => _rewarded = rewarded);
  }

  Future<void> _useUndo() async {
    final progress = ProgressScope.read(context);
    if (progress.undoBoosters <= 0 || !_game.undo()) return;
    FeedbackScope.read(context).emit(GameEvent.undo);
    await progress.useBooster(Booster.undo);
  }

  Future<void> _useHint() async {
    final progress = ProgressScope.read(context);
    if (progress.hintBoosters <= 0) return;
    if (_game.useHint() == null) {
      _snack('No safe move left. Try Undo.');
      return;
    }
    await progress.useBooster(Booster.hint);
  }

  static const Duration _snackDuration = Duration(seconds: 2);

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), duration: _snackDuration));
  }

  Future<void> _useRefresh() async {
    final progress = ProgressScope.read(context);
    if (progress.refreshBoosters <= 0) return;
    if (!_game.refresh()) {
      _snack("Can't reshuffle right now.");
      return;
    }
    await progress.useBooster(Booster.refresh);
  }

  /// Clear is armed first; the booster is only spent once a vehicle is lifted.
  void _toggleClear() {
    final progress = ProgressScope.read(context);
    if (!_game.clearArmed.value && progress.clearBoosters <= 0) return;
    _game.toggleClear();
  }

  Future<void> _useSort() async {
    final progress = ProgressScope.read(context);
    if (progress.sortBoosters <= 0) return;
    if (!_game.sortQueue()) {
      _snack('Nobody in the queue matches a parked vehicle.');
      return;
    }
    await progress.useBooster(Booster.sort);
  }

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
                              BoosterTile(
                                key: const Key('booster-undo'),
                                icon: Icons.undo,
                                label: 'Undo',
                                count: progress.undoBoosters,
                                enabled: _game.canUndo,
                                onPressed: _useUndo,
                              ),
                              BoosterTile(
                                key: const Key('booster-hint'),
                                icon: Icons.lightbulb_outline,
                                label: 'Hint',
                                count: progress.hintBoosters,
                                enabled: _game.canHint,
                                onPressed: _useHint,
                              ),
                              BoosterTile(
                                key: const Key('booster-refresh'),
                                icon: Icons.shuffle,
                                label: 'Refresh',
                                count: progress.refreshBoosters,
                                enabled: _game.canRefresh,
                                onPressed: _useRefresh,
                              ),
                              BoosterTile(
                                key: const Key('booster-clear'),
                                icon: Icons.flight,
                                label: 'Clear',
                                count: progress.clearBoosters,
                                enabled: _game.canClear,
                                armed: armed,
                                onPressed: _toggleClear,
                              ),
                              BoosterTile(
                                key: const Key('booster-sort'),
                                icon: Icons.sort,
                                label: 'Sort',
                                count: progress.sortBoosters,
                                enabled: _game.canSort,
                                onPressed: _useSort,
                              ),
                            ],
                          ),
                          if (_showResult)
                            ResultOverlay(
                              won: s.status == GameStatus.won,
                              stars: _stars,
                              rewarded: _rewarded,
                              coins: _coinsEarned,
                              daily: widget.daily != null,
                              timedOut: _game.timeUp.value,
                              fast: _fast,
                              streak: _streak,
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
    icon: Icons.undo,
    label: 'Undo',
    count: progress.undoBoosters,
    enabled: _game.canUndo,
    onPressed: _useUndo,
  );
}
