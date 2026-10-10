import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flutter/painting.dart';

import 'layout.dart';
import 'palette.dart';

/// Win celebration: two party poppers from the bottom corners and a shower
/// from the top. Purely cosmetic, so it uses a plain [Random].
List<Component> buildConfetti(Random rng) {
  return [
    _burst(
      rng,
      origin: Vector2(16, GameLayout.height - 140),
      dx: (50, 260),
      dy: (-760, -420),
      count: 45,
    ),
    _burst(
      rng,
      origin: Vector2(GameLayout.width - 16, GameLayout.height - 140),
      dx: (-260, -50),
      dy: (-760, -420),
      count: 45,
    ),
    _burst(
      rng,
      origin: Vector2(GameLayout.width / 2, 40),
      dx: (-220, 220),
      dy: (-60, 120),
      count: 50,
    ),
  ];
}

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
    priority: 20,
    particle: Particle.generate(
      count: count,
      lifespan: 2.2,
      generator: (i) {
        final color = busColors[rng.nextInt(busColors.length)];
        final spin = rng.nextDouble() * 12 - 6;
        final w = 6 + rng.nextDouble() * 6;
        final h = 4 + rng.nextDouble() * 5;
        return AcceleratedParticle(
          speed: Vector2(between(dx), between(dy)),
          acceleration: Vector2(0, 520),
          child: ComputedParticle(
            renderer: (canvas, particle) {
              canvas.rotate(spin * particle.progress);
              final fade = particle.progress < 0.7
                  ? 1.0
                  : (1 - particle.progress) / 0.3;
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
