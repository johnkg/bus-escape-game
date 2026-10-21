import '../core/core.dart';

/// One-line tips for things a player meets for the first time, keyed by a
/// stable id (it is saved once the tip has been shown).
///
/// Returns the tips that apply to [level]; [timed] says whether it runs
/// against a clock.
Map<String, String> firstTimeTipsFor(Level level, {required bool timed}) {
  final colors = {for (final b in level.buses) b.colorIndex};
  return {
    if (timed)
      'timed':
          'Timed level! Clear it before the clock runs out. '
          'Finish with half the time left for bonus coins.',
    if (colors.contains(policeColor))
      'police': 'Police officers only board police cars.',
    if (colors.contains(fireColor))
      'fire': 'Firefighters only board fire trucks.',
    if (colors.contains(ambulanceColor))
      'ambulance': 'Paramedics only board ambulances.',
  };
}
