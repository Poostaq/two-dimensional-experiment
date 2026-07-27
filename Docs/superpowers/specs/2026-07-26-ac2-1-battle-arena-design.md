# AC2.1 Battle Arena Design

**Project:** Two-Dimension Exploration  
**Source Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`  
**Acceptance Criterion:** AC2.1 — Battles use a 6-slot player side and a 6-slot enemy side  
**Owner:** Project Lead  
**Prepared by:** Codex  
**Date:** 2026-07-26  
**Status:** Approved for implementation planning

---

## 1. Goal

Connect Combat and Boss encounter overlays to a full-screen battle arena containing exactly six player slots and six enemy slots in opposing formations. Preserve the active map and run state underneath the arena so later combat criteria can resolve a battle and return to the same run.

## 2. Scope

AC2.1 includes:

- An `Enter Battle` action for Combat and Boss encounter overlays.
- A reusable full-screen `battle_arena.tscn` instantiated under the world scene's existing UI layer.
- Six uniquely indexed player slots and six uniquely indexed enemy slots.
- A visible distinction between player and enemy formations.
- Encounter coordinate and encounter type passed into the arena as battle context.
- Map input blocked for the entire time the arena is active.
- A temporary `Exit Battle (Debug)` action that removes the arena and restores map navigation.
- Automated structural and transition tests plus manual runtime verification.

AC2.1 excludes:

- Changes to Safe encounter behavior.
- Unit population, character data, enemy composition, or roster integration.
- Speed order, actions, targeting, damage, defeat, victory, or loss.
- Rewards, combat persistence, and production battle-exit rules.
- Final visual art, animation, audio, and balance.

## 3. Baseline Assumptions

AC2.1 begins from the following verified pre-combat state:

- `res://Scenes/game_world.tscn` contains the existing `UI` `CanvasLayer` that will host the arena.
- `res://Scripts/Map/map_controller.gd` owns active encounter lifecycle and navigation blocking, but has no active-battle API.
- `res://Scripts/Encounter/encounter_overlay.gd` exposes `close_requested` and `configure()`, but has no battle request signal.
- `res://Scenes/battle_arena.tscn` does not exist and will be created by AC2.1.
- `res://Scripts/Battle/battle_arena.gd` does not exist and will be created by AC2.1.
- `res://Tests/Map/test_ac2_1_battle_arena.gd` does not exist and will be created as the focused structural and transition test.
- `Docs/Specs/AC2/` does not exist and will be created with the AC2.1 evidence hierarchy.

These are intentional implementation targets, not missing prerequisites.

## 4. Encounter-Type Contract

`HexMapModel` is the canonical encounter-type authority. AC2.1 accepts only these existing case-sensitive values:

| Constant | Canonical string | AC2.1 behavior |
|---|---|---|
| `HexMapModel.ENCOUNTER_SAFE` | `"Safe"` | Preserve the existing overlay; do not expose or accept battle entry. |
| `HexMapModel.ENCOUNTER_COMBAT` | `"Combat"` | Expose battle entry and configure the arena as Combat. |
| `HexMapModel.ENCOUNTER_BOSS` | `"Boss"` | Expose battle entry and configure the arena as Boss. |

AC2.1 performs no trimming, case folding, aliasing, or fallback normalization. Callers must pass a canonical constant. Any other value, including `HexMapModel.ENCOUNTER_NONE`, is ineligible for battle entry and must not create an arena. Tests compare behavior against the `HexMapModel` constants rather than duplicating free-form literals.

## 5. Authority and Dependency Chain

Implementation and review use this ordered authority chain:

1. `.agents/policies/project-governance.md` defines the Concept → Design → Implementation → QA gate and current-evidence requirement.
2. `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` is the product authority for AC2.1 and its manual runtime verification path.
3. This document is the approved behavioral, architectural, interface, and verification authority for AC2.1.
4. `Docs/superpowers/plans/2026-07-27-ac2-1-battle-arena.md` will define the implementation sequence after this design is approved.
5. `Docs/Specs/AC2/Evidence/AC2.1/2026-07-26/` is the completion authority; AC2.1 remains unchecked until every required artifact exists and records passing current evidence.

