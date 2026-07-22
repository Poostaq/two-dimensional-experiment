# AC1.2 Seeded Encounters Implementation Spec

**Project:** Two-Dimension Exploration  
**Source Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`  
**Acceptance Criterion:** AC1.2 - Hex encounter types (Safe/Combat/Boss) are seeded and deterministic per run ID  
**Owner:** Project Lead  
**Prepared by:** Codex  
**Date:** 2026-07-22  
**Status:** Implemented; evidence recorded  

---

## 1. Goal

Add deterministic encounter typing to the existing 25-hex world map. For a given Run ID, every valid map coordinate receives a reproducible encounter type from the AC1.2 set: Safe, Combat, or Boss.

AC1.2 builds on the implemented AC1.1 map navigation slice. It does not add battle entry, combat resolution, rewards, Sudden Death, persistence, or full run lifecycle ownership.

---

## 2. Current Project Context

- Godot project: Godot 4.7 configuration.
- Current scene: `res://Scenes/game_world.tscn`.
- AC1.1 baseline: implemented with evidence under `Docs/Specs/AC1/Evidence/AC1.1/2026-07-21/`.
- Map model: `res://Scripts/Map/hex_map_model.gd` owns bounded axial 5x5 coordinates, adjacency, start coordinate, boss coordinate, and path existence.
- Map controller: `res://Scripts/Map/map_controller.gd` owns scene-level player position, movement input, move count, tile instancing, and visual refresh.
- Tile view: `res://Scripts/Map/hex_tile_view.gd` owns per-tile display states.
- Current AC1.2 implementation state: encounter/run-ID APIs, Safe/Combat display states, and AC1.2 tests are implemented.

---

## 3. Acceptance Interpretation

The MVP spec says a different Run ID layout "can differ." For AC1.2 verification, this spec makes that measurable through fixed deterministic fixtures:

- Same fixture Run ID: `AC1.2-A`
  - Two generated layouts for this Run ID must match exactly.
- Different fixture Run IDs: `AC1.2-A` and `AC1.2-B`
  - Under the AC1.2 hash algorithm and 40% Safe / 60% Combat split, these two fixture Run IDs must differ by at least one non-boss tile.

This fixture expectation does not require every arbitrary pair of different Run IDs to differ. It requires the known verification pair to differ so the automated test proves the generator responds to Run ID input.

---

## 4. Design Decisions

### 4.1 Encounter Types

Use string constants in `HexMapModel`:

```gdscript
const ENCOUNTER_NONE := ""
const ENCOUNTER_SAFE := "safe"
const ENCOUNTER_COMBAT := "combat"
const ENCOUNTER_BOSS := "boss"
```

Safe, Combat, and Boss are the only valid encounter types for valid AC1.2 map coordinates.

### 4.2 Coordinate Rules

- Start coordinate: `Vector2i(0, 0)`.
- Boss coordinate: `Vector2i(4, 4)`.
- The start coordinate is always Safe.
- The boss coordinate is always Boss.
- Every other valid coordinate is seeded as Safe or Combat.
- Invalid coordinates return `ENCOUNTER_NONE`.

### 4.3 Run ID Rules

- Run ID is a `String`.
- Empty Run ID normalizes to `default-run`.
- Encounter assignment uses `RUN_ID:q:r` as the deterministic hash input for each coordinate.
- Generation must be order-independent so future systems can query one coordinate or a whole layout and get the same result.

### 4.4 Hash Rule

Use 32-bit FNV-1a with:

```gdscript
const HASH_OFFSET_BASIS := 2166136261
const HASH_PRIME := 16777619
const HASH_MODULUS := 4294967296
```

For non-start, non-boss valid coordinates:

```gdscript
var roll := _stable_hash("%s:%d:%d" % [normalized_run_id, coord.x, coord.y]) % 100
return ENCOUNTER_SAFE if roll < 40 else ENCOUNTER_COMBAT
```

The fixed fixtures `AC1.2-A` and `AC1.2-B` are expected to differ by at least one non-boss coordinate with this algorithm.

---

## 5. Proposed File Boundaries

### Modify

- `Scripts/Map/hex_map_model.gd`
  - Add encounter constants, Run ID normalization, stable hash helper, `get_encounter_type()`, and `get_encounter_types_for_run()`.

- `Scripts/Map/map_controller.gd`
  - Add `run_id`, cached `encounter_types`, `set_run_id()`, `get_encounter_layout()`, and `get_encounter_type_at()`.
  - Refresh tile display states from encounter data.

- `Scripts/Map/hex_tile_view.gd`
  - Add Safe and Combat display states.

- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
  - Keep AC1.2 unchecked until implementation evidence exists.
  - Mark AC1.2 complete only after automated log, manual/runtime check, and implementation link are recorded.

### Create

- `Tests/Map/test_ac1_2_encounter_determinism.gd`
  - Pure model determinism tests.

