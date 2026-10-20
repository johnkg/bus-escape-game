import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/core.dart';
import '../game/bus_escape_game.dart';
import '../game/layout.dart';
import '../levels/level_repository.dart';
import '../services/feedback_service.dart';
import '../services/progress_service.dart';
import 'feedback_scope.dart';
import 'game_hud.dart';
import 'progress_scope.dart';
import 'result_overlay.dart';
import 'widgets.dart';

/// Hosts the Flame game in a centered portrait box (letterboxed on wide
/// screens) with the Flutter HUD, boosters and result dialog on top.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.levelNumber = 0, this.daily});

  final int levelNumber;

  /// Plays the daily challenge for this date instead of a numbered level.
  final DateTime? daily;

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
    _showResult = false;
    _recorded = false;
    _rewarded = false;
    _stars = 0;
    _coinsEarned = 0;
    _streak = 0;
    _paused = false;
    _game.onUnlockRequested = _unlockSlot;
    _game.onAirlift = () => progress.useBooster(Booster.clear);
  }

  void _onStateChanged() {
    final s = _game.stateNotifier.value;
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
    final date = widget.daily;
    if (date != null) {
      setState(() => _stars = stars);
      final coins = await progress.recordDaily(date);
      if (mounted) {
        setState(() {
          _coinsEarned = coins;
          _streak = progress.dailyStreak(date);
        });
      }
      return;
    }
    final previous = progress.stars(widget.levelNumber);
    final coins = ProgressService.winCoins(
      previousStars: previous,
      stars: stars,
    );
    setState(() {
      _stars = stars;
      _coinsEarned = coins;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No safe move left. Try Undo.'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    await progress.useBooster(Booster.hint);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Not enough coins (${ProgressService.slotUnlockCost} needed).',
          ),
          duration: Duration(seconds: 2),
        ),
      );
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
    setState(_startGame);
  }

  void _goTo(int level) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => GameScreen(levelNumber: level)),
    );
  }

  @override
  void dispose() {
    _game.stateNotifier.removeListener(_onStateChanged);
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
                            title: widget.daily == null ? null : 'Daily Challenge',
                            moves: s.moves,
                            coins: progress.coins,
                            onPause: () => _setPaused(true),
                          ),
                          LeftSign(count: s.queue.length),
                          if (_game.level.hint != null)
                            _HintBanner(text: _game.level.hint!),
                          _BoosterBar(
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
                              streak: _streak,
                              onNext: () => _goTo(widget.levelNumber + 1),
                              onRetry: _retry,
                              onMenu: () =>
                                  Navigator.of(context)
                                      .popUntil((r) => r.isFirst),
                              undoButton: _undoButton(
                                progress,
                                const Key('result-undo'),
                              ),
                              extraSlotButton: _game.canAddSlot
                                  ? BigButton(
                                      key: const Key('result-unlock'),
                                      label:
                                          'Unlock slot (${ProgressService.slotUnlockCost})',
                                      color: const Color(0xFF2E9E4F),
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

class _BoosterBar extends StatelessWidget {
  const _BoosterBar({required this.clearArmed, required this.tilesFor});

  final ValueNotifier<bool> clearArmed;
  final List<Widget> Function(bool clearArmed) tilesFor;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: clearArmed,
      builder: (context, armed, _) => Stack(
        children: [
          if (armed)
            Positioned(
              key: const Key('clear-banner'),
              top: GameLayout.boosterTop - 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF39C12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Tap any vehicle to airlift it  (tap Clear to cancel)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            right: 8,
            top: GameLayout.boosterTop,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: tilesFor(armed),
            ),
          ),
        ],
      ),
    );
  }
}

/// Teaching text for tutorial levels, between the HUD and the board.
class _HintBanner extends StatelessWidget {
  const _HintBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 96,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF3F566D),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.15,
          ),
        ),
      ),
    );
  }
}
