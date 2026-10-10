# Bus Escape — Plan

A clone of the "Bus Out / Bus Escape" puzzle genre: a jammed parking-lot grid of buses, tap a bus to drive it out, passengers board matching-color buses.

## 1. Core mechanic (what we are cloning)

- **Grid** of buses. Each bus occupies 2–3 cells, faces N/S/E/W, has a color and a seat capacity.
- **Tap a bus** → it drives forward and exits only if every cell ahead of it to the grid edge is clear. Blocked bus = shake/no-op.
- **Loading lane** with limited slots (5). A bus that leaves the grid parks in a slot.
- **Passenger queue** (colored stick figures) at the front. Front passenger auto-boards the leftmost parked bus of the same color. Full bus departs and frees its slot.
- **Win:** all buses cleared and all passengers boarded.
- **Lose:** all slots full and the front passenger has no matching bus. No timer.
- **Boosters:** undo, extra slot, (later) shuffle queue / remove blocker.

## 2. Tech stack options

| Option | Pros | Cons |
|---|---|---|
| **Flutter + Flame (Dart)** | One codebase iOS/Android/web/desktop; good 2D engine; hot reload; strong UI toolkit for menus/settings; user's stated preference | Smaller game ecosystem; no real 3D; web build is heavy |
| Godot 4 (GDScript) | Real game editor, 2D+3D, great export to mobile/web | Separate tool/language, less code-first for AI-driven workflow |
| Unity (C#) | Industry standard, 3D, ads/IAP SDKs | Heavy, license/runtime fees history, overkill for this |
| Phaser/PixiJS + Capacitor (TS) | Best web reach, fast iteration, huge ecosystem | Wrapped web view on mobile; weaker native feel |
| React Native + Skia | Native UI feel | Game loop/animation ergonomics worse than Flame |

**Recommendation: Flutter + Flame.** Game is a turn-based grid puzzle with simple 2D animation, so Flame is more than enough. Flutter gives menus, settings, and store builds for free. Keep game logic in a renderer-agnostic `lib/core/` so a 3D rewrite stays possible.

## 3. Architecture

```
bus_escape/
  lib/
    core/        # pure Dart: grid, bus, passenger queue, rules, undo stack, level generator (no Flutter/Flame imports)
    game/        # Flame: components (BusComponent, LaneComponent, PassengerComponent), tween/animation, input
    ui/          # Flutter widgets: main menu, level select, win/lose dialogs, settings, HUD
    services/    # audio, haptics, persistence (shared_preferences), settings
    levels/      # handmade tutorial levels (JSON) + procedural generator
  assets/        # sprites, sfx, music
  test/          # unit tests for core (rules, generator solvability, undo)
```

Key decisions:
- **Deterministic core + immutable state snapshots** → undo is trivial, tests are easy, generator can verify solvability.
- **State management:** plain `ChangeNotifier`/Riverpod for UI; Flame reads core state through a single controller.
- **Persistence:** `shared_preferences` (level, coins, boosters, settings).

## 4. Level generation

- Seeded by level number → reproducible.
- Generate **backwards from solved**: place buses so a valid exit order exists, then verify with a solver (BFS/DFS on exit order + lane capacity). Reject unsolvable seeds.
- Difficulty knobs: grid size, bus count, bus length mix, color count, lane slots, passenger order randomness.
- First ~10 levels handmade as a tutorial (tap, blocked bus, lane, boarding, booster intro).

## 5. Milestones

1. **Scaffold** — Flutter project, folder structure, lints, CI-less tests running.
2. **Core rules** — grid, bus exit logic, lane, boarding, win/lose, undo. Full unit tests.
3. **Solver + generator** — solvable procedural levels, difficulty curve.
4. **Flame rendering** — grid, buses (placeholder art), tap input, drive-out and boarding animations.
5. **Game loop UX** — HUD, moves counter, win/lose flow, level progression.
6. **Boosters + economy** — undo, extra slot, coins.
7. **Polish** — real art, particles, SFX/music, haptics, settings, tutorial.
8. **Ship prep** — app icons, splash, Android/iOS builds, optional web build.

## 6. Risks / open questions

- Art: placeholder shapes first vs. generated/purchased asset pack?
- Monetization (ads/IAP) — out of scope for now?
- Target platforms priority: phone first, web demo later?
- Flutter SDK not yet on PATH — user installs it, we verify with `flutter doctor`.

## 7. Decisions (confirmed)

- Stack: Flutter + Flame.
- Art: free asset pack (CC0, e.g. Kenney), not hand-drawn placeholders; placeholder rectangles only until the pack is downloaded.
- Ads/IAP: skipped for now; build later once the full game works. `AdService`/`PurchaseService` interfaces with no-op impls keep the door open.
- Platform order: **web demo first**, then iOS Simulator / real phone.

## 8. Test loop

- Daily: `flutter run -d chrome` with a phone-sized viewport.
- Mobile feel: iOS Simulator.
- Real phone: occasional USB check.
- Shareable: `flutter build web` hosted on GitHub Pages/Netlify, open on phone.

## 9. Next step

Run the prompt in `PROMPT.md`.