- `Tests/Map/test_ac1_2_runtime_encounter_layout.gd`
  - Runtime scene/controller layout tests.

- `Tests/Map/test_ac1_2_hex_tile_view_states.gd`
  - Tile view display-state regression test for seeded encounter visuals.

- `Docs/Specs/AC1/Evidence/AC1.2/YYYY-MM-DD/automated-test.log`
  - Current automated test output.

- `Docs/Specs/AC1/Evidence/AC1.2/YYYY-MM-DD/manual-runtime-check.md`
  - Manual/runtime verification notes.

- `Docs/Specs/AC1/Evidence/AC1.2/YYYY-MM-DD/implementation-link.txt`
  - Commit, branch, remote, PR status, spec path, and plan path.

---

## 6. Verification Requirements

Automated tests must prove:

- The generated encounter layout has one entry for every valid map coordinate.
- Generating a layout twice with `AC1.2-A` produces identical dictionaries.
- Generating layouts with `AC1.2-A` and `AC1.2-B` differs by at least one non-boss tile.
- Start coordinate is Safe.
- Boss coordinate is Boss.
- Non-boss valid coordinates are Safe or Combat only.
- Runtime `MapController` exposes the same deterministic layout behavior.
- `HexTileView` applies distinct Combat display colors for encounter visuals.
- Existing AC1.1 movement tests still pass.

Manual/runtime verification must prove:

- The scene creates 25 encounter entries.
- The start tile reports Safe.
- The boss tile reports Boss.
- The fixed Run ID pair `AC1.2-A` and `AC1.2-B` differs by at least one non-boss tile.
- Movement remains functional after encounter data is generated.

---

## 7. Traceability Matrix

| Source | Requirement | Verification Type | Evidence Target |
|---|---|---|---|
| AC1.2 | Same Run ID gives identical Safe/Combat/Boss layout | Automated model and runtime controller tests | `test_same_run_id_produces_identical_layout`; `test_same_run_id_keeps_matching_layout`; `automated-test.log` |
| AC1.2 | Different Run ID can affect layout | Fixed-fixture automated model and runtime controller tests | `AC1.2-A` vs `AC1.2-B` differ by at least one non-boss tile; `automated-test.log`; `manual-runtime-check.md` |
| AC1.2 | Start coordinate is Safe | Automated model and runtime controller tests | `test_start_is_safe`; `test_controller_reports_start_safe`; `manual-runtime-check.md` |
| AC1.2 | Boss coordinate is Boss | Automated model and runtime controller tests | `test_boss_is_boss`; `test_controller_reports_boss_boss`; `manual-runtime-check.md` |
| AC1.2 | Valid non-boss coordinates are Safe or Combat | Automated model test | `test_non_boss_tiles_are_safe_or_combat`; `automated-test.log` |
| AC1.2 | Combat encounter state is visually distinct | Automated tile view test | `test_ac1_2_hex_tile_view_states.gd`; `automated-test.log` |
| AC1.1 dependency | Existing movement behavior remains intact | Regression tests | `test_hex_map_model.gd`; `test_map_controller_runtime.gd`; `test_ac1_1_runtime_step_counts.gd` |

---

## 8. Evidence Governance

AC1.2 must remain unchecked in `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` until all required AC1.2 evidence exists:

```text
Docs/Specs/AC1/Evidence/AC1.2/YYYY-MM-DD/automated-test.log
Docs/Specs/AC1/Evidence/AC1.2/YYYY-MM-DD/manual-runtime-check.md
Docs/Specs/AC1/Evidence/AC1.2/YYYY-MM-DD/implementation-link.txt
```

Do not claim AC1.2 complete without:

- This implementation spec path.
- Current automated test results.
- Current manual/runtime verification.
- Commit or branch implementation reference.

---

## 9. Out Of Scope

- Entering the boss hex triggering combat.
- Combat scene creation.
- Encounter content payloads such as enemy groups, tavern choices, loot, or reward tables.
- Sudden Death and boss pursuit.
- Save/load persistence.
- Run history, run lifecycle management, or cross-scene run session ownership.
- Meta-progression.

---

## 10. Definition Of Done

AC1.2 is complete when:

- `HexMapModel` exposes deterministic encounter APIs.
- `MapController` exposes deterministic Run ID layout APIs.
- `HexTileView` can visually distinguish Safe and Combat encounter states.
- The boss coordinate is always Boss.
- The start coordinate is always Safe.
- Same Run ID layouts match exactly.
- The fixed fixture pair `AC1.2-A` and `AC1.2-B` differs by at least one non-boss tile.
- AC1.1 regression tests still pass.
- AC1.2 automated tests pass.
- Manual/runtime verification is recorded.
- Evidence files exist under `Docs/Specs/AC1/Evidence/AC1.2/YYYY-MM-DD/`.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` marks AC1.2 complete only after the evidence package exists.
