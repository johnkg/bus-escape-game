import 'package:flutter/material.dart';

import '../game/palette.dart' as palette;

/// Colors of the Flutter UI (menus, HUD, dialogs). Game-world colors live
/// in `game/palette.dart`.
abstract final class AppColors {
  static const Color background = palette.backgroundColor;
  static const Color accent = Color(0xFFF39C12); // orange: main actions
  static const Color secondary = Color(0xFF3498DB); // blue
  static const Color go = Color(0xFF2E9E4F); // green buttons
  static const Color goDark = Color(0xFF2E7D32);
  static const Color muted = Color(0xFF7F8C8D); // grey buttons
  static const Color frame = Color(0xFFF3D452); // yellow button rims
  static const Color panel = Color(0xFF3F566D);
  static const Color card = Color(0xFF34495E);
  static const Color ink = Color(0xFF1F2D3A); // text outlines
  static const Color gold = palette.gold;
  static const Color star = Color(0xFFF1C40F);
  static const Color warning = palette.crossRed;
  static const Color queueSign = Color(0xFF2F7DE1);
}

/// Spacing scale for padding and gaps.
abstract final class Gap {
  static const double xxs = 2;
  static const double xs = 4;
  static const double s = 6;
  static const double m = 8;
  static const double l = 12;
  static const double xl = 16;
  static const double xxl = 20;
  static const double xxxl = 24;
  static const double huge = 48;
}

/// Corner radii.
abstract final class Radii {
  static const double s = 8;
  static const double badge = 10;
  static const double m = 12;
  static const double l = 14;
  static const double xl = 16;
  static const double pill = 18;
  static const double card = 24;
}

/// Font sizes.
abstract final class FontSizes {
  static const double caption = 12;
  static const double small = 13;
  static const double body = 14;
  static const double label = 16;
  static const double button = 20;
  static const double title = 22;
  static const double hud = 24;
  static const double heading = 30;
  static const double hero = 40;
}

/// Shadow behind white text drawn over the game.
const List<Shadow> textOverGame = [
  Shadow(blurRadius: _textShadowBlur, color: Colors.black87),
];
const double _textShadowBlur = 3;

/// Rim of the green game buttons.
const BorderSide buttonRim = BorderSide(color: AppColors.frame, width: 2);

/// Opacity of a button that cannot be used right now.
const double disabledOpacity = 0.4;

/// Menu screens stay phone-width on tablets and the web.
const double maxScreenWidth = 480;
