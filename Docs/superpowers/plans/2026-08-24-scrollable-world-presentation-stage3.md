# Scrollable World Presentation Stage 3 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the approved 217-cell world presentation, camera, minimap, layered terrain, markers, HUD, Party entry, visual fixtures, and performance harness behind a dedicated non-production scene.

**Architecture:** A pure presentation controller consumes one validated `WorldPlan` and creates main-map and minimap views without owning generation or runtime movement. Focused view scripts own cell drawing, camera behavior, minimap projection, and HUD formatting. `Scenes/game_world.tscn`, `Scripts/Map/map_controller.gd`, and all frozen legacy tests remain unchanged throughout Stage 3.

**Tech Stack:** Godot 4.7, typed GDScript, Node2D/Control scenes, Camera2D, procedural Polygon2D/Line2D presentation, repository-root `icon.svg`, headless SceneTree tests, GodotIQ scene editing and verification.

**Authority:** `Docs/superpowers/specs/2026-08-23-scrollable-hex-world-target-design.md` and `Docs/superpowers/specs/2026-08-23-25-to-217-hex-world-migration-design.md`, Stage 3; closes automated/manual portions of WM-T06–WM-T10 and WM-T14–WM-T15 without production cutover.

**Branch and rollback boundary:** Work on `feat/world-presentation-stage3`, based on `main` SHA `203248307dbd8cb29cb240f48363b692afa39df2`. Rollback deletes only the new Stage 3 files. No production scene, current map controller, frozen test, encounter flow, or movement rule may change.

---

## File map

| Path | Responsibility |
|---|---|
| `Scripts/WorldMap/world_cell_view.gd` | One main-map cell with fixed layer precedence and testable geometry metrics |
| `Scenes/world_cell_view.tscn` | Persistent outline, terrain, road, town, highlight, and marker layer nodes |
| `Scripts/WorldMap/world_camera_controller.gd` | Drag pan, wheel zoom, 3/5/11 framing, and camera bounds; never emits movement |
| `Scripts/WorldMap/world_minimap.gd` | Complete-board miniature projection, town/party markers, and camera footprint |
| `Scenes/world_minimap.tscn` | Minimap panel and clipped drawing surface |
| `Scripts/UI/world_map_hud.gd` | Countdown, six semantic formation slots, context text, and Party request signal |
| `Scenes/world_map_hud.tscn` | Top countdown, bottom-left formation, bottom context bar |
| `Scripts/WorldMap/world_presentation_controller.gd` | Validated-plan consumption and view composition only |
| `Scenes/world_map_preview.tscn` | Explicit non-production Stage 3 entry using a deterministic fixture seed |
| `Tests/WorldMap/test_world_cell_view.gd` | Layer order and protected geometry contract |
| `Tests/WorldMap/test_world_camera_controller.gd` | Zoom, drag, bounds, and zero-turn semantics |
| `Tests/WorldMap/test_world_minimap.gd` | 217 cells, seven towns, two markers, camera footprint |
| `Tests/UI/test_world_map_hud.gd` | Countdown, Front/Back slots, context, Party gating |
| `Tests/WorldMap/test_world_presentation_scene.gd` | Full scene composition and production-isolation contract |
| `Tools/WorldMap/world_presentation_profile.gd` | Deterministic generation/build/update timing and node/memory counters |
| `Docs/Specs/WorldMap/Evidence/PresentationStage3/` | RED/GREEN, screenshots, profile, and isolation evidence |

### Task 1: Freeze Stage 3 isolation and cell-layer contract

**Files:**
- Create: `Tests/WorldMap/test_world_cell_view.gd`
- Create: `Docs/Specs/WorldMap/Evidence/PresentationStage3/baseline.txt`
- Create: `Docs/Specs/WorldMap/Evidence/PresentationStage3/red/cell-view-red.log`

- [ ] Record `git rev-parse HEAD`, dirty-worktree exclusions, and SHA-256 values for `Scenes/game_world.tscn`, `Scripts/Map/map_controller.gd`, and the frozen-test manifest.
- [ ] Write a failing SceneTree test that loads `Scenes/world_cell_view.tscn`, asserts named layers with z-indices `0..6`, verifies persistent outline geometry, and checks the road corridor, town footprint, and marker plate formulas for flat-to-flat width `F` and point-to-point height `H`.
- [ ] Run `godot --headless --quiet --path . --script res://Tests/WorldMap/test_world_cell_view.gd`; expect exit `1` because the scene is absent, and capture the output.
- [ ] Commit the baseline, RED test, UID, and RED evidence as `test: lock Stage 3 cell presentation contract`.

