/// Draw order of everything in the game world, back to front.
abstract final class Layer {
  static const int scene = -10;
  static const int lane = 0;
  static const int departing = 2;
  static const int fullPop = 3;
  static const int queue = 5;
  static const int boarding = 6;
  static const int slotButton = 6;

  /// Jam vehicles start here and add their bottom row.
  static const int jam = 10;
  static const int confetti = 20;

  /// Vehicles in transit start here, each newer one above the last.
  static const int flying = 200;
}