AC2.1 depends on the existing AC1.2 encounter-type constants, AC1.3 map input path, AC1.4 encounter lifecycle/input blocking, and AC1.5 runtime Boss identity. Existing `Tests/Map/*.gd` assets remain regression authority for those contracts.

No roadmap or migration-matrix artifact exists in the repository. This design does not create a competing planning authority solely for AC2.1.

## 6. Architecture

The battle arena is a packed full-screen `Control` scene instantiated as a child of the existing `UI` `CanvasLayer` in `game_world.tscn`. `MapController` remains the runtime flow owner because it already owns the encounter overlay, navigation guard, run state, and UI-layer reference.

`EncounterOverlay` presents an `Enter Battle` button only when configured with a Combat or Boss encounter. Pressing it emits `battle_requested(coordinate, encounter_type)`. Safe encounters do not show the button and retain their existing close behavior unchanged.

`MapController` handles the request as one transition:

1. Validate that the active overlay requested Combat or Boss.
2. Close the active encounter overlay.
3. Instantiate `battle_arena.tscn` under the existing UI layer.
4. Configure it with the encounter coordinate and type.
5. Retain the instance as the active-battle authority.

`request_move()` rejects navigation whenever either an encounter overlay or battle arena is active. The arena's temporary `exit_requested` signal lets `MapController` free the arena and restore the existing map without resetting coordinates, move count, Run ID, boss position, encounter layout, or Sudden Death state.

## 7. Components and Interfaces

### 7.1 Encounter Overlay

`Scripts/Encounter/encounter_overlay.gd` gains:

```gdscript
signal battle_requested(coordinate: Vector2i, encounter_type: String)
```

The scene gains an `Enter Battle` button. `configure()` shows and enables it only for Combat and Boss. Its pressed handler emits the stored coordinate and type. The existing `close_requested` contract remains intact.

### 7.2 Battle Arena

`Scripts/Battle/battle_arena.gd` defines `class_name BattleArena` and owns:

```gdscript
signal exit_requested

const SIDE_SLOT_COUNT := 6

var encounter_coordinate: Vector2i
var encounter_type: String

func configure(coordinate: Vector2i, type: String) -> void
func get_player_slots() -> Array[Control]
func get_enemy_slots() -> Array[Control]
```

`Scenes/battle_arena.tscn` contains:

- A full-rect opaque background that visually replaces the map while active.
- A title/context area identifying Combat or Boss.
- `PlayerFormation` with exactly six slot controls indexed `0` through `5`.
- `EnemyFormation` with exactly six slot controls indexed `0` through `5`.
- Opposing layout and side labels so formation ownership is unambiguous.
- An `Exit Battle (Debug)` button.

Slots are scene-authored structural nodes, not generated combatants. Each slot exposes its side and index through node metadata or an equivalent stable scene-authored property so tests and later combat systems do not depend on screen coordinates or label text.

### 7.3 Map Controller

`Scripts/Map/map_controller.gd` gains:

```gdscript
func has_active_battle() -> bool
func get_active_battle() -> BattleArena
func exit_active_battle() -> void
```

It preloads or loads the arena scene, connects `EncounterOverlay.battle_requested`, owns the active arena reference, and treats either active UI state as a navigation blocker. `set_run_id()` closes both active UI states before resetting the run.

## 8. UI and Interaction

The arena fills the viewport and consumes mouse input so the map cannot receive clicks through it. The two formations face one another across the center of the screen, with player slots grouped consistently on one side and enemy slots on the other. Slot styling may use simple project-native panels, borders, and labels; final combat art is outside AC2.1.

Combat and Boss overlays expose the same transition action. The arena displays the encounter type so the route is observable, but both types share one structural arena. Safe overlays remain behaviorally and visually unchanged.

The debug exit is deliberately temporary. It provides a complete verification loop until AC2.4 defines production battle completion and return behavior.

## 9. State and Error Handling

- A battle request is accepted only from the currently active overlay.
- Only Combat and Boss types may start a battle.
- A second battle cannot be created while one is active.
- Navigation requests fail without mutation while an encounter or battle is active.
- Exiting a battle removes only the arena; it does not reset or advance the map.
- Changing the Run ID removes any active encounter or battle before applying the normal reset.
- Missing or invalid arena instantiation fails without leaving a stale active-battle reference.
- Signal connections use typed handlers and one-shot scene ownership rather than global state.