### Task 2: Implement the layered main-map cell

**Files:**
- Create: `Scripts/WorldMap/world_cell_view.gd`
- Create: `Scenes/world_cell_view.tscn`
- Modify: `Tests/WorldMap/test_world_cell_view.gd`

- [ ] Implement `configure(coord: Vector2i, encounter_type: String, terrain: String, road_edges: Array[Vector2i], is_town: bool) -> void`, `set_highlighted(value: bool) -> void`, and `set_party_marker(kind: String) -> void`.
- [ ] Keep encounter base, forest decoration, road corridor, town buildings, highlight, readability plate, and `icon.svg` marker in separate fixed-z children. Tint player green and boss red, add contrasting outlines, and expose computed corridor/footprint/plate rectangles for deterministic tests.
- [ ] Build the cell scene through GodotIQ, save it, then run per-file `validate` and `check_errors`.
- [ ] Run the cell test; expect all layer and geometry assertions to pass.
- [ ] Commit as `feat: add layered world cell presentation`.

### Task 3: Implement camera framing and input

**Files:**
- Create: `Tests/WorldMap/test_world_camera_controller.gd`
- Create: `Scripts/WorldMap/world_camera_controller.gd`

- [ ] Write failing tests for default five-hex framing, min three-hex framing, max eleven-hex framing, wheel clamp, left-button drag, bounded camera position, absence of an edge-scroll path, and unchanged supplied move count after every camera operation.
- [ ] Implement a Camera2D controller with `configure(world_rect: Rect2, viewport_size: Vector2, cell_flat_width: float)`, `zoom_by_steps(steps: int, anchor: Vector2)`, `pan_by(delta: Vector2)`, and `get_visible_world_rect()`. Consume only drag and wheel input; do not define a process-driven edge-scroll function.
- [ ] Derive zoom limits from `viewport_width / (hexes_across * cell_flat_width)` for 3 and 11 cells and default to 5; clamp camera center so the world cannot be lost beyond the viewport.
- [ ] Validate/check and run the test GREEN.
- [ ] Commit as `feat: add bounded world camera controls`.

### Task 4: Implement the complete-board minimap

**Files:**
- Create: `Tests/WorldMap/test_world_minimap.gd`
- Create: `Scripts/WorldMap/world_minimap.gd`
- Create: `Scenes/world_minimap.tscn`

- [ ] Write a failing test that configures the minimap from a golden `WorldPlan` and asserts 217 individually distinguishable cells, exactly seven towns, green player marker, red boss marker, and a camera-footprint outline that changes after a camera rectangle update without changing the plan bytes.
- [ ] Implement canonical axial projection into a fixed minimap rectangle. Draw cells individually, simplify terrain, show towns and both non-color-distinguished party markers, and update only the viewport outline on camera changes.
- [ ] Build and save the minimap scene with GodotIQ; validate/check and run the test GREEN.
- [ ] Commit as `feat: add complete-board world minimap`.

### Task 5: Implement the desktop HUD and Party request boundary

**Files:**
- Create: `Tests/UI/test_world_map_hud.gd`
- Create: `Scripts/UI/world_map_hud.gd`
- Create: `Scenes/world_map_hud.tscn`

- [ ] Write a failing test for move count, threshold `30`, exact remaining count, dormant/active label, three Back Line plus three Front Line slots, occupied/empty states, context terrain/encounter text, highlighted-neighbor instruction, `Manage Party` availability gating, and a typed `party_requested` signal.
- [ ] Implement `set_turn_state(move_count: int, boss_active: bool)`, `set_formation(slots: Array[RunCharacter])`, `set_context(encounter_type: String, terrain_tags: Array[String], is_valid: bool)`, and `set_party_available(value: bool)`.
- [ ] Build the HUD scene with a top bar, compact bottom-left formation, and remaining bottom context bar at the 1152×648 project baseline. The signal requests Party access but does not instantiate party management in Stage 3.
- [ ] Validate/check and run the HUD test GREEN.
- [ ] Commit as `feat: add world map HUD and Party boundary`.

### Task 6: Compose the non-production 217-cell preview

**Files:**
- Create: `Tests/WorldMap/test_world_presentation_scene.gd`
- Create: `Scripts/WorldMap/world_presentation_controller.gd`
- Create: `Scenes/world_map_preview.tscn`

