import 'dart:convert';

import '../core/core.dart';

/// Handmade tutorial levels 1–10, kept as JSON so they are easy to edit.
///
/// `queueRuns` is `[color, count]` pairs. Colors: 0 red, 1 blue, 2 green,
/// 3 yellow, 4 purple, 5 orange. Buses: `row`/`col` is the top-left cell.
class TutorialLevels {
  const TutorialLevels._();

  static final List<Level> all = [
    for (final j in jsonDecode(_json) as List)
      Level.fromJson(j as Map<String, dynamic>),
  ];

  static const String _json = '''
[
  {
    "id": 1, "rows": 4, "cols": 4, "laneSlots": 5,
    "hint": "Tap a bus to send it out.",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 2, "length": 2, "dir": "east"},
      {"id": 1, "color": 1, "row": 1, "col": 0, "length": 2, "dir": "south"}
    ],
    "queueRuns": [[0, 4], [1, 4]]
  },
  {
    "id": 2, "rows": 4, "cols": 4, "laneSlots": 5,
    "hint": "A bus can't leave if something is in front of it. Clear the way first!",
    "buses": [
      {"id": 0, "color": 0, "row": 1, "col": 0, "length": 2, "dir": "east"},
      {"id": 1, "color": 1, "row": 0, "col": 2, "length": 2, "dir": "south"}
    ],
    "queueRuns": [[1, 4], [0, 4]]
  },
  {
    "id": 3, "rows": 4, "cols": 5, "laneSlots": 5,
    "hint": "Passengers board the bus of their color. A full bus leaves.",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 0, "length": 3, "dir": "east"},
      {"id": 1, "color": 1, "row": 1, "col": 2, "length": 3, "dir": "east"},
      {"id": 2, "color": 2, "row": 2, "col": 0, "length": 2, "dir": "south"}
    ],
    "queueRuns": [[0, 6], [1, 6], [2, 4]]
  },
  {
    "id": 4, "rows": 4, "cols": 5, "laneSlots": 3,
    "hint": "The lane only holds 3 buses. Send the color the first passenger needs!",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 3, "length": 2, "dir": "east"},
      {"id": 1, "color": 1, "row": 1, "col": 3, "length": 2, "dir": "east"},
      {"id": 2, "color": 2, "row": 2, "col": 3, "length": 2, "dir": "east"},
      {"id": 3, "color": 3, "row": 3, "col": 3, "length": 2, "dir": "east"}
    ],
    "queueRuns": [[0, 4], [1, 4], [2, 4], [3, 4]]
  },
  {
    "id": 5, "rows": 5, "cols": 4, "laneSlots": 3,
    "hint": "Made a mistake? Undo takes back your last move.",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 2, "length": 2, "dir": "east"},
      {"id": 1, "color": 1, "row": 0, "col": 0, "length": 2, "dir": "south"},
      {"id": 2, "color": 2, "row": 2, "col": 2, "length": 2, "dir": "east"},
      {"id": 3, "color": 3, "row": 3, "col": 1, "length": 2, "dir": "north"},
      {"id": 4, "color": 4, "row": 4, "col": 2, "length": 2, "dir": "west"}
    ],
    "queueRuns": [[4, 4], [3, 4], [0, 4], [1, 4], [2, 4]]
  },
  {
    "id": 6, "rows": 5, "cols": 5, "laneSlots": 2,
    "hint": "Lane full? + Slot adds one more spot.",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 4, "length": 2, "dir": "south"},
      {"id": 1, "color": 1, "row": 2, "col": 2, "length": 2, "dir": "east"},
      {"id": 2, "color": 2, "row": 3, "col": 3, "length": 2, "dir": "east"},
      {"id": 3, "color": 3, "row": 4, "col": 1, "length": 2, "dir": "west"}
    ],
    "queueRuns": [[0, 4], [2, 4], [1, 4], [3, 4]]
  },
  {
    "id": 7, "rows": 6, "cols": 5, "laneSlots": 4,
    "hint": "Blockers can be chained. Work out which bus has to go first.",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 0, "length": 3, "dir": "east"},
      {"id": 1, "color": 1, "row": 0, "col": 3, "length": 2, "dir": "south"},
      {"id": 2, "color": 2, "row": 3, "col": 2, "length": 3, "dir": "east"},
      {"id": 3, "color": 3, "row": 4, "col": 0, "length": 2, "dir": "north"},
      {"id": 4, "color": 4, "row": 5, "col": 3, "length": 2, "dir": "east"}
    ],
    "queueRuns": [[2, 6], [1, 4], [4, 4], [0, 6], [3, 4]]
  },
  {
    "id": 8, "rows": 6, "cols": 5, "laneSlots": 4,
    "hint": "Plan ahead. Some buses are stuck behind others.",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 0, "length": 2, "dir": "east"},
      {"id": 1, "color": 1, "row": 0, "col": 3, "length": 3, "dir": "south"},
      {"id": 2, "color": 2, "row": 3, "col": 2, "length": 2, "dir": "east"},
      {"id": 3, "color": 3, "row": 3, "col": 4, "length": 2, "dir": "south"},
      {"id": 4, "color": 4, "row": 5, "col": 2, "length": 3, "dir": "west"},
      {"id": 5, "color": 5, "row": 4, "col": 0, "length": 2, "dir": "east"}
    ],
    "queueRuns": [[3, 4], [4, 6], [2, 4], [0, 4], [1, 6], [5, 4]]
  },
  {
    "id": 9, "rows": 6, "cols": 6, "laneSlots": 4,
    "hint": "Two buses share a color. Passengers fill the leftmost one first.",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 0, "length": 3, "dir": "east"},
      {"id": 1, "color": 1, "row": 0, "col": 4, "length": 3, "dir": "south"},
      {"id": 2, "color": 0, "row": 3, "col": 3, "length": 2, "dir": "west"},
      {"id": 3, "color": 2, "row": 3, "col": 1, "length": 3, "dir": "south"},
      {"id": 4, "color": 3, "row": 4, "col": 2, "length": 3, "dir": "east"},
      {"id": 5, "color": 1, "row": 4, "col": 5, "length": 2, "dir": "north"},
      {"id": 6, "color": 2, "row": 1, "col": 0, "length": 2, "dir": "west"}
    ],
    "queueRuns": [[2, 6], [0, 4], [3, 6], [1, 4], [0, 6], [2, 4], [1, 6]]
  },
  {
    "id": 10, "rows": 6, "cols": 6, "laneSlots": 3,
    "hint": "Final test: only 3 lane spots. Think before you tap!",
    "buses": [
      {"id": 0, "color": 0, "row": 0, "col": 0, "length": 3, "dir": "east"},
      {"id": 1, "color": 1, "row": 0, "col": 4, "length": 3, "dir": "south"},
      {"id": 2, "color": 0, "row": 3, "col": 3, "length": 2, "dir": "west"},
      {"id": 3, "color": 2, "row": 3, "col": 1, "length": 3, "dir": "south"},
      {"id": 4, "color": 3, "row": 4, "col": 2, "length": 3, "dir": "east"},
      {"id": 5, "color": 1, "row": 4, "col": 5, "length": 2, "dir": "north"},
      {"id": 6, "color": 2, "row": 1, "col": 0, "length": 2, "dir": "west"}
    ],
    "queueRuns": [[2, 4], [1, 4], [3, 6], [2, 6], [0, 4], [1, 6], [0, 6]]
  }
]
''';
}