## 10. Verification

### Automated

Create the focused headless test asset:

`res://Tests/Map/test_ac2_1_battle_arena.gd`

Run it from the repository root with:

```powershell
godot --headless --path . --script Tests/Map/test_ac2_1_battle_arena.gd
```

The test must exit `0` and print this exact success signature:

```text
AC2.1 battle arena tests: PASS (11/11)
```

Any failed assertion must print one or more lines beginning with `FAILED:`, omit the success signature, and cause exit code `1`.

The 11 cases verify:

1. The arena exposes exactly six player slots.
2. The arena exposes exactly six enemy slots.
3. Each side uses the complete unique index set `0..5`.
4. Combat overlays show `Enter Battle` and transition into a configured arena.
5. Boss overlays show `Enter Battle` and transition into a configured arena.
6. Safe overlays do not expose a battle transition and preserve close behavior.
7. The encounter overlay is closed when battle begins.
8. Map navigation is rejected without state mutation during battle.
9. A duplicate battle request does not create another arena.
10. Debug exit removes the arena and preserves map/run state.
11. `set_run_id()` clears an active arena and performs the existing complete reset.

Encounter-type cases must use and assert the canonical `HexMapModel.ENCOUNTER_SAFE`, `HexMapModel.ENCOUNTER_COMBAT`, and `HexMapModel.ENCOUNTER_BOSS` constants, including rejection of noncanonical and unsupported values.

Run all existing map tests independently as the regression gate:

```powershell
Get-ChildItem Tests/Map/*.gd | ForEach-Object {
    & godot --headless --path . --script $_.FullName
    if ($LASTEXITCODE -ne 0) { throw "Failed: $($_.Name)" }
}
```

Expected: every test exits `0`, no output contains `FAILED:`, and the focused test prints `AC2.1 battle arena tests: PASS (11/11)`.

### Manual runtime check

Using a deterministic Run ID:

1. Enter a Combat hex and select `Enter Battle`.
2. Confirm the full-screen arena shows exactly six player and six enemy slots in opposing formations and identifies the encounter as Combat.
3. Confirm map clicks do not move the player while the arena is active.
4. Use `Exit Battle (Debug)` and confirm the player remains on the Combat hex.
5. Enter the Boss encounter and repeat the structural check with Boss context.
6. Enter a Safe hex and confirm its existing overlay behavior is unchanged and no battle action appears.

## 11. Completion Evidence

AC2.1 remains unchecked until the repository contains:

- Passing focused AC2.1 automated output.
- Passing existing AC1 regression output.
- GodotIQ project validation, parser, signal, and runtime-health evidence.
- A manual runtime record for Combat, Boss, Safe, input blocking, and debug return.
- An implementation link identifying the task branch and final implementation commit.

Evidence belongs under:

`Docs/Specs/AC2/Evidence/AC2.1/2026-07-26/`

Implementation must create the complete hierarchy and these artifacts:

### `automated-test.log`

Record:

- Date, Godot version, branch, and implementation commit under test.
- Exact command base.
- One `RUN <test path>` section per `Tests/Map/*.gd` asset.
- Full relevant output, exact PASS signature, and `EXIT 0` for every test.
- GodotIQ project validation, parser check, and orphan-signal results.

### `manual-runtime-check.md`

Record:

- Date, Godot version, scene, branch, implementation commit, and deterministic Run ID.
- Runtime startup and debug-console health.
- A step table containing input/check, expected result, observed result, and PASS/FAIL for Combat entry, the 6+6 formation, input blocking, debug exit with preserved map state, Boss entry, and unchanged Safe behavior.
- Overall PASS only when every required observation passes.

### `implementation-link.txt`

Record:

- Branch and final implementation commit.
- PR state or URL.
- Source spec, this design, and implementation-plan paths.
- Implemented scene, script, and test paths.
- All evidence artifact paths.

The evidence folder is the completion authority. `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` must keep AC2.1 unchecked until all three files exist with passing current results.

## 12. Future Extension Points

Later AC2 criteria may populate the stable slot nodes with units, calculate speed order, resolve damage and defeat, and replace debug exit with battle results. Those additions should extend `BattleArena` or introduce focused battle-domain collaborators without moving run-state ownership out of `MapController` prematurely.
