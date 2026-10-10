import 'dart:ui';

import '../core/core.dart';

/// Vehicle and passenger colors; indexed by [Bus.colorIndex] / passenger color.
const List<Color> busColors = [
  Color(0xFFE5393A), // red
  Color(0xFF2F7DE1), // blue
  Color(0xFF34B85A), // green
  Color(0xFFF5C21B), // yellow
  Color(0xFF8E44C9), // purple
  Color(0xFFF06DAF), // pink
];

/// Body color of a vehicle (and its ordinary passengers) by color index.
/// Police cars are white with blue trim, fire trucks deep red.
Color colorFor(int colorIndex) {
  if (colorIndex == policeColor) return const Color(0xFFF1F4F8);
  if (colorIndex == fireColor) return const Color(0xFFC62828);
  return busColors[colorIndex % busColors.length];
}

/// Menu / screen background.
const Color backgroundColor = Color(0xFF2C3E50);

// Game scene.
const Color pavementColor = Color(0xFFCBD5DE);
const Color lotColor = Color(0xFFB7C3CF);
const Color lotLineColor = Color(0xFFA6B3C0);
const Color roadColor = Color(0xFF69747F);
const Color roadEdgeColor = Color(0xFF4F5963);
const Color bayLineColor = Color(0xFFE9EEF2);
