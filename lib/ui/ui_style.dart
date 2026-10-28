import 'package:flutter/material.dart';

import '../game/palette.dart' as palette;

/// Colors of the Flutter UI (menus, HUD, dialogs). Game-world colors live
/// in `game/palette.dart`.
abstract final class AppColors {
  static const Color background = palette.backgroundColor;

  /// Menu backdrop gradient, top to bottom.
  static const Color backdropTop = Color(0xFF3B5874);
  static const Color backdropBottom = Color(0xFF1E2B38);

  static const Color accent = Color(0xFFF39C12); // orange: main actions
  static const Color secondary = Color(0xFF3498DB); // blue
  static const Color go = Color(0xFF2E9E4F); // green buttons
  static const Color goDark = Color(0xFF2E7D32);
  static const Color muted = Color(0xFF7F8C8D); // grey buttons
  static const Color frame = Color(0xFFF3D452); // yellow button rims
  static const Color panel = Color(0xFF3F566D);
  static const Color card = Color(0xFF34495E);

  /// Light rim around clay cards and panels.
  static const Color cardRim = Color(0xFF5C7A96);
  static const Color ink = Color(0xFF1F2D3A); // text outlines
  static const Color gold = palette.gold;
  static const Color star = Color(0xFFF1C40F);
  static const Color warning = palette.crossRed;

  /// Destructive actions (reset progress); readable on [card].
  static const Color danger = Color(0xFFFF8A80);
  static const Color queueSign = Color(0xFF2F7DE1);

  /// Secondary text on dark surfaces (meets 4.5:1 on [card]).
  static const Color textMuted = Color(0xFFC9D6E2);

  /// Drop shadow under clay surfaces.
  static const Color shadow = Color(0x59000000);

  /// Soft drop shadow under button labels.
  static const Color labelShadow = Color(0x80000000);

  /// Backdrop behind dialogs.
  static const Color scrim = Color(0xA6000000);
}

/// Font families bundled in `assets/fonts` (SIL Open Font License).
abstract final class Fonts {
  /// Rounded display face for titles, buttons and numbers.
  static const String display = 'Fredoka';

  /// Rounded body face for everything else.
  static const String body = 'Nunito';
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
  static const double hero = 44;
}

/// The chunky "clay" look: a raised face sitting on a darker lip that it
/// sinks into when pressed.
abstract final class Clay {
  /// Height of the lip under a button face.
  static const double lip = 5;

  /// Thinner lip for small buttons.
  static const double smallLip = 3;

  /// Rim drawn around faces and cards.
  static const double rim = 3;

  /// Lip color: the face darkened by this much HSL lightness.
  static const double lipShade = palette.clayLipShade;

  /// Top of the face gradient: the face lightened by this much.
  static const double highlightShade = 0.07;

  /// Rim color: the face lightened by this much.
  static const double rimShade = palette.clayRimShade;

  /// Blur and offset of the soft drop shadow.
  static const double shadowBlur = 10;
  static const double shadowDrop = 4;

  /// Press feedback: sinking is quick, springing back slower.
  static const Duration pressIn = Duration(milliseconds: 70);
  static const Duration pressOut = Duration(milliseconds: 180);

  /// Dialog cards pop in with this scale and duration.
  static const double popFrom = 0.85;
  static const Duration popIn = Duration(milliseconds: 260);
}

/// Shadow behind white text drawn over the game.
const List<Shadow> textOverGame = [
  Shadow(blurRadius: _textShadowBlur, color: Colors.black87),
];
const double _textShadowBlur = 3;

/// Small drop shadow under white labels on colored clay buttons.
const List<Shadow> labelShadows = [
  Shadow(offset: Offset(0, _labelDrop), color: AppColors.labelShadow),
];
const double _labelDrop = 2;

/// Rim of the green game buttons.
const BorderSide buttonRim = BorderSide(color: AppColors.frame, width: 2);

/// Opacity of a button that cannot be used right now.
const double disabledOpacity = 0.4;

/// Menu screens stay phone-width on tablets and the web.
const double maxScreenWidth = 480;

/// Minimum touch target for icon buttons.
const double minTouchTarget = 48;
