import 'dart:math';
import 'dart:ui';

import 'package:bus_escape_game/core/core.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../services/feedback_service.dart';
import 'bus_component.dart';
import 'confetti.dart';
import 'departing_bus.dart';
import 'lane_delta.dart';
import 'lane_view.dart';
import 'locked_slot_button.dart';
import 'layout.dart';
import 'palette.dart';
import 'queue_view.dart';
import 'scene_view.dart';
import 'tap_events.dart';

/// Flame renderer. All rules live in `core/`; this only draws and animates.
class BusEscapeGame extends FlameGame {
  factory BusEscapeGame({
    required Level level,
    FeedbackService? feedback,
    bool Function()? symbolsEnabled,
  }) {
    final w = World();
    return BusEscapeGame._(level, w, feedback, symbolsEnabled ?? () => false);
  }

  BusEscapeGame._(this.level, World w, this.feedback, this._symbolsEnabled)
    : layout = GameLayout(
        rows: level.rows,
        cols: level.cols,
        laneSlots: level.laneSlots,
        lockedSlots: GameSession.maxExtraSlots,
      ),
      super(
        world: w,
        camera: CameraComponent.withFixedResolution(
          world: w,
          width: GameLayout.width,
          height: GameLayout.height,
        ),
      );

  final Level level;
  final GameLayout layout;

  /// Sound + haptics; null means silent.
  final FeedbackService? feedback;

  final bool Function() _symbolsEnabled;

  /// Accessibility setting, read live so toggling it applies immediately.
  bool get showSymbols => _symbolsEnabled();
  late final GameSession session = GameSession(level);

  /// Lets Flutter widgets (HUD, dialogs) react to state changes.
  late final ValueNotifier<GameState> stateNotifier = ValueNotifier(
    session.state,
  );

  /// Called when the player taps a locked lane slot (the screen decides
  /// whether they can afford it).
  VoidCallback? onUnlockRequested;

  /// How long after the final tap the result dialog should wait, so the
  /// bus, boarding and celebration animations can play first.
  Duration resultDelay = const Duration(milliseconds: 700);

  /// Counters so tests can see that the effects fired.
  int confettiBursts = 0;
  int shakes = 0;

  final Map<int, BusComponent> _buses = {};
  late final LaneView _lane = LaneView();
  final List<TimerComponent> _pending = [];
  final Random _rng = Random();

