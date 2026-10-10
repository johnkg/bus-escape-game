/// Passenger / vehicle colors 0..5 are ordinary; these two are services.
/// A passenger boards a vehicle of the same color index, so police only
/// ever board police cars and firefighters only fire trucks.
const int policeColor = 10;
const int fireColor = 11;

bool isServiceColor(int colorIndex) => colorIndex >= policeColor;

/// The only vehicles in the game, told apart by length and color.
///
/// - sedan: 2 cells, 4 seats
/// - coaster (small bus): 3 cells, 6 seats
/// - bus: 5 cells, 10 seats
/// - police car: a sedan for police passengers
/// - fire truck: a coaster-sized truck for firefighters
enum VehicleKind {
  sedan,
  coaster,
  bus,
  policeCar,
  fireTruck;

  static VehicleKind of({required int length, required int colorIndex}) {
    if (colorIndex == policeColor) return VehicleKind.policeCar;
    if (colorIndex == fireColor) return VehicleKind.fireTruck;
    if (length <= 2) return VehicleKind.sedan;
    if (length == 3) return VehicleKind.coaster;
    return VehicleKind.bus;
  }
}