- [ ] Write a failing integration test that loads the preview, builds one golden plan, asserts 217 main cells and one shared plan reference, verifies ten forest clusters and seven towns are presented, finds roads connecting all towns, checks player/boss marker coordinates, and confirms camera/minimap/HUD nodes are present.
- [ ] Implement `present_plan(plan: WorldPlan) -> bool` with full validation before clearing/publishing views. Instantiate cell views in canonical coordinate order, apply terrain and road topology, configure minimap/camera/HUD, and reject invalid plans without partial nodes.
- [ ] Build a dedicated preview scene with `WorldRoot`, Camera2D controller, minimap, HUD, and controller. Use a fixed approved fixture seed only for this explicit development entry.
- [ ] Assert `ProjectSettings.application/run/main_scene` remains `res://Scenes/game_world.tscn`, and `git diff` shows no changes to the frozen production boundary.
- [ ] Validate/check and run the integration test GREEN.
- [ ] Commit as `feat: add non-production 217-cell world preview`.

### Task 7: Add deterministic zoom fixtures and visual proof

**Files:**
- Create: `Tests/WorldMap/test_world_visual_fixtures.gd`
- Create: `Docs/Specs/WorldMap/Evidence/PresentationStage3/visual/fixture-manifest.json`
- Create: `Docs/Specs/WorldMap/Evidence/PresentationStage3/visual/visual-review.md`

- [ ] Add deterministic fixture states for road-through-forest, town-on-Safe, highlighted road, player-on-road, and boss-adjacent-to-forest at 3-, 5-, and 11-hex framing.
- [ ] Assert protected corridor, building footprint, marker plate, cell-outline, and layer-index metrics exactly before screenshot capture.
- [ ] Run the preview through GodotIQ at each zoom, capture one overview per verification point, inspect actual screenshots, and record observed readability issues and fixes. Do not approve pixel baselines automatically.
- [ ] Run the fixture test GREEN and commit as `test: add Stage 3 visual fixtures`.

### Task 8: Add performance harness and complete Stage 3 evidence

**Files:**
- Create: `Tools/WorldMap/world_presentation_profile.gd`
- Create: `Tests/WorldMap/test_world_presentation_profile.gd`
- Create: `Docs/Specs/WorldMap/Evidence/PresentationStage3/green/automated-tests.log`
- Create: `Docs/Specs/WorldMap/Evidence/PresentationStage3/green/runtime-health.json`
- Create: `Docs/Specs/WorldMap/Evidence/PresentationStage3/green/performance-profile.json`
- Create: `Docs/Specs/WorldMap/Evidence/PresentationStage3/green/isolation-proof.txt`

- [ ] Write a failing harness test that requires generation timing, presentation-build timing, minimap-update timing, resident node counts, memory delta, idle allocation stability, and environment metadata fields.
- [ ] Implement a deterministic profiler entry that exercises the approved seed corpus, 217-cell build, 60-second scripted pan/zoom path when explicitly requested, and idle update sampling without mutating world state.
- [ ] Run all Stage 3 tests, all Generator V1/save/run-start tests, and all 15 frozen legacy tests. Record exact commands and exit codes.
- [ ] Run GodotIQ project validation, parser checks, orphan-signal audit, preview runtime health, and main-scene runtime health.
- [ ] Record that authoritative reference-hardware WM-T15 approval remains a manual project-lead gate if this machine does not match the approved i3-12100F/RX 6500 XT baseline; do not fabricate compliance.
- [ ] Prove production isolation with SHA comparison and `git diff --exit-code <base> -- Scenes/game_world.tscn Scripts/Map Tests/Map` for frozen files.
- [ ] Commit evidence only as `test: record Stage 3 presentation evidence`.

## Final acceptance checklist

- [ ] WM-T06: approximately 3/5/11 cells across at max/default/min zoom.
- [ ] WM-T07: drag pan and wheel zoom are bounded and consume zero turns; no edge scroll exists.
- [ ] WM-T08: 217 outlined main cells and 217 outlined minimap cells remain distinguishable.
- [ ] WM-T09: minimap contains seven towns, both party markers, and live camera footprint.
- [ ] WM-T10: countdown, six Front/Back formation slots, context bar, and Party request are readable.
- [ ] WM-T14: fixed layer precedence and clear-space formulas pass deterministic fixtures.
- [ ] WM-T15: automated measurements are captured; reference-hardware approval is accurately reported as PASS or pending.
- [ ] Production remains the frozen 25-cell `Scenes/game_world.tscn` path.
- [ ] No runtime movement, encounter, boss pursuit, or production cutover is introduced in Stage 3.
