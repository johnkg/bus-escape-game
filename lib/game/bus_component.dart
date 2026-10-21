import 'dart:math';
import 'dart:ui';

import 'package:bus_escape_game/core/core.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';

import 'bus_escape_game.dart';
import 'parked_vehicle_painter.dart';
import 'layers.dart';
import 'layout.dart';
import 'symbols.dart';
import 'vehicle_painter.dart';

/// A bus sitting on the grid. Tapping asks the game to drive it out.
class BusComponent extends PositionComponent
    with TapCallbacks, HasGameReference<BusEscapeGame> {
  BusComponent(this.bus) : super(priority: Layer.jam + _bottomRow(bus));

  /// Lower rows draw later so a vehicle's side panel overlaps the one below.
  static int _bottomRow(Bus bus) =>
      bus.dir.isHorizontal ? bus.row : bus.row + bus.length - 1;

  /// Vehicles in transit draw above the grid; later ones above earlier ones.
  static int _flyPriority = Layer.flying;

  final Bus bus;
  Vector2? _home;

  /// Seconds the hint glow has left.
  double _hintLeft = 0;

  bool get isHinted => _hintLeft > 0;

  void highlight() => _hintLeft = _hintSeconds;

  /// How long a hint keeps a vehicle glowing.
  static const double _hintSeconds = 3;

  @override
  void update(double dt) {
    if (_hintLeft > 0) _hintLeft = max(0, _hintLeft - dt);
    if (_route != null) _stepFlight(dt);
    final lift = _liftSlot;
    if (lift != null && _gate!()) {
      _liftSlot = null;
      _startLift(lift);
    }
  }

  @override
  void onLoad() {
    final cell = game.layout.cellSize;
    final w = bus.dir.isHorizontal ? bus.length : 1;
    final h = bus.dir.isHorizontal ? 1 : bus.length;
    size = Vector2(w * cell, h * cell);
    position = game.layout.gridOrigin + Vector2(bus.col * cell, bus.row * cell);
    _home = position.clone();
  }

  @override
  void onTapDown(TapDownEvent event) => game.tapBus(bus.id);

  /// Drive speed on the way to the lane, in design pixels per second.
  static const double _driveSpeed = 640;

  /// How long [exitToLane] takes in total; later effects are timed from it.
  double flightSeconds(int slot) => _flightTime(_routeTo(slot));

  /// Extra time on every drive for pulling away and parking.
  static const double _pullAwaySeconds = 0.15;

  static double _flightTime(List<Vector2> route) =>
      _pullAwaySeconds + _routeLength(route) / _driveSpeed;

  static double _routeLength(List<Vector2> route) {
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += route[i].distanceTo(route[i - 1]);
    }
    return total;
  }

  /// Seconds the Clear helicopter takes to carry a vehicle to the lane.
  static const double liftSeconds = 0.55;

  /// Clear booster: carried straight to the lane slot, over everything.
  void liftToLane(int slot, VoidCallback onArrived, bool Function() gate) {
    _gate = gate;
    _onArrived = onArrived;
    priority = ++_flyPriority;
    _liftSlot = slot; // takes off once the bay is free
  }

  int? _liftSlot;

  /// True once the vehicle may pull into its bay (the last one has left).
  bool Function()? _gate;

  void _startLift(int slot) {
    final onArrived = _onArrived!;
    _onArrived = null;
    final c = game.layout.laneSlotRect(slot).center;
    final target = Vector2(c.dx, c.dy) - size / 2;
    add(
      MoveEffect.to(
        target,
        EffectController(duration: liftSeconds, curve: Curves.easeInOutCubic),
        onComplete: onArrived,
      ),
    );
  }

  // Flight state: the vehicle follows [_route] (centre points), turning at
  // each corner, then pulls into its bay.
  List<Vector2>? _route;
  double _flightT = 0;
  double _flightDuration = 1;
  Direction _heading = Direction.north;
  int _slot = 0;
  bool _inBay = false;
  VoidCallback? _onArrived;

  /// Room a vehicle leaves between itself and the lot, or the screen edge,
  /// when it turns; route points closer than [_minStep] are merged.
  static const double _lotClearance = 6;
  static const double _edgeMargin = 4;
  static const double _minStep = 0.5;

  /// Centre-point route: out of the lot along the vehicle's direction, round
  /// to the drive strip below the bays, along it, then up into [slot].
  List<Vector2> _routeTo(int slot) {
    final layout = game.layout;
    final g = layout.gridRect;
    final cell = layout.cellSize;
    final long = bus.length * cell;
    final halfShort = cell / 2;
    final start = layout.gridOrigin +
        Vector2(
          (bus.col + (bus.dir.isHorizontal ? bus.length : 1) / 2) * cell,
          (bus.row + (bus.dir.isHorizontal ? 1 : bus.length) / 2) * cell,
        );
    final bay = layout.laneSlotRect(slot).center;
    final bayCentre = Vector2(bay.dx, bay.dy);
    const driveY = GameLayout.driveY;
    const w = GameLayout.width;

    final pts = <Vector2>[start];
    void go(double x, double y) {
      if (pts.last.distanceTo(Vector2(x, y)) > _minStep) pts.add(Vector2(x, y));
    }

    switch (bus.dir) {
      case Direction.north:
        break;
      case Direction.west:
        go(
          max(g.left - long / 2 - _lotClearance, halfShort + _edgeMargin),
          start.y,
        );
      case Direction.east:
        go(
          min(g.right + long / 2 + _lotClearance, w - halfShort - _edgeMargin),
          start.y,
        );
      case Direction.south:
        go(start.x, g.bottom + long / 2 + _lotClearance);
        go(
          start.x < w / 2
              ? halfShort + _edgeMargin
              : w - halfShort - _edgeMargin,
          pts.last.y,
        );
    }
    go(pts.last.x, driveY);
    go(bayCentre.x, driveY);
    go(bayCentre.x, bayCentre.y);
    if (pts.length == 1) pts.add(bayCentre);
    return pts;
  }

  /// Drive out, along the road and into the bay.
  void exitToLane(int slot, VoidCallback onArrived, bool Function() gate) {
    _gate = gate;
    final route = _routeTo(slot);
    priority = ++_flyPriority; // fly above everything else
    anchor = Anchor.center;
    position = route.first.clone();
    _route = route;
    _flightT = 0;
    _flightDuration = _flightTime(route);
    _onArrived = onArrived;
    _slot = slot;
    _applyPose(route.first, route[1]);
  }

  /// The size change runs over this stretch of the drive before the bay
  /// (as shares of it): it starts at [_morphFrom] and lasts [_morphSpan].
  static const double _morphFrom = 0.2;
  static const double _morphSpan = 0.8;

  void _stepFlight(double dt) {
    final route = _route!;
    var t = _flightT + dt;
    // Wait at the kerb, short of the last stretch, while the bay is taken.
    if (!_gate!()) {
      final total = _routeLength(route);
      final last = route.last.distanceTo(route[route.length - 2]);
      final reach = Curves.easeInOutSine.transform(
        (t / _flightDuration).clamp(0.0, 1.0),
      );
      if (reach * total > total - last) t = _flightT;
    }
    _flightT = t;
    final p = (_flightT / _flightDuration).clamp(0.0, 1.0);
    final eased = Curves.easeInOutSine.transform(p);
    final total = _routeLength(route);
    var left = eased * total;
    // Shrink from jam size to bay size while driving, so the vehicle
    // reaches its bay already the size it will park at.
    final firstPart = total - route.last.distanceTo(route[route.length - 2]);
    final morph = firstPart <= 0
        ? 1.0
        : Curves.easeInOut.transform(
            ((left / firstPart - _morphFrom) / _morphSpan).clamp(0.0, 1.0),
          );
    for (var i = 1; i < route.length; i++) {
      final seg = route[i].distanceTo(route[i - 1]);
      if (left <= seg || i == route.length - 1) {
        final t = seg == 0 ? 1.0 : (left / seg).clamp(0.0, 1.0);
        position = route[i - 1] + (route[i] - route[i - 1]) * t;
        _applyPose(
          route[i - 1],
          route[i],
          last: i == route.length - 1,
          morph: morph,
        );
        break;
      }
      left -= seg;
    }
    if (p >= 1) {
      final done = _onArrived;
      _route = null;
      _onArrived = null;
      done?.call();
    }
  }

  void _applyPose(
    Vector2 from,
    Vector2 to, {
    bool last = false,
    double morph = 0,
  }) {
    final d = to - from;
    final h = d.x.abs() > d.y.abs()
        ? (d.x > 0 ? Direction.east : Direction.west)
        : (d.y > 0 ? Direction.south : Direction.north);
    _heading = h;
    _inBay = last && h == Direction.north;
    final cell = game.layout.cellSize;
    final slot = game.layout.laneSlotRect(_slot);
    if (_inBay) {
      size = Vector2(slot.width, slot.height);
      return;
    }
    final parked = ParkedBus(
      id: bus.id,
      colorIndex: bus.colorIndex,
      capacity: bus.capacity,
    );
    final lane = laneVehicleSize(slot, parked); // nose up: (wide, long)
    final long = bus.length * cell + (lane.height - bus.length * cell) * morph;
    final wide = cell + (lane.width - cell) * morph;
    size = h.isHorizontal ? Vector2(long, wide) : Vector2(wide, long);
  }

  /// A blocked vehicle jolts this far forward and back.
  static const double _shakeDistance = 6;
  static const double _shakeStep = 0.05;

  void shake() {
    if (children.whereType<Effect>().isNotEmpty) return;
    final d =
        Vector2(bus.dir.dCol.toDouble(), bus.dir.dRow.toDouble()) *
        _shakeDistance;
    add(
      SequenceEffect([
        MoveEffect.by(d, EffectController(duration: _shakeStep)),
        MoveEffect.by(-d * 2, EffectController(duration: _shakeStep * 2)),
        MoveEffect.by(d, EffectController(duration: _shakeStep)),
      ], onComplete: () => position = _home!.clone()),
    );
  }

  /// Gap between neighbouring jam vehicles, as a share of a cell.
  static const double _jamInset = 0.06;

  // Hint glow: a pulsing white ring round the roof.
  static const double _pulseBase = 0.55;
  static const double _pulseDepth = 0.45;
  static const double _pulseSpeed = 9;
  static const double _glowSpread = 3;
  static const double _glowRadius = 12;
  static const double _glowWidth = 5;
  static const int _glowRgb = 255;

  /// The color symbol sits toward the tail so the arrow stays visible.
  static const double _symbolBack = 0.3;
  static const double _symbolSize = 0.36;

  @override
  void render(Canvas canvas) {
    final cell = game.layout.cellSize;
    if (_route != null && _inBay) {
      paintLaneVehicle(
        canvas,
        Rect.fromLTWH(0, 0, size.x, size.y),
        ParkedBus(
          id: bus.id,
          colorIndex: bus.colorIndex,
          capacity: bus.capacity,
        ),
        symbols: game.showSymbols,
      );
      return;
    }
    final flying = _route != null;
    final dir = flying ? _heading : bus.dir;
    final r = Rect.fromLTWH(0, 0, size.x, size.y).deflate(cell * _jamInset);
    final roof = paintVehicle(
      canvas,
      r,
      bus.colorIndex,
      dir,
      length: bus.length,
      depth: cell * vehicleDepthFactor,
      showArrow: !flying,
    );
    if (flying) return;
    if (isHinted) {
      final pulse = _pulseBase + _pulseDepth * sin(_hintLeft * _pulseSpeed);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          roof.inflate(_glowSpread),
          const Radius.circular(_glowRadius),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = _glowWidth
          ..color = Color.fromRGBO(_glowRgb, _glowRgb, _glowRgb, pulse),
      );
    }
    if (game.showSymbols) {
      final long = bus.dir.isHorizontal ? roof.width : roof.height;
      final back = Offset(-bus.dir.dCol.toDouble(), -bus.dir.dRow.toDouble());
      paintSymbol(
        canvas,
        roof.center + back * (long * _symbolBack),
        roof.shortestSide * _symbolSize,
        symbolFor(bus.colorIndex),
      );
    }
  }
}
