import 'dart:math';
import 'dart:ui';

import 'package:bus_escape_game/core/core.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';

import '../services/feedback_service.dart';
import 'boarding_passenger.dart';
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

  /// Queue as drawn while passengers are still walking to their vehicle;
  /// null means draw the real queue.
  List<int>? queueShown;
  int _boardingRuns = 0;

  /// Slot -> id of the vehicle that holds it visually, from the moment it
  /// is assigned until its bus has driven off. Later vehicles for the same
  /// slot queue up in [_slotWaiting] instead of overlapping it.
  final Map<int, int> _slotOwner = {};
  final Map<int, List<int>> _slotWaiting = {};

  /// Whether vehicle [id] may pull into [slot] yet.
  bool mayEnter(int slot, int id) => _slotOwner[slot] == id;

  /// Returns true if [id] got the slot straight away.
  bool _claimSlot(int slot, int id) {
    if (_slotOwner[slot] == null) {
      _slotOwner[slot] = id;
      return true;
    }
    (_slotWaiting[slot] ??= []).add(id);
    return false;
  }

  void _freeSlot(int slot) {
    _slotOwner.remove(slot);
    final waiting = _slotWaiting[slot];
    if (waiting != null && waiting.isNotEmpty) {
      _slotOwner[slot] = waiting.removeAt(0);
      _lane.hidden.add(slot);
    }
  }

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
    _slotOwner.clear();
    _slotWaiting.clear();
    queueShown = null;
    _boardingRuns = 0;
    for (final c in [
      ...world.children.whereType<DepartingBus>(),
      ...world.children.whereType<BoardingPassenger>(),
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

  /// Seconds between passengers setting off, and the whole boarding run.
  static const double _stride = 0.16;

  double _strideFor(int total) => total <= 1 ? 0 : min(_stride, 1.0 / total);

  double _boardSeconds(LaneDelta delta) {
    final total = delta.boardCounts.values.fold(0, (a, b) => a + b);
    if (total == 0) return 0;
    return _strideFor(total) * (total - 1) + BoardingPassenger.duration;
  }

  /// Walks the passengers into their vehicles one at a time.
  void _boardOneByOne(LaneDelta delta) {
    final steps = <(int slot, int color)>[
      for (final slot in delta.boardedSlots)
        for (var i = 0; i < (delta.boardCounts[slot] ?? 0); i++)
          (slot, delta.before[slot]!.colorIndex),
    ];
    final stride = _strideFor(steps.length);
    final seated = <int, int>{
      for (final slot in delta.boardedSlots) slot: delta.before[slot]!.boarded,
    };
    for (var i = 0; i < steps.length; i++) {
      final (slot, color) = steps[i];
      _runAfter(stride * i, () {
        final shown = queueShown;
        var idx = shown?.indexOf(color) ?? -1;
        if (idx >= 0) shown!.removeAt(idx);
        idx = idx < 0 ? 0 : min(idx, GameLayout.queueVisible - 1);
        final bay = layout.laneSlotRect(slot);
        world.add(
          BoardingPassenger(
            from: layout.queuePoint(idx),
            to: Offset(bay.center.dx, bay.bottom - 22),
            colorIndex: color,
            onArrived: () {
              final n = seated[slot] = seated[slot]! + 1;
              final held = _lane.holding[slot];
              if (held != null) _lane.holding[slot] = held.withBoarded(n);
              _lane.hop(slot);
            },
          ),
        );
      });
    }
    _runAfter(_boardSeconds(delta), () {
      for (final slot in delta.boardedSlots) {
        if (!delta.departed.any((d) => d.slot == slot)) {
          _lane.holding.remove(slot); // show the real passenger count
        }
      }
      _endBoardingRun();
    });
  }

  void _endBoardingRun() {
    if (_boardingRuns > 0 && --_boardingRuns == 0) queueShown = null;
  }

  /// Plays one post-arrival event: its sound/haptic plus its visual.
  void _playEvent(GameEvent event, LaneDelta delta) {
    feedback?.emit(event);
    switch (event) {
      case GameEvent.board:
        _boardOneByOne(delta);
      case GameEvent.depart:
        for (final d in delta.departed) {
          _lane.holding.remove(d.slot);
          world.add(DepartingBus(slot: d.slot, bus: d.bus));
          // Let the leaving bus clear the bay before the next one pulls in.
          _runAfter(0.25, () => _freeSlot(d.slot));
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

    resultDelay = _resultDelayFor(after.status, events, delta, 0, 0);
    feedback?.emit(GameEvent.booster);
    _beginBoardingRun(before, events);
    for (final slot in delta.boardedSlots) {
      _lane.holding[slot] = delta.before[slot]!;
    }
    stateNotifier.value = after;
    _scheduleEvents(events, delta, from: 0);
    return true;
  }

  /// Keeps the queue looking untouched until the passengers walk off it.
  void _beginBoardingRun(GameState before, List<GameEvent> events) {
    _boardingRuns++;
    queueShown ??= [...before.queue];
    if (!events.contains(GameEvent.board)) _endBoardingRun();
  }

  /// Start time of each event from [from] on, relative to the first one.
  List<double> _eventOffsets(
    List<GameEvent> events,
    LaneDelta delta,
    int from,
  ) {
    final out = <double>[];
    var t = 0.0;
    for (var i = from; i < events.length; i++) {
      out.add(t);
      t += events[i] == GameEvent.board ? _boardSeconds(delta) + 0.12 : _beat;
    }
    return out;
  }

  /// How long after a move the result dialog should wait.
  Duration _resultDelayFor(
    GameStatus status,
    List<GameEvent> events,
    LaneDelta delta,
    int from,
    double lead,
  ) {
    final tail = switch (status) {
      GameStatus.won => 1.6,
      GameStatus.lost => 0.8,
      GameStatus.playing => 0.0,
    };
    final offsets = _eventOffsets(events, delta, from);
    final last = offsets.isEmpty ? 0.0 : offsets.last;
    return Duration(milliseconds: ((lead + last + tail) * 1000).round());
  }

  void _scheduleEvents(
    List<GameEvent> events,
    LaneDelta delta, {
    int from = 1,
  }) {
    final offsets = _eventOffsets(events, delta, from);
    for (var i = from; i < events.length; i++) {
      _runAfter(offsets[i - from], () => _playEvent(events[i], delta));
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
    final flight = airlift
        ? BusComponent.liftSeconds
        : comp.flightSeconds(delta.slot);

    final slot = delta.slot;
    final immediate = _claimSlot(slot, id);
    // A vehicle queued behind one that is still leaving arrives later.
    final wait = immediate ? 0.0 : 1.2;

    // Time the result dialog to land after the last animation.
    resultDelay = _resultDelayFor(after.status, events, delta, 1, flight + wait);

    feedback?.emit(events.first);
    _beginBoardingRun(before, events);
    // Until the bus arrives and the animation says so, keep the lane
    // looking the way it did before this move's boarding. The new bus's
    // own bay is set up on arrival: it may still show the previous bus.
    for (final s in delta.boardedSlots) {
      if (s != slot) _lane.holding[s] = delta.before[s]!;
    }
    if (immediate) _lane.hidden.add(slot);
    _buses.remove(id);
    stateNotifier.value = after;
    void arrived() {
      _lane.hidden.remove(slot);
      comp.removeFromParent();
      if (delta.boardedSlots.contains(slot)) {
        _lane.holding[slot] = delta.before[slot]!;
      }
      _scheduleEvents(events, delta);
    }

    bool gate() => mayEnter(slot, id);
    airlift
        ? comp.liftToLane(slot, arrived, gate)
        : comp.exitToLane(slot, arrived, gate);
  }
}