  @override
  Color backgroundColor() => pavementColor;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.addAll([SceneView(), _lane, QueueView()]);
    _spawnBuses();
    _syncLockedButtons();
  }

  void _syncLockedButtons() {
    for (final b in world.children.whereType<LockedSlotButton>().toList()) {
      b.removeFromParent();
    }
    for (var i = layout.laneSlots; i < layout.slotCount; i++) {
      world.add(LockedSlotButton(i));
    }
  }

  void _spawnBuses() {
    for (final b in session.state.buses) {
      final c = BusComponent(b);
      _buses[b.id] = c;
      world.add(c);
    }
  }

  /// Rebuild every visual from core state (after undo / extra slot).
  void _resync() {
    for (final c in world.children.whereType<BusComponent>().toList()) {
      c.removeFromParent();
    }
    _buses.clear();
    _cancelAnimations();
    layout.laneSlots = session.state.lane.length;
    layout.lockedSlots = GameSession.maxExtraSlots - session.extraSlots;
    clearArmed.value = false;
    _spawnBuses();
    _syncLockedButtons();
    stateNotifier.value = session.state;
  }

  /// Stops everything that was scheduled for an earlier move.
  void _cancelAnimations() {
    for (final t in _pending) {
      t.removeFromParent();
    }
    _pending.clear();
    _lane.reset();
    for (final c in [
      ...world.children.whereType<DepartingBus>(),
      ...world.children.whereType<ParticleSystemComponent>(),
    ]) {
      c.removeFromParent();
    }
    for (final e in camera.viewfinder.children.whereType<Effect>().toList()) {
      e.removeFromParent();
    }
    camera.viewfinder.position = Vector2.zero();
  }

  void _runAfter(double seconds, VoidCallback fn) {
    if (seconds <= 0) {
      fn();
      return;
    }
    late final TimerComponent t;
    t = TimerComponent(
      period: seconds,
      removeOnFinish: true,
      onTick: () {
        _pending.remove(t);
        fn();
      },
    );
    _pending.add(t);
    add(t);
  }

  /// Seconds between the staggered after-arrival effects.
  static const double _beat = 0.25;

  /// Plays one post-arrival event: its sound/haptic plus its visual.
  void _playEvent(GameEvent event, LaneDelta delta) {
    feedback?.emit(event);
    switch (event) {
      case GameEvent.board:
        for (final slot in delta.boardedSlots) {
          final leaving = delta.departed.where((d) => d.slot == slot);
          if (leaving.isEmpty) {
            _lane.holding.remove(slot); // reveal the new passenger count
          } else {
            _lane.holding[slot] = leaving.first.bus; // full, about to leave
          }
          _lane.hop(slot);
        }
      case GameEvent.depart:
        for (final d in delta.departed) {
          _lane.holding.remove(d.slot);
          world.add(DepartingBus(slot: d.slot, bus: d.bus));
        }
      case GameEvent.win:
        confettiBursts++;
        world.addAll(buildConfetti(_rng));
      case GameEvent.lose:
        shakes++;
        camera.viewfinder.add(
          MoveEffect.by(
            Vector2(8, 0),
            EffectController(duration: 0.045, alternate: true, repeatCount: 5),
          ),
        );
      case GameEvent.busExit ||
          GameEvent.blocked ||
          GameEvent.undo ||
          GameEvent.booster:
        break;
    }
  }

  bool get canUndo => session.canUndo && session.state.status != GameStatus.won;

  bool get canHint => session.state.status == GameStatus.playing;

  /// The bus currently glowing as a hint, if any.
  int? get hintedBusId {
    for (final b in world.children.whereType<BusComponent>()) {
      if (b.isHinted) return b.bus.id;
    }
    return null;
  }

  /// Makes a good bus glow. Returns its id, or null if there is no safe
  /// move left (nothing is spent or marked in that case).
  int? useHint() {
    if (!canHint) return null;
    final id = Hints.nextBus(session.state, fallbackOrder: level.solution);
    final comp = id == null ? null : _buses[id];
    if (comp == null) return null;
    session.noteHintUsed();
    comp.highlight();
    feedback?.emit(GameEvent.booster);
    return id;
  }

  bool get canAddSlot =>
      session.extraSlots < GameSession.maxExtraSlots &&
      session.state.status != GameStatus.won;

  /// Returns true if a move was undone.
  bool undo() {
    if (!canUndo || !session.undo()) return false;
    _resync();
    return true;
  }

  /// Returns true if a lane slot was added.
  bool addExtraSlot() {
    if (!canAddSlot || !session.addExtraSlot()) return false;
    _resync();
    return true;
  }

  // ---- Refresh / Clear / Sort ----------------------------------------

  /// True while the Clear booster waits for the player to pick a vehicle.
  final ValueNotifier<bool> clearArmed = ValueNotifier(false);

  /// Called once a vehicle was actually airlifted (the screen spends the
  /// booster then, not when it is armed).
  VoidCallback? onAirlift;

  bool get canRefresh =>
      session.state.status == GameStatus.playing &&
      session.state.buses.length >= 2;

  bool get canClear =>
      session.state.status == GameStatus.playing &&
      session.state.buses.isNotEmpty &&
      session.state.lane.contains(null);

  bool get canSort =>
      session.state.status == GameStatus.playing &&
      Rules.sortQueue(session.state) != null;

  /// Arms or disarms Clear; returns whether it is now armed.
  bool toggleClear() {
    if (clearArmed.value) {
      clearArmed.value = false;
    } else if (canClear) {
      clearArmed.value = true;
    }
    return clearArmed.value;
  }

  /// Re-places the vehicles still in the jam. False if it could not.
  bool refresh() {
    if (!canRefresh) return false;
    if (!session.refresh(Rng(_rng.nextInt(1 << 30)))) return false;
    _resync();
    feedback?.emit(GameEvent.booster);
    return true;
  }

  /// Passengers jump the queue to fill parked vehicles. False if none could.
  bool sortQueue() {
    final before = session.state;
    if (!canSort || !session.sort()) return false;
    final after = session.state;
    final events = eventsForSort(before, after);
    final delta = laneDelta(before, after, null);

    resultDelay = _resultDelayFor(after.status, events.length - 1, 0);
    feedback?.emit(GameEvent.booster);
    for (final slot in delta.boardedSlots) {
      _lane.holding[slot] = delta.before[slot]!;
    }
    stateNotifier.value = after;
    _scheduleEvents(events, delta, from: 0);
    return true;
  }

  /// How long after a move the result dialog should wait.
  Duration _resultDelayFor(
    GameStatus status,
    int staggeredEvents,
    double lead,
  ) {
    final tail = switch (status) {
      GameStatus.won => 1.6,
      GameStatus.lost => 0.8,
      GameStatus.playing => 0.0,
    };
    return Duration(
      milliseconds: ((lead + _beat * max(0, staggeredEvents - 1) + tail) * 1000)
          .round(),
    );
  }

  void _scheduleEvents(
    List<GameEvent> events,
    LaneDelta delta, {
    int from = 1,
  }) {
    for (var i = from; i < events.length; i++) {
      _runAfter(_beat * (i - from), () => _playEvent(events[i], delta));
    }
  }

  void tapBus(int id) {
    final before = session.state;
    if (before.status != GameStatus.playing) return;
    final comp = _buses[id];
    if (comp == null) return;

    final airlift = clearArmed.value;
    final moved = airlift ? session.clear(id) : session.tap(id);
    if (!moved) {
      if (!airlift) {
        comp.shake();
        feedback?.emit(GameEvent.blocked);
      }
      return;
    }
    if (airlift) {
      clearArmed.value = false;
      onAirlift?.call();
    }

    final after = session.state;
    final events = eventsForMove(before, after);
    final delta = laneDelta(before, after, comp.bus);
    final flight = airlift ? BusComponent.liftSeconds : comp.flightSeconds(delta.slot);

    // Time the result dialog to land after the last animation.
    resultDelay = _resultDelayFor(after.status, events.length - 1, flight);

    feedback?.emit(events.first);
    // Until the bus arrives and the animation says so, keep the lane
    // looking the way it did before this move's boarding.
    for (final slot in delta.boardedSlots) {
      _lane.holding[slot] = delta.before[slot]!;
    }
    _lane.hidden.add(delta.slot);
    _buses.remove(id);
    stateNotifier.value = after;
    void arrived() {
      _lane.hidden.remove(delta.slot);
      comp.removeFromParent();
      _scheduleEvents(events, delta);
    }

    airlift
        ? comp.liftToLane(delta.slot, arrived)
        : comp.exitToLane(delta.slot, arrived);
  }
}
