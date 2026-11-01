# Bus Escape: Codebase Guide

What every file does, how the app works from the first tap to the win screen,
and how to keep it healthy. Written against `main` at commit `74f0e8f`.

If something here disagrees with the code, the code wins. Please fix this
guide in the same change that makes it wrong.

- [1. The game in one minute](#1-the-game-in-one-minute)
- [2. The app flow, explained for a 10-year-old](#2-the-app-flow-explained-for-a-10-year-old)
- [3. The big picture](#3-the-big-picture)
- [4. File by file](#4-file-by-file)
- [5. How to maintain it](#5-how-to-maintain-it)
- [6. Glossary](#6-glossary)

---

## 1. The game in one minute

A parking lot is jammed with vehicles, and every vehicle points one way.
You tap a vehicle to send it out. It can only leave if nothing is in its
way. When it leaves, it parks in one of a few spots on a road (the **lane**).

Outside the depot, passengers stand in a line (the **queue**). The first
passenger climbs into a parked vehicle of the **same colour**. When all the
seats in a vehicle are taken, it drives away and frees its spot.

- **You win** when the lot is empty and every passenger has a seat.
- **You lose** when every lane spot is taken and the first passenger has no
  matching vehicle. Timed levels also lose when the clock runs out.

Around that core loop there are extras: five boosters, stars, coins, a daily
challenge with a streak, timed levels, service vehicles (police, fire,
ambulance), colour symbols for colour-blind players, and a stats screen.

---

## 2. The app flow, explained for a 10-year-old

### The story

Imagine a school car park where all the cars are stuck, nose to tail. Each
car can only drive straight ahead. If another car is right in front of it,
it can't move.

At the bottom of the screen there is a short road with a few parking spots.
Up at the top, kids wait in a line outside a building. Every kid wants a car
that is **their** colour: red kids want red cars, blue kids want blue cars.

You are the traffic helper. You tap a car, and if the way is clear, off it
drives to a spot on the road. The kid at the front of the line looks at the
parked cars. If there is a car in their colour with a free seat, they hop in.
When a car is full, it drives away and the spot is free again.

You win when the car park is empty and everybody has a seat. You lose if the
road fills up with cars and the kid at the front can't find their colour.

### The five jobs inside the app

Think of the app as a small company where each team has one job:

| Team (folder) | Their job | In kid words |
|---|---|---|
| `lib/core/` | Knows the rules | **The brain.** It decides "can this car leave?" It never draws anything. |
| `lib/game/` | Draws and moves things | **The eyes and hands.** It shows cars driving, kids walking, confetti. |
| `lib/ui/` | Menus and buttons | **The control panel.** Menu, settings, buttons, the pause box. |
| `lib/services/` | Remembers and makes noise | **The notebook and the speakers.** Saves your progress, plays sounds. |
| `lib/levels/` | Supplies the puzzles | **The puzzle book.** Ten handmade levels, then endless made-up ones. |

The brain is kept apart from the pictures on purpose. That means we can test
every rule without a screen, and one day the pictures could be swapped
(even for 3D) without touching the rules.

### What happens when you open the app

1. `main.dart` wakes everything up: it locks the phone to portrait, opens the
   saved progress, gets the sounds ready, and starts the app.
2. The **menu** appears (`menu_screen.dart`). It reads your progress to show
   "Play, Level 7", your coins and your daily streak.
3. You press **Play**. `game_screen.dart` asks the puzzle book
   (`level_repository.dart`) for level 7 and creates the game
   (`bus_escape_game.dart`).
4. The game draws the depot, the road, the queue and the jam, and waits.

### What happens when you tap one car

1. The car (`bus_component.dart`) feels the tap and tells the game: "car 4
   was tapped."
2. The game asks the session (`session.dart`): "can car 4 leave?"
3. The session asks the rulebook (`rules.dart`): is every square in front of
   the car empty?
   - **No:** the car wobbles, a "blocked" sound plays, and you lose a star
     (the game notes a mistake).
   - **Yes:** the rulebook builds a **new** picture of the world (a
     `GameState`) where the car is gone from the lot and parked on the road.
     It never edits the old one, so Undo is just "go back to the previous
     picture".
4. The rulebook also moves kids: the first kid boards a matching parked car,
   then the next, until someone can't board. Full cars leave. Then it asks
   "have we won or lost yet?" (`Rules.evaluate`).
5. The game compares the picture before and after (`lane_delta.dart`,
   `tap_events.dart`) to work out what to **show**: the car drives along its
   route, kids walk over one by one (`boarding_passenger.dart`), a full car
   slides away with a "FULL!" pop (`departing_bus.dart`, `full_pop.dart`),
   and sounds and buzzes play (`feedback_service.dart`).
6. After the last animation, if you won or lost, `game_screen.dart` shows the
   result card (`result_overlay.dart`). A win is saved through
   `progress_service.dart`: next level unlocked, stars and coins recorded.

The important idea: **the rules decide first, instantly; the pictures catch
up afterwards.** The animations are only a replay of a decision that was
already made.

### Where the "made-up" levels come from

From level 11 on, a level is made by a recipe (`level_generator.dart`):

1. Cut out a parking-lot shape (often not a plain rectangle).
2. Place cars one at a time, **in the order they will leave, but backwards**,
   so every car always has a way out once the ones before it are gone.
3. Make the line of kids by actually playing that exit order against the
   real rules, so the puzzle is winnable by construction.

The recipe uses its own tiny dice (`rng.dart`), so level 37 is the **same
level for every player on every phone**.

---

## 3. The big picture

```
                 ┌──────────────────────────────────────────────┐
                 │  lib/main.dart  (starts the app, wires it up) │
                 └───────────────┬──────────────────────────────┘
                                 │
        ┌────────────────────────┼─────────────────────────┐
        ▼                        ▼                         ▼
  lib/ui/  (Flutter)      lib/game/  (Flame)         lib/services/
  screens, HUD,           draws + animates           progress (saved),
  dialogs, theme          the board                  sound, haptics
        │                        │                         ▲
        └──────────┬─────────────┘                         │
                   ▼                                       │
             lib/core/  (pure Dart rules)  ◄── lib/levels/ ┘
             no Flutter, no Flame imports      (tutorial JSON + generator)
```

Dependency rules (keep these true):

- `core/` imports nothing from Flutter or Flame.
- `game/` imports `core/`, and a little of `services/` (sound events, the
  unlock price). It never imports `ui/`.
- `ui/` imports `core/`, `game/`, `services/` and `levels/`.
- `services/` imports `core/` only for shared names and constants.
- Screens reach shared objects through "scopes" (`ProgressScope`,
  `FeedbackScope`), not globals.

**Two coordinate worlds.** The board is drawn in a fixed 390 x 844 "design
space" (`game/layout.dart`) that is scaled to the real screen. The Flutter
overlay (HUD, boosters, dialogs) is laid out in the same 390 x 844 space and
scaled with it, so they always line up.

---

## 4. File by file

Format: **what it does** (and, where it isn't obvious, **why it exists**).

### Project root

| File | What it does |
|---|---|
| `pubspec.yaml` | The app's shopping list: name, Flutter/Dart versions, packages (`flame`, `flame_audio`, `shared_preferences`), and bundled assets (audio and fonts). |
| `pubspec.lock` | The exact package versions that were tested. Commit changes to it. |
| `analysis_options.yaml` | Lint rules (`flutter_lints`). CI treats **info-level** lints as failures. Build output and platform folders are excluded. |
| `README.md` | Front door: what the game is, how to run, test, build, and deploy. |
| `CLAUDE.md` | Instructions for the AI assistant working in this repo (reply style). Not part of the app. |
| `docs/CODEBASE_GUIDE.md` | This file. |
| `docs/PLAN.md` | The original plan and milestones. Kept for history; parts are out of date (for example it says "no timer"). |
| `docs/PROMPT.md` | The original build prompt. Kept for history. |
| `.github/workflows/deploy-web.yml` | CI: on every push it runs `flutter analyze`, `flutter test`, builds the web app, and deploys to Cloudflare Pages. `main` is the live site; other branches get a preview URL. |
| `tools/generate_audio.py` | Writes the sound effects and music into `assets/audio/` using plain maths (sine, triangle, square, noise). |
| `web/` | The web page shell (`index.html`, `manifest.json`, icons) that hosts the Flutter app in a browser. |
| `android/`, `ios/`, `linux/`, `macos/`, `windows/` | Generated platform wrappers. Rarely edited by hand. The app id is `com.jkg.busescape`. |
| `assets/audio/` | One short `.wav` per game event, plus `music.wav`. |
| `assets/fonts/` | Fredoka (headings) and Nunito (body), cut down to Latin letters, plus their licence files. |
| `assets/CREDITS.md` | Where the audio and fonts came from. Update it whenever you add an asset. |

### `lib/main.dart`

Starts the app. Locks portrait orientation, loads `ProgressService`, preloads
sounds, builds the `FeedbackService`, then runs `BusEscapeApp`, which wraps
the app in `ProgressScope` and `FeedbackScope`, applies `buildAppTheme()` and
shows `MenuScreen`.

### `lib/core/`: the brain (pure Dart)

Everything here is plain logic with no drawing, so it is quick to test.

| File | What it does |
|---|---|
| `core.dart` | A "table of contents" that re-exports the files below, so other code can write one import. |
| `direction.dart` | `Direction` (north, south, east, west) with the row/column step for each and `isHorizontal`. Row 0 is the top. |
| `bus.dart` | `Bus`: one vehicle in the lot (id, colour, top-left cell, length, direction). Knows its `capacity` (2 seats per cell), the `cells` it covers, its `front`, and `pathCells`, the squares between its nose and the edge. `copyWith` makes a moved copy. Also JSON in/out for handmade levels. |
| `vehicle_kind.dart` | Vehicle names and sizes: sedan (2 cells, 4 seats), coaster (3 cells, 6 seats), bus (5 cells, 10 seats), plus police car, fire truck and ambulance. Colours 0-5 are ordinary; **10, 11, 12** are police, fire, ambulance, and their passengers only board their own vehicle. |
| `game_state.dart` | `GameState`: an immutable snapshot of the whole game (vehicles in the lot, the lane, the queue, moves, win/lose status). `ParkedBus` is a vehicle in the lane with its boarded count. Every rule returns a *new* `GameState`. `key` is a short fingerprint the solver uses to spot repeats. |
| `level.dart` | `Level`: the fixed description of a puzzle (grid size, vehicles, queue, lane slots, teaching hint, optional lot outline, known solution). `toState()` makes the starting `GameState`. `lotHasCell` answers "is this square part of the lot?" |
| `rules.dart` | The rulebook. `canExit`, `tap` (drive out + board), `airlift` (the Clear booster ignores blockers), `sortQueue`/`sortedQueue` (the Sort booster), `board` (kids board the leftmost matching vehicle), and `evaluate` (won, lost, still playing). No side effects, no randomness. |
| `session.dart` | `GameSession`: wraps the immutable states with a history stack for **Undo**, extra lane slots (max 3), booster actions, and the **star** counting (mistakes and help used). |
| `solver.dart` | Depth-first search that finds a winning tap order, remembering dead ends. Used by tests, hints and Refresh. Has a node budget so it never runs forever. |
| `hint.dart` | `Hints.nextBus`: which vehicle to glow. Searches for a winning line, falls back to the level's known solution, then to "something the front passenger wants". |
| `refresher.dart` | The **Refresh** booster: finds a winning order for the current board, then re-places the vehicles still in the lot so that order still works. |
| `placement.dart` | `placeRandomly`: tries random spots until a vehicle fits (on the lot, not overlapping, with a clear way out). Shared by the generator and Refresh. |
| `level_generator.dart` | Makes levels from the level number: `configFor` is the difficulty curve (size, vehicle count, colours, lane slots, service vehicles), then it carves the lot, places vehicles in reverse exit order, and builds the queue by playing the exit order. Deterministic. |
| `rng.dart` | A tiny seeded random generator (xorshift32). Written by hand so levels come out identical on every platform, including the web. |
| `daily.dart` | `dayNumber(date)`: whole days since 1 Jan 2024. Everyone on the same date gets the same daily challenge, and the streak counts in these days. |

### `lib/game/`: the eyes and hands (Flame)

Draws the board and plays animations. All rules stay in `core/`.

**The controller**

| File | What it does |
|---|---|
| `bus_escape_game.dart` | `BusEscapeGame`, the one Flame game object. Owns the `GameSession`; turns a tap into animations; keeps track of which vehicle is in which bay and which passengers are mid-walk; schedules effects in order; exposes `canUndo`, `canHint`, `canRefresh`, `canClear`, `canSort`; runs the level timer; tells the Flutter screen about changes through `stateNotifier`. The biggest file, and the one to read first. |
| `layout.dart` | `GameLayout`: all the positions in the 390 x 844 design space (queue path, road, lane bays, jam grid, booster row). Change positions here, not in the components. |
| `layers.dart` | The draw order of everything (`Layer.scene` at the back, `Layer.flying` at the front). |

**Things on the board**

| File | What it does |
|---|---|
| `scene_view.dart` | The ground, the clay depot building (roof, windows, door, awning, bus-stop sign) and the parking-lot tiles. |
| `lane_view.dart` | The road and its dashed bays; draws parked vehicles, seats-left badges, locked "+ 100" bays and the little hop when a passenger lands. |
| `queue_view.dart` | The line of waiting passengers; they glide forward to close a gap when someone leaves. |
| `bus_component.dart` | One vehicle in the jam. Handles taps, the shake when blocked, the hint glow, and the drive from the lot, along the road, into its bay (or the helicopter lift for Clear). |
| `locked_slot_button.dart` | An invisible tap target over a locked bay; asks the screen to sell you the slot. |
| `boarding_passenger.dart` | One passenger walking (with a hop) from the queue to a seat. |
| `departing_bus.dart` | A full vehicle sliding up and fading out of its bay. |
| `full_pop.dart` | The "FULL!" text that floats up when a vehicle leaves. |
| `confetti.dart` | The win celebration: two party poppers and a shower from the top. |
| `timed_effect.dart` | Small base class for short effects: counts time, exposes `progress` (0 to 1), removes itself when done. |

**Working out what to show**

| File | What it does |
|---|---|
| `lane_delta.dart` | Compares the lane before and after a move to list which passenger boards which vehicle, in order. The animations replay this list. |
| `tap_events.dart` | Works out which sound/haptic events a move should trigger (exit, board, depart, win, lose). |
| `level_timer.dart` | The countdown for timed levels. Pausing the game pauses it. |

**Painting (pure drawing code)**

| File | What it does |
|---|---|
| `palette.dart` | Every game colour in one place, plus `colorFor(index)` and `shade()` to lighten or darken a colour. |
| `paint_helpers.dart` | Small shared drawing helpers: rounded fills, the ground shadow under vehicles, fade layers. |
| `vehicle_painter.dart` | Draws a vehicle seen in the jam, with fake depth (shadow, side panel, roof, windows, wheels, direction arrow). Each vehicle kind has a style entry in one table. |
| `parked_vehicle_painter.dart` | Draws a vehicle parked in the lane, seen from above with its seats showing, boarded passengers, the seats-left badge and service badges. Also says where each seat is. |
| `passenger_painter.dart` | Draws a little person; police, paramedics and firefighters get their own hats and stripes. |
| `symbols.dart` | The shapes (circle, square, triangle, ...) for the colour-blind "Color symbols" setting, one per colour. |

### `lib/levels/`: the puzzle book

| File | What it does |
|---|---|
| `level_repository.dart` | The one place to ask "give me level N" (`levelFor`) or "today's challenge" (`dailyLevel`). Levels 1-10 are handmade, later ones are generated and start easy again. Also decides which levels are **timed** (every fifth level after the tutorial: 13, 18, 23, ...) and how long the clock is (20 s plus 6 s per vehicle). |
| `tutorial_levels.dart` | The ten handmade levels as readable JSON (`queueRuns` is `[colour, count]` pairs), each with a teaching hint. |

### `lib/services/`: the notebook and the speakers

| File | What it does |
|---|---|
| `progress_service.dart` | Everything saved on the phone (via `shared_preferences`): unlocked level, stars, boosters, coins, daily streak, first-time tips seen, and the four settings. Also holds the money rules (win coins, daily coins, slot price) and the booster-gift rules. It is a `ChangeNotifier`, so screens refresh when it changes. |
| `feedback_service.dart` | Plays a sound and a buzz for each `GameEvent`, respecting the sound, music and haptics settings. The real players (`FlameSoundPlayer`, `SystemHapticsPlayer`) swallow errors, because sound must never crash the game. Silent versions exist for tests. |

### `lib/ui/`: the control panel (Flutter)

| File | What it does |
|---|---|
| `ui_style.dart` | The design tokens: colours (`AppColors`), spacing (`Gap`), corner radii, font sizes, fonts and the clay measurements (`Clay`). Change the look here first. |
| `app_theme.dart` | The Material theme (dark clay surfaces, rounded fonts, dialog and switch styles). |
| `widgets.dart` | The shared building blocks: `ScreenFrame`, `ClayButton` (a chunky button that sinks when pressed), `BigButton`, `ClayIconButton`, `ClayCard`, `DialogCard`, `BoosterTile`, `StarRow`, `InfoChip`, `OutlinedText`, and `pushScreen`. |
| `menu_screen.dart` | The home screen. Long-pressing the title opens the hidden "practice a level" box (progress is not saved). |
| `level_select_screen.dart` | The grid of levels with stars, locks and a clock icon for timed levels. |
| `settings_screen.dart` | Sound, music, haptics, colour symbols, a link to Stats, and Reset progress (with a confirm). |
| `stats_screen.dart` | A grid of lifetime numbers (levels cleared, stars, streaks, coins). |
| `game_screen.dart` | The screen that hosts the Flame game and puts the HUD, booster bar and dialogs on top. Spends boosters, records wins, decides when to show the result, and handles pause, retry and next level. Handles three kinds of play: numbered level, daily challenge, practice. |
| `game_hud.dart` | Top of the game: coin chip, level title, move count, clock, pause button; plus the "N LEFT" sign and the pause menu. |
| `game_overlays.dart` | The booster bar along the bottom (with the "tap a vehicle" banner while Clear is armed) and the teaching/tip banner. |
| `result_overlay.dart` | The win/lose card: stars, coins, bonuses, and Next / Replay / Retry / Menu (plus Undo or Unlock slot to rescue a lost run). |
| `first_time_tips.dart` | One-line tips for things met for the first time (timed level, police, fire, ambulance). Each shows once, ever. |
| `progress_scope.dart` | Hands `ProgressService` to any screen and rebuilds it when progress changes. |
| `feedback_scope.dart` | Hands `FeedbackService` to any screen. |

### `test/`

| File | What it checks |
|---|---|
| `core/rules_test.dart` | Exits, blocked taps, boarding order, departures, win/lose, undo. |
| `core/boosters_test.dart` | Clear, Sort and Refresh, including that Refresh keeps levels winnable. |
| `core/stars_test.dart` | The star rules. |
| `core/hint_test.dart` | Following hints wins levels 1-40 and recovers from mistakes. |
| `core/generator_test.dart` | The random numbers, the solver, and generated levels (deterministic, on the lot, no overlaps, solvable, service vehicles behave). |
| `core/stress_test.dart` | Generates and wins levels 1-300 and reports the slowest. |
| `game/lane_delta_test.dart` | Boarding order for exits, fills, departures and Sort. |
| `game/level_timer_test.dart` | The countdown. |
| `game/symbols_test.dart` | Every colour has its own shape and every shape paints. |
| `levels/tutorial_levels_test.dart` | Tutorials are valid and solvable; levels 1-80 are winnable and deterministic; timed and daily levels. |
| `services/progress_service_test.dart` | Saving, loading, resets, coins, rewards, streaks. |
| `services/feedback_service_test.dart` | Sound and haptics follow the settings. |
| `widget_test.dart` | Whole-screen flows: menu to game, pause, boosters, result dialogs, settings, stats, tips. |

---

## 5. How to maintain it

### Daily routine

Before every push (CI runs the same three steps, and **fails on info-level
lints**):

```bash
dart format lib test
flutter analyze
flutter test
```

Every push to any branch builds and deploys a preview; `main` is the live
site (bus-escape-b8m.pages.dev). Open a pull request when you want something
reviewed or merged.

### House rules

1. **Rules go in `lib/core/`.** If it decides what is allowed or what the
   score is, it belongs there with a unit test. If it only draws or animates,
   it belongs in `game/`.
2. **No magic numbers.** Give every number a named constant with a short
   comment saying what it means. UI sizes go in `ui_style.dart`; game colours
   go in `palette.dart`; positions go in `layout.dart`.
3. **No duplicate code.** If you copy a block, share it instead. Examples
   already in place: `placeRandomly`, `ClayButton`, `InfoChip`, `TimedEffect`.
4. **Descriptive names.** `_bayOccupant`, not `_occ`. Booleans read as
   questions (`canUndo`, `isFull`).
5. **Don't build features nobody uses yet.** (The unused ads/purchases
   scaffold was deleted for this reason.)
6. **Keep screens thin.** Screens call services and the game; they don't
   contain rules.

### Things that must not change by accident

| Danger | Why | How to stay safe |
|---|---|---|
| **Saved-data keys** in `progress_service.dart` (`unlocked`, `stars_N`, `booster_*`, `coins`, `daily_*`, `tip_*`, settings) | Renaming one wipes that data for every player. | Never rename. If you must, write a migration. |
| **The order of random draws** in `level_generator.dart`, `placement.dart`, `refresher.dart` | Changing it changes every generated level, so a player's "level 40" is different, and the daily challenge stops matching between players. | If you touch these files, compare before and after: write a throwaway test that prints the JSON of levels 1-300, some daily levels and some Refresh results, run it on the old and new code, and diff the output. The refactor on 31 Oct 2026 used exactly this and the output was identical. |
| **Difficulty numbers** in `LevelGenerator` (`_fillBase`, `_growEvery`, ...) | Same as above: they are tuning, not rules. | Change on purpose, then re-run the stress test. |
| **Colour numbers**: 0-5 ordinary, 10/11/12 services | They are stored in levels and used to match passengers. | Add new colours at the end, keep service colours at 10+. |
| **Tutorial level ids 1-10** | The repository serves them by position. | Keep ten, in order. |
| **Bundled fonts** | They are licensed under the SIL Open Font License. | Keep the `*-OFL.txt` files next to them. |

### "I want to..." cheat sheet

| I want to... | Edit |
|---|---|
| Change a colour or spacing in menus | `lib/ui/ui_style.dart` |
| Change how a button looks everywhere | `ClayButton` in `lib/ui/widgets.dart` |
| Change a colour on the board | `lib/game/palette.dart` |
| Move something on the board | `lib/game/layout.dart` (then check `scene_view.dart`) |
| Make levels harder or easier | `LevelGenerator.configFor` in `lib/core/level_generator.dart` |
| Edit a tutorial level | `lib/levels/tutorial_levels.dart` (run `flutter test test/levels`) |
| Change which levels are timed, or the clock length | `lib/levels/level_repository.dart` |
| Change how many coins things pay or cost | `lib/services/progress_service.dart` |
| Change a rule (for example how boarding works) | `lib/core/rules.dart` **and its tests** |
| Change the star rules | `GameSession.stars` in `lib/core/session.dart` |
| Change a sound | Replace the file in `assets/audio/` with the same name, or edit and re-run `python3 tools/generate_audio.py` |
| Change how a vehicle looks | `lib/game/vehicle_painter.dart` (jam) and `parked_vehicle_painter.dart` (lane) |
| Change the depot building | `_paintBuilding` in `lib/game/scene_view.dart` |
| Add or change a first-time tip | `lib/ui/first_time_tips.dart` |

### Recipes

**Add a new booster.** Add a value to the `Booster` enum
(`progress_service.dart`). The compiler then points at every `switch` that
needs a case. Add the rule in `core/` (a `Rules` function and a
`GameSession` method), add `canX` and the action in `bus_escape_game.dart`,
then add its icon, enabled check and button action in `game_screen.dart`. The
booster bar is built from `Booster.values`, so the tile appears by itself.
Add tests in `test/core/boosters_test.dart` and `test/widget_test.dart`.

**Add a new vehicle kind.** Add it to `VehicleKind` (and a colour constant if
it has its own passengers) in `vehicle_kind.dart`. Give it a style in
`vehicle_painter.dart` (`_styles`), a size in `parked_vehicle_painter.dart`
(`_bayFill`) and a lane badge (`_laneBadge`). Give it a shape in
`symbols.dart`, a chance in `LevelConfig` and `_randomVehicle`, and a tip in
`first_time_tips.dart`. Adding it to the generator changes generated levels,
so see "Things that must not change by accident".

**Add a setting.** Add a key, getter and setter in `progress_service.dart`
(add the key to `_settingKeys` if it should survive Reset), then add a switch
in `settings_screen.dart`. Read it where needed through `ProgressScope`.

**Add a screen.** Create `lib/ui/your_screen.dart` using `ScreenFrame`, link
to it with `pushScreen(context, const YourScreen())`, and add a widget test.

**Replace the drawn art with image files.** Put the files in `assets/images/`,
register them in `pubspec.yaml`, record the pack name, author and licence in
`assets/CREDITS.md`, and swap the painters (`vehicle_painter.dart`,
`parked_vehicle_painter.dart`, `passenger_painter.dart`) for sprites.

### When something breaks

| Symptom | Likely cause |
|---|---|
| CI fails on `flutter analyze` with an "info" message | The project treats info lints as errors. Fix the lint; don't ignore it. |
| A widget test fails with a yellow/black overflow error | A label is wider than its box. Labels use `FittedBox` to shrink; check the new text. |
| Levels look different from before | Random draw order changed (see the table above). |
| Dialog text appears twice in a test | `OutlinedText` draws its text twice (outline and fill); use `findsWidgets`. |
| Flame test hangs on `pumpAndSettle` | The game ticks forever; use `pump()` instead. |
| Sound doesn't start on the web | Browsers only allow audio after the first tap. This is expected. |
| `flutter` refuses to run as root in a container | It only warns; it still works. |

### Known gaps

- iOS and Android have **not** been built or run on a real phone yet (the code
  is shared and has no platform forks). Check touch targets, audio delay,
  haptics and that progress survives closing the app.
- No ads or in-app purchases yet. They were removed as unused; add them when
  there is a real SDK to plug in.
- All art is drawn in code. No app icon or splash screen yet.
- White text on the orange buttons is below the 4.5:1 contrast guideline.
- Music pausing when the app goes to the background has only been exercised
  on the web.
- The CI "Check Cloudflare credentials" step is a debugging aid
  (`continue-on-error`); it can be removed once deploys are stable.

---

## 6. Glossary

| Word | Meaning |
|---|---|
| **Jam / lot** | The grid of parked vehicles you are trying to empty. |
| **Lane / bay** | The road with parking spots. A *bay* is one spot. |
| **Queue** | The line of waiting passengers. |
| **Vehicle / bus** | Any vehicle. The code calls them all `Bus`, even sedans. |
| **Path** | The squares between a vehicle's nose and the edge of the lot. It can leave if they are all empty. |
| **Airlift** | The Clear booster: a helicopter lifts a vehicle straight into the lane. |
| **Snapshot / `GameState`** | A frozen picture of the whole game. Rules make a new one each time. |
| **Session** | The wrapper that keeps the history of snapshots (for Undo) and counts mistakes. |
| **Booster** | A helper: Undo, Hint, Refresh, Clear, Sort. |
| **Design space** | The fixed 390 x 844 canvas the board is drawn on, scaled to the real screen. |
| **Clay** | The chunky, soft, toy-like look: raised buttons on a darker lip that sink when pressed. |
| **Scope** | A Flutter widget that hands a shared object (progress, feedback) to the screens below it. |
| **Deterministic** | Gives the same result every time from the same input. Why the same level number is the same puzzle for everyone. |
