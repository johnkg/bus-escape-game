# Bus Escape

A bus-jam puzzle for phones and the web, built with Flutter and Flame.

A parking lot is jammed with buses. Tap a bus to drive it out. It can only leave if nothing is in front of it, and it parks in a small loading lane. Passengers wait in a queue; the front passenger boards the leftmost parked bus of their color, and a full bus drives away. Clear every bus and board every passenger to win. If the lane is full and the front passenger can't board, you lose. There is no timer.

## Status

- **Web demo:** playable. Release build verified in Chrome (phone-sized and wide windows).
- **Core, levels, UI, boosters, sound, haptics, animations:** done and covered by tests.
- **iOS / Android:** the code is shared and has no platform forks, but it has **not been built or run on a phone or simulator yet**. Xcode and the Android SDK were not set up on the development machine (see [Mobile](#mobile)).
- **Art:** all drawn in code: a depot scene, cars and buses with fake depth, people in the queue, a road lane. No asset files yet; a free pack (e.g. [Kenney](https://kenney.nl), CC0) could replace the shapes later.
- **Ads / in-app purchases:** intentionally not built yet. `AdService` and `PurchaseService` interfaces exist with no-op implementations (`lib/services/monetization.dart`), so a real SDK can be dropped in later.

## Requirements

- Flutter (stable, Dart 3.13 or newer). Check with `flutter doctor`.
- Chrome, for the web demo.
- For iOS: full Xcode and CocoaPods. For Android: Android Studio / SDK.

If `flutter` is not on your PATH, add the SDK's `bin` folder:

```bash
export PATH="$HOME/flutter/bin:$PATH"
```

## Run

```bash
flutter pub get
flutter run -d chrome
```

The game is portrait-first (390x844 design size). On a wide window it is letterboxed and centered. To judge the mobile feel, shrink the Chrome window to phone width or use DevTools device mode.

## Test

```bash
flutter analyze
flutter test
```

The tests cover the rules, undo, solver, level generator, tutorial levels, persistence, the feedback (sound/haptics) service, and the main screens.

## Build for web

```bash
flutter build web --release
```

The output is in `build/web/`. Host that folder on any static host (GitHub Pages, Netlify, Cloudflare Pages) and open the URL on your phone for a quick touch-feel check with no cable. Notes:

- The first load downloads the CanvasKit renderer (a few MB). The `canvaskit/` folder is large on disk because it holds every renderer variant; a browser fetches only one.
- If the site is not served from the domain root, pass `--base-href /your-path/`.
- Audio can only start after the first tap or click (browser autoplay rules), so music begins when you press Play.
- Haptics do nothing on web.
- Do not judge frame rate or performance from the web build alone.

## Mobile

Not yet verified. When you are ready:

**iOS Simulator** (needs the full Xcode app, not just command line tools):

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
open -a Simulator
flutter run -d "iPhone"
```

**Real iPhone:** open `ios/Runner.xcworkspace` in Xcode once, pick your personal team under Signing, plug the phone in, then `flutter run -d <device>`.

**Android:** install Android Studio, run `flutter doctor --android-licenses`, enable USB debugging on the phone, plug it in, then `flutter run -d <device>`.

Things to check first on a real device: touch targets, audio latency, haptics, and that progress survives closing the app.

## How the code is organized

```
lib/
  core/       Pure Dart game logic. No Flutter or Flame imports, so the
              renderer can be swapped (for example for 3D) later.
              Grid, buses, rules, undo session, solver, level generator.
  game/       Flame renderer: board, lane, queue, bus components, animations,
              confetti, and the single BusEscapeGame controller.
  ui/         Flutter screens: menu, level select, settings, game screen with
              HUD, boosters and result dialog.
  services/   Progress and settings (shared_preferences) and the
              sound/haptics service.
  levels/     Handmade tutorial levels (JSON) and the level repository.
assets/audio  Generated sound effects and music loop.
tools/        generate_audio.py
docs/         The original plan and build prompt.
test/         Unit and widget tests.
```

Key ideas:

- **Deterministic core.** `GameState` is immutable and every rule returns a new state, so undo is a stack of snapshots and a level plus a tap sequence always replays the same way. The level generator uses its own small random number generator so levels are identical on every platform.
- **Levels.** Levels 1-10 are handmade tutorials (`lib/levels/tutorial_levels.dart`, with hints). From level 11 they are generated: a lot outline is carved (often not a rectangle), cars (2 cells, 4 seats) and buses (3 cells, 6 seats) are placed in reverse exit order so the jam can always be emptied, then the passenger queue is built by playing that exit order with the real rules. That makes every level winnable by construction, with no search, and keeps generation fast even for 25+ vehicles.
- **Lane.** A road with parking bays. Some bays start locked (`+ 100`): tap one to unlock it with coins (up to 3 extra). Coins come from clearing levels (20 + 10 per star on a first clear).
- **Boosters** (3 of each to start, +1 of each for the first clear of every 5th level):
  - **Undo**: take back the last move or booster.
  - **Hint**: makes a vehicle that keeps the level winnable glow.
  - **Refresh**: re-places every vehicle still in the jam, guaranteed to stay winnable.
  - **Clear**: tap it, then tap any vehicle (even a boxed-in one) and a helicopter lifts it into the lane.
  - **Sort**: passengers who match a parked vehicle jump the queue and board it.
- **Stars.** Every level takes exactly one move per bus, so stars are about mistakes instead: 3 stars = no blocked taps and no boosters, 2 = no boosters but you tapped a blocked bus, 1 = you used any booster (Undo, Hint, Refresh, Clear or Sort).
- **Color symbols.** A Settings toggle (off by default) draws a distinct shape on every bus and passenger, so the game can be played without telling colors apart.

## Before a store release

- App identifier is `com.jkg.busescape` on all platforms. Check it is the one you want to register with the App Store and Google Play before the first upload (it cannot change afterwards).
- Add real app icons and a splash screen (needs art).
- Review the music pause on backgrounding on a real device; it relies on `FlameAudio.bgm.initialize()` and has only been exercised on web.

## Common tasks

**Edit or add a tutorial level:** change `lib/levels/tutorial_levels.dart`. `queueRuns` is `[color, count]` pairs; colors are 0 red, 1 blue, 2 green, 3 yellow, 4 purple, 5 orange. `flutter test test/levels` checks that every level is valid and solvable.

**Tune difficulty:** `LevelGenerator.configFor` in `lib/core/level_generator.dart` sets grid size, bus count, colors, lane slots and passenger mixing per level. The tests solve levels 1-80, and a stress test solves 1-300.

**Regenerate or replace audio:** `python3 tools/generate_audio.py` rewrites `assets/audio/`. To use your own sounds, keep the same file names.

**Add the art pack:** drop the files in `assets/images/`, register them in `pubspec.yaml`, record the pack name, author and license in `assets/CREDITS.md`, and swap `paintBus` in `lib/game/bus_component.dart` for sprites.

## Credits

See `assets/CREDITS.md`.
