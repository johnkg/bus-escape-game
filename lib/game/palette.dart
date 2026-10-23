import 'dart:ui';

import 'package:flutter/painting.dart' show HSLColor;

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

// Service vehicle bodies.
const Color policeBodyColor = Color(0xFFF1F4F8);
const Color fireBodyColor = Color(0xFFC62828);
const Color ambulanceBodyColor = Color(0xFFD6F2E3);

/// Body color of a vehicle (and its ordinary passengers) by color index.
/// Police cars are white with blue trim, fire trucks deep red and
/// ambulances pale green-white with a red cross.
Color colorFor(int colorIndex) {
  if (colorIndex == policeColor) return policeBodyColor;
  if (colorIndex == fireColor) return fireBodyColor;
  if (colorIndex == ambulanceColor) return ambulanceBodyColor;
  return busColors[colorIndex % busColors.length];
}

/// [c] made lighter (positive [delta]) or darker, in HSL lightness.
Color shade(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
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

// Depot building.
const Color buildingWallColor = Color(0xFFF3F6F9);
const Color buildingRoofColor = Color(0xFF5D6D80);
const Color buildingWindowColor = Color(0xFF8DB4D8);
const Color buildingSignColor = Color(0xFFD9444A);
const Color buildingDoorColor = Color(0xFF55698C);
const Color buildingAwningColor = Color(0xFF3F4E6E);

// Neutrals and shadows.
const Color white = Color(0xFFFFFFFF);
const Color softShadow = Color(0x22000000);
const Color shadowColor = Color(0x33000000);
const Color outlineShadow = Color(0x55000000);
const Color symbolOutline = Color(0xAA000000);
const Color textShadow = Color(0xCC000000);

// Vehicle parts shared by the jam and the lane.
const Color glassColor = Color(0xE63A526B);
const Color sideWindowColor = Color(0xFFCFE6F7);
const Color tyreColor = Color(0xFF2A2F36);
const Color steelColor = Color(0xFF9AA4AE);
const Color ladderRailColor = Color(0xFFCFD6DD);
const Color headlightColor = Color(0xFFFFF3B0);
const Color seatColor = Color(0xFFD9B27C);
const Color cabinFloorColor = Color(0xFFF6EBD0);

// Service liveries and uniforms.
const Color policeBlue = Color(0xFF2B4C9B);
const Color policeCapColor = Color(0xFF1B2F66);
const Color beaconRed = Color(0xFFFF4A4A);
const Color beaconBlue = Color(0xFF4AA3FF);
const Color crossRed = Color(0xFFD13B3B);
const Color hiVisYellow = Color(0xFFFFD23F);
const Color paramedicTeal = Color(0xFF1F9E8F);
const Color firefighterCoat = Color(0xFF3A3F47);
const Color skinColor = Color(0xFFF1C9A0);

// Lane badges and buttons.
const Color unlockGreen = Color(0xFF3DBE5B);
const Color badgeTextColor = Color(0xFF1B2733);

/// Confetti and coin gold.
const Color gold = Color(0xFFF5C21B);
