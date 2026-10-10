import 'dart:math';
import 'dart:ui';

import 'package:bus_escape_game/core/core.dart';
import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flame/events.dart';
import 'package:flutter/animation.dart';

import 'bus_escape_game.dart';
import 'lane_view.dart';
import 'layout.dart';
import 'palette.dart';
import 'symbols.dart';
import 'vehicle_painter.dart';

/// A bus sitting on the grid. Tapping asks the game to drive it out.
class BusComponent extends PositionComponent
    with TapCallbacks, HasGameReference<BusEscapeGame> {
  BusComponent(this.bus) : super(priority: 10 + _bottomRow(bus));

  /// Lower rows draw later so a vehicle's side panel overlaps the one below.
  static int _bottomRow(Bus bus) =>
      bus.dir.isHorizontal ? bus.row : bus.row + bus.length - 1;

  final Bus bus;
  Vector2? _home;

  /// Seconds the hint glow has left.
  double _hintLeft = 0;

  bool get isHinted => _hintLeft > 0;

  void highlight() => _hintLeft = 3;

  @override
  void update(double dt) {
    if (_hintLeft > 0) _hintLeft = max(0, _hintLeft - dt);
    if (_route != null) _stepFlight(dt);
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

  static double _flightTime(List<Vector2> route) =>
      0.15 + _routeLength(route) / _driveSpeed;

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
  void liftToLane(int slot, VoidCallback onArrived) {
    final c = game.layout.laneSlotRect(slot).center;
    final target = Vector2(c.dx, c.dy) - size / 2;
    priority = 200;
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
  bool _inBay = false;
  VoidCallback? _onArrived;

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
      if (pts.last.distanceTo(Vector2(x, y)) > 0.5) pts.add(Vector2(x, y));
    }

    switch (bus.dir) {
      case Direction.north:
        break;
      case Direction.west:
        go(max(g.left - long / 2 - 6, halfShort + 4), start.y);
      case Direction.east:
        go(min(g.right + long / 2 + 6, w - halfShort - 4), start.y);
      case Direction.south:
        go(start.x, g.bottom + long / 2 + 6);
        go(
          start.x < w / 2 ? halfShort + 4 : w - halfShort - 4,
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
  void exitToLane(int slot, VoidCallback onArrived) {
    final route = _routeTo(slot);
    priority = 200; // fly above everything else
    anchor = Anchor.center;
    position = route.first.clone();
    _route = route;
    _flightT = 0;
    _flightDuration = _flightTime(route);
    _onArrived = onArrived;
    _applyPose(route.first, route[1]);
  }

  void _stepFlight(double dt) {
    final route = _route!;
    _flightT += dt;
    final p = (_flightT / _flightDuration).clamp(0.0, 1.0);
    final eased = Curves.easeInOutSine.transform(p);
    var left = eased * _routeLength(route);
    for (var i = 1; i < route.length; i++) {
      final seg = route[i].distanceTo(route[i - 1]);
      if (left <= seg || i == route.length - 1) {
        final t = seg == 0 ? 1.0 : (left / seg).clamp(0.0, 1.0);
        position = route[i - 1] + (route[i] - route[i - 1]) * t;
        _applyPose(route[i - 1], route[i], last: i == route.length - 1);
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

  void _applyPose(Vector2 from, Vector2 to, {bool last = false}) {
    final d = to - from;
    final h = d.x.abs() > d.y.abs()
        ? (d.x > 0 ? Direction.east : Direction.west)
        : (d.y > 0 ? Direction.south : Direction.north);
    _heading = h;
    _inBay = last && h == Direction.north;
    final cell = game.layout.cellSize;
    if (_inBay) {
      final r = game.layout.laneSlotRect(0);
      size = Vector2(r.width, r.height);
    } else {
      final long = bus.length * cell;
      size = h.isHorizontal ? Vector2(long, cell) : Vector2(cell, long);
    }
  }

  void shake() {
    if (children.whereType<Effect>().isNotEmpty) return;
    final d = Vector2(bus.dir.dCol.toDouble(), bus.dir.dRow.toDouble()) * 6;
    add(
      SequenceEffect([
        MoveEffect.by(d, EffectController(duration: 0.05)),
        MoveEffect.by(-d * 2, EffectController(duration: 0.1)),
        MoveEffect.by(d, EffectController(duration: 0.05)),
      ], onComplete: () => position = _home!.clone()),
    );
  }

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
    final r = Rect.fromLTWH(0, 0, size.x, size.y).deflate(cell * 0.06);
    final roof = paintVehicle(
      canvas,
      r,
      busColors[bus.colorIndex % busColors.length],
      dir,
      length: bus.length,
      depth: cell * vehicleDepthFactor,
      showArrow: !flying,
    );
    if (flying) return;
    if (isHinted) {
      final pulse = 0.55 + 0.45 * sin(_hintLeft * 9);
      canvas.drawRRect(
        RRect.fromRectAndRadius(roof.inflate(3), const Radius.circular(12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..color = Color.fromRGBO(255, 255, 255, pulse),
      );
    }
    if (game.showSymbols) {
      // Sit it toward the tail so it does not hide the direction arrow.
      final long = bus.dir.isHorizontal ? roof.width : roof.height;
      final back = Offset(-bus.dir.dCol.toDouble(), -bus.dir.dRow.toDouble());
      paintSymbol(
        canvas,
        roof.center + back * (long * 0.3),
        roof.shortestSide * 0.36,
        symbolFor(bus.colorIndex),
      );
    }
  }
}
