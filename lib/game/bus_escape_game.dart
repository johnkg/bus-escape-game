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

  late final QueueView _queue = QueueView(layout);

  /// Bay -> id of the vehicle using it, from the moment it is assigned until
  /// it has pulled away. Bays are visual: a vehicle parks in the next free
  /// open bay, which need not be the slot core state numbered it.
  final Map<int, int> _bayOcc = {};
  final Map<int, int> _bayOfBus = {};

  /// Vehicles that had to wait for a bay that is still emptying, per bay.
  final Map<int, List<int>> _bayWaiting = {};

  /// Passengers on their way to a vehicle's seats, per bay.
  final Map<int, int> _inFlight = {};

  /// Vehicles sent off early; their remaining passengers were already
  /// taken off the queue, so later boarding steps for them are skipped.
  final Set<int> _sentOff = {};

  /// Whether vehicle [id] may pull into [bay] yet.
  bool mayEnter(int bay, int id) => _bayOcc[bay] == id;

  void _syncBays() {
    _bayOcc.clear();
    _bayOfBus.clear();
    _bayWaiting.clear();
    _inFlight.clear();
    _sentOff.clear();
    final lane = session.state.lane;
    for (var i = 0; i < lane.length; i++) {
      final p = lane[i];
      if (p == null) continue;
      _bayOcc[i] = p.id;
      _bayOfBus[p.id] = i;
    }
    _lane.syncFrom(lane);
    _queue.reset(session.state.queue);
  }

  /// The next open bay with nobody in it. Failing that, a bay whose vehicle
  /// core state has already sent away (it is only still boarding on screen),
  /// which [_sendOff] then clears at once so nobody has to wait.
  int _pickBay(int preferred, GameState after) {
    final inLane = {
      for (final p in after.lane)
        if (p != null) p.id,
    };
    final open = [for (var b = 0; b < layout.laneSlots; b++) b];
    final free = open.where((b) => !_bayOcc.containsKey(b)).toList();
    if (free.isNotEmpty) {
      return free.contains(preferred) ? preferred : free.first;
    }
    final leaving = open.where((b) => !inLane.contains(_bayOcc[b])).toList();
    for (final b in leaving) {
      if (_lane.bays[b]?.id == _bayOcc[b]) return b; // parked: can go now
    }
    return leaving.isNotEmpty ? leaving.first : preferred;
  }

  /// Seats a leaving vehicle's remaining passengers at once and drives it
  /// off, freeing its bay immediately.
  void _sendOff(int bay) {
    final id = _bayOcc[bay];
    final parked = _lane.bays[bay];
    if (id == null || parked == null || parked.id != id) return;
    final remaining = parked.capacity - parked.boarded - (_inFlight[bay] ?? 0);
    for (var i = 0; i < remaining; i++) {
      _queue.take(parked.colorIndex);
    }
    _sentOff.add(id);
    _inFlight[bay] = 0;
    _depart(bay, parked.withBoarded(parked.capacity));
    _freeBay(bay);
  }

  void _depart(int bay, ParkedBus full) {
    _lane.bays.remove(bay);
    _bayOfBus.remove(full.id);
    feedback?.emit(GameEvent.depart);
    world.add(DepartingBus(slot: bay, bus: full));
  }

  /// Returns true if [id] got [bay] straight away.
  bool _claimBay(int bay, int id) {
    if (_bayOcc[bay] == null) {
      _bayOcc[bay] = id;
      return true;
    }
    (_bayWaiting[bay] ??= []).add(id);
    return false;
  }

  void _freeBay(int bay) {
    _bayOcc.remove(bay);
    final waiting = _bayWaiting[bay];
    if (waiting != null && waiting.isNotEmpty) {
      _bayOcc[bay] = waiting.removeAt(0);
    }
  }

  @override
  Color backgroundColor() => pavementColor;

  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    world.addAll([SceneView(), _lane, _queue]);
    _syncBays();
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
    _syncBays();
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

  /// Seconds between passengers setting off.
  static const double _stride = 0.12;

  double _strideFor(int total) => total <= 1 ? 0 : min(_stride, 0.9 / total);

  double _boardSeconds(LaneDelta delta) {
    final total = delta.boardingOrder.length;
    if (total == 0) return 0;
    return _strideFor(total) * (total - 1) + BoardingPassenger.duration;
  }

  /// Walks the passengers into their vehicles one at a time. A vehicle
  /// pulls away the moment its last seat is taken, whatever the others do.
  void _boardOneByOne(LaneDelta delta) {
    final steps = delta.boardingOrder;
    final stride = _strideFor(steps.length);
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      _runAfter(stride * i, () => _sendPassenger(step.busId, step.color));
    }
  }

  void _sendPassenger(int busId, int color) {
    if (_sentOff.contains(busId)) return;
    final bay = _bayOfBus[busId];
    final parked = bay == null ? null : _lane.bays[bay];
    if (bay == null || parked == null || parked.id != busId) return;
    final seatNo = parked.boarded + (_inFlight[bay] ?? 0);
    _inFlight[bay] = (_inFlight[bay] ?? 0) + 1;
    final seat = laneSeat(layout.laneSlotRect(bay), parked, seatNo);
    world.add(
      BoardingPassenger(
        from: _queue.take(color) ?? layout.queuePoint(0),
        to: seat.center,
        toScale: seat.scale,
        colorIndex: color,
        onArrived: () => _passengerSeated(bay, busId),
      ),
    );
  }

  void _passengerSeated(int bay, int busId) {
    final parked = _lane.bays[bay];
    if (parked == null || parked.id != busId) return;
    _inFlight[bay] = max(0, (_inFlight[bay] ?? 1) - 1);
    final now = parked.withBoarded(parked.boarded + 1);
    if (!now.isFull) {
      _lane.bays[bay] = now;
      _lane.hop(bay);
      return;
    }
    // Full: off it goes, and the bay is free for the next vehicle.
    _depart(bay, now);
    _runAfter(0.3, () => _freeBay(bay));
  }

  /// Plays one post-arrival event: its sound/haptic plus its visual.
  void _playEvent(GameEvent event, LaneDelta delta) {
    // Departures are played by the vehicles themselves, as each one fills.
    if (event != GameEvent.depart) feedback?.emit(event);
    switch (event) {
      case GameEvent.board:
        _boardOneByOne(delta);
      case GameEvent.depart:
        break;
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
    final delta = laneDelta(
      before,
      after,
      null,
      queue: Rules.sortedQueue(before),
    );

    resultDelay = _resultDelayFor(after.status, events, delta, 0, 0);
    feedback?.emit(GameEvent.booster);
    stateNotifier.value = after;
    _scheduleEvents(events, delta, from: 0);
    return true;
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
    final bay = _pickBay(delta.slot, after);
    final occupant = _bayOcc[bay];
    if (occupant != null && !after.lane.any((p) => p?.id == occupant)) {
      _sendOff(bay); // it is leaving anyway; don't make this one wait
    }
    _bayOfBus[id] = bay;
    final immediate = _claimBay(bay, id);
    final flight = airlift
        ? BusComponent.liftSeconds
        : comp.flightSeconds(bay);
    // A vehicle held back for a bay that is still emptying arrives later.
    final wait = immediate ? 0.0 : 1.2;

    // Time the result dialog to land after the last animation.
    resultDelay = _resultDelayFor(after.status, events, delta, 1, flight + wait);

    feedback?.emit(events.first);
    _buses.remove(id);
    stateNotifier.value = after;
    void arrived() {
      comp.removeFromParent();
      _lane.bays[bay] = delta.before[delta.slot]!;
      _scheduleEvents(events, delta);
    }

    bool gate() => mayEnter(bay, id);
    airlift
        ? comp.liftToLane(bay, arrived, gate)
        : comp.exitToLane(bay, arrived, gate);
  }
}
