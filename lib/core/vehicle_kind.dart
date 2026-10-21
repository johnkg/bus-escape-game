/// Passenger / vehicle colors 0..5 are ordinary; these three are services.
/// A passenger boards a vehicle of the same color index, so police only
/// ever board police cars, firefighters only fire trucks and paramedics
/// only ambulances.
const int policeColor = 10;
const int fireColor = 11;
const int ambulanceColor = 12;

/// How many ordinary passenger / vehicle colors there are (0 until this).
const int ordinaryColorCount = 6;

bool isServiceColor(int colorIndex) => colorIndex >= policeColor;

/// The only vehicles in the game, told apart by length and color.
///
/// - sedan: 2 cells, 4 seats
/// - coaster (small bus): 3 cells, 6 seats
/// - bus: 5 cells, 10 seats
/// - police car: a sedan for police passengers
/// - fire truck: a coaster-sized truck for firefighters
/// - ambulance: a sedan-sized van for paramedics
enum VehicleKind {
  sedan,
  coaster,
  bus,
  policeCar,
  fireTruck,
  ambulance;

  /// Lengths in cells; seats are length times [Bus.seatsPerCell].
  static const int sedanLength = 2;
  static const int coasterLength = 3;
  static const int busLength = 5;

  static VehicleKind of({required int length, required int colorIndex}) {
    if (colorIndex == policeColor) return VehicleKind.policeCar;
    if (colorIndex == fireColor) return VehicleKind.fireTruck;
    if (colorIndex == ambulanceColor) return VehicleKind.ambulance;
    if (length <= sedanLength) return VehicleKind.sedan;
    if (length == coasterLength) return VehicleKind.coaster;
    return VehicleKind.bus;
  }
}
