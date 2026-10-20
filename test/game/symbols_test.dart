import 'dart:ui';

import 'package:bus_escape_game/core/core.dart';
import 'package:bus_escape_game/game/palette.dart';
import 'package:bus_escape_game/game/symbols.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every bus color has its own shape', () {
    final shapes = {for (var i = 0; i < busColors.length; i++) symbolFor(i)};
    expect(shapes.length, busColors.length);
  });

  test('police, fire and ambulance each have a shape no other color uses', () {
    final ordinary = {for (var i = 0; i < busColors.length; i++) symbolFor(i)};
    final services = [
      symbolFor(policeColor),
      symbolFor(fireColor),
      symbolFor(ambulanceColor),
    ];
    expect(services.toSet().length, 3);
    for (final s in services) {
      expect(ordinary, isNot(contains(s)));
    }
  });

  test('shapes wrap around like colors do', () {
    expect(symbolFor(busColors.length), symbolFor(0));
    expect(symbolFor(busColors.length + 2), symbolFor(2));
  });

  test('every shape can be painted', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    for (final s in SymbolShape.values) {
      paintSymbol(canvas, const Offset(20, 20), 12, s);
    }
    final picture = recorder.endRecording();
    expect(picture.approximateBytesUsed, greaterThan(0));
    picture.dispose();
  });
}
