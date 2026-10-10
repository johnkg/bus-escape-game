# Build prompt: Bus Escape

Paste this into a fresh Claude Code session started in `~/Source/mobile/bus_escape`. Read `PLAN.md` first for background.

---

You are building **Bus Escape**, a polished 2D mobile puzzle game in the style of "Bus Out" / bus-escape games, using **Flutter + Flame (Dart)**. The first deliverable is a **playable web demo**; the long-term target is iOS/Android, so every decision must stay mobile-first.

## Game rules

- A rectangular **grid** is jammed with buses. Each bus occupies 2–3 cells, faces N/S/E/W, has a color and a seat capacity (equal to its length x 2, tunable).
- **Tapping a bus** drives it forward. It exits only if every cell ahead of it to the grid edge is empty. If blocked: shake animation, no state change, no move counted.
- A bus that exits parks in the **loading lane**, which has a limited number of slots (default 5).
- A **passenger queue** (colored figures) is shown. The front passenger auto-boards the leftmost parked bus of the same color. When a bus is full it departs and frees its slot.
- **Win:** grid empty, all passengers boarded. **Lose:** all lane slots full and the front passenger has no matching bus. No timer.
- A **moves counter** counts successful bus exits.
- **Boosters:** Undo (restore previous snapshot) and Extra Slot (+1 lane slot for the level). Counts persist.

## Tech and structure

- Flutter (stable) + Flame. Target Dart null safety, `flutter_lints`.
- Layout:
  - `lib/core/` — **pure Dart, no Flutter/Flame imports.** Grid, Bus, Passenger queue, rules engine, immutable `GameState` snapshots, undo stack, solver, level generator. Must be swappable behind a different renderer later (possibly 3D).
  - `lib/game/` — Flame components (grid, BusComponent, LaneComponent, PassengerComponent), animation, tap input, a single controller that reads/writes core state.
  - `lib/ui/` — Flutter screens: main menu, level select, HUD, win/lose dialogs, settings.
  - `lib/services/` — audio, haptics, persistence (`shared_preferences`), and **interfaces** for future monetization (`AdService`, `PurchaseService`) with no-op implementations. **Do not integrate any ads or IAP now.**
  - `lib/levels/` — handmade tutorial levels (JSON) and the procedural generator.
  - `test/` — unit tests for core.
- State is deterministic: given a level seed and a tap sequence, the result is reproducible.

## Levels

- **Procedural**, seeded by level number. Generate backwards from a solved state so a valid exit order exists, then **verify solvability with the solver** (including lane capacity and passenger order); reject and reseed if unsolvable.
- Difficulty curve knobs: grid size, bus count, length mix, color count, lane slots, passenger order randomness.
- **First ~8–10 levels handmade** as tutorial: tap a bus, blocked bus, the lane, boarding, a full-lane near-loss, Undo, Extra Slot.

## Art and audio

- Use a **free asset pack** (prefer CC0, e.g. Kenney.nl top-down vehicle / character packs). Put files under `assets/` and register them in `pubspec.yaml`. Keep a `assets/CREDITS.md` with pack name, author and license. If you need me to download a pack, tell me exactly which one and where to put it, then continue with colored placeholder rectangles until it is in place. Color buses by tinting a single sprite where possible.
- Juicy feel: ease-in drive-out, shake on blocked tap, boarding hop, bus departure, confetti on win, subtle screen shake on lose.
- SFX and music via a small audio service (e.g. `flame_audio`); settings toggles for sound, music and haptics. Haptics must be a no-op on web.

## Platform priorities

1. **Web demo first.** Must run with `flutter run -d chrome` and build with `flutter build web`. Portrait-first layout (~390x844 design size), letterboxed and centered on wide screens, scales cleanly. Touch and mouse both work.
2. Then iOS Simulator / Android, without any code forks. Keep web-specific code behind conditional imports or service interfaces.
3. Do not judge performance by web only; keep per-frame work small (no per-frame allocations in hot paths).

## Persistence and settings

Persist current level, best moves per level, booster counts and settings via `shared_preferences`. Provide a Reset Progress option.

## Process

- Flutter SDK may not be on PATH; check `flutter --version`. If missing, stop and tell me the exact install step. Do not install it silently.
- Work milestone by milestone, and commit-ready at each (no git commits unless I ask):
  1. Scaffold project, folder structure, lints, a passing smoke test.
  2. `core/`: grid, buses, exit rule, lane, boarding, win/lose, undo. **Tests first (TDD)**, covering blocked exits, boarding order, lane overflow, undo.
  3. Solver + generator + tests proving N seeded levels are solvable and deterministic.
  4. Flame rendering with placeholder visuals, tap input, animations.
  5. HUD, level flow, win/lose dialogs, level select, persistence.
  6. Boosters.
  7. Asset pack integration, audio, haptics, polish, tutorial levels.
  8. Web build verification and short README (how to run, test, build web, test on iOS Simulator / a real phone).
- After each milestone, run `flutter analyze` and `flutter test`, and report results honestly. For visual milestones, run it in Chrome and verify before claiming done.
- Ask me only when blocked on a decision that is genuinely mine; otherwise pick sensible defaults and note them.

## Definition of done (v1 web demo)

A player can open the web build on a phone-sized viewport, play through tutorial levels and at least 50 generated levels, use Undo and Extra Slot, win and lose correctly, hear sound, and resume progress after reload.
