import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/painting.dart';

import 'layout.dart';
import 'palette.dart';
import 'layers.dart';

/// Win celebration: two party poppers from the bottom corners and a shower
/// from the top. Purely cosmetic, so it uses a plain [Random].
List<Component> buildConfetti(Random rng) {
  return [
    _burst(
      rng,
      origin: Vector2(_popperInset, GameLayout.height - _popperRise),
      dx: (_popperMinDx, _popperMaxDx),
      dy: _popperDy,
      count: _popperCount,
    ),
    _burst(
      rng,
      origin: Vector2(
        GameLayout.width - _popperInset,
        GameLayout.height - _popperRise,
      ),
      dx: (-_popperMaxDx, -_popperMinDx),
      dy: _popperDy,
      count: _popperCount,
    ),
    _burst(
      rng,
      origin: Vector2(GameLayout.width / 2, _showerTop),
      dx: (-_showerSpread, _showerSpread),
      dy: _showerDy,
      count: _showerCount,
    ),
  ];
}

// Party poppers in the bottom corners, firing up and inwards (px, px/s).
const double _popperInset = 16;
const double _popperRise = 140;
const double _popperMinDx = 50;
const double _popperMaxDx = 260;
const (double, double) _popperDy = (-760, -420);
const int _popperCount = 45;

// A shower from the top.
const double _showerTop = 40;
const double _showerSpread = 220;
const (double, double) _showerDy = (-60, 120);
const int _showerCount = 50;

// Each piece of confetti.
const double _lifespan = 2.2;
const double _gravity = 520;
const double _maxSpin = 6; // radians over its life, either way
const double _minWidth = 6;
const double _widthRange = 6;
const double _minHeight = 4;
const double _heightRange = 5;

/// Pieces fade out over the last part of their life.
const double _fadeFrom = 0.7;
const double _fadeLength = 0.3; // 1 - _fadeFrom

Component _burst(
  Random rng, {
  required Vector2 origin,
  required (double, double) dx,
  required (double, double) dy,
  required int count,
}) {
  double between((double, double) r) => r.$1 + rng.nextDouble() * (r.$2 - r.$1);
  return ParticleSystemComponent(
    position: origin,
    priority: Layer.confetti,
    particle: Particle.generate(
      count: count,
      lifespan: _lifespan,
      generator: (i) {
        final color = busColors[rng.nextInt(busColors.length)];
        final spin = between((-_maxSpin, _maxSpin));
        final w = _minWidth + rng.nextDouble() * _widthRange;
        final h = _minHeight + rng.nextDouble() * _heightRange;
        return AcceleratedParticle(
          speed: Vector2(between(dx), between(dy)),
          acceleration: Vector2(0, _gravity),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              canvas.rotate(spin * particle.progress);
              final fade = particle.progress < _fadeFrom
                  ? 1.0
                  : (1 - particle.progress) / _fadeLength;
              canvas.drawRect(
                Rect.fromCenter(center: Offset.zero, width: w, height: h),
                Paint()..color = color.withValues(alpha: fade.clamp(0.0, 1.0)),
              );
            },
          ),
        );
      },
    ),
  );
}
