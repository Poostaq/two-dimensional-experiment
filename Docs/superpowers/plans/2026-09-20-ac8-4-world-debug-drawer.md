# AC8.4 Habitat and World Debug Drawer Implementation Plan

> **For agentic workers:** Use superpowers:executing-plans and test-driven-development. Follow AGENTS.md, use the primary workspace task branch and GodotIQ edits. The approved design is `Docs/superpowers/specs/2026-09-20-ac8-4-habitat-and-world-debug-drawer-design.md`.

**Status:** Implemented in `cf25a14`; 27 regression runners and two rendered viewport checks passed. [Verification evidence](../../Specs/AC8/Evidence/AC8.4-expansion/verification.md).

**Goal:** Persistent current-habitat HUD information and a read-only current-hex debug drawer matching battle.

**Architecture:** WorldHabitatRules provides versioned compatibility data. TownOwnershipRules delegates to it while preserving town-only errors. WorldRuntimeController produces a detached diagnostic dictionary from authoritative state; WorldDebugPresenter formats sections and WorldDebugDrawer owns only overlay/focus/input behavior. Authored scenes own static UI.

**Tech Stack:** Godot 4.7.2, typed GDScript, authored Control scenes, SceneTree tests, GodotIQ.

## Task 1 — Shared habitat rule

- [x] Create `Scripts/WorldMap/world_habitat_rules.gd`; modify `Scripts/WorldMap/town_ownership_rules.gd` and `Scripts/WorldMap/world_runtime_model.gd`.
- [x] Add `Tests/WorldMap/test_ac8_4_habitat_rules.gd`, require failure before production edits. Test every v1 cell, town-only errors, invalid plan/cell/version, no topology mutation and reload compatibility.
- [x] API: `resolve(plan: WorldPlan, coord: Vector2i) -> Dictionary` returns `{ok, clan_id, display_name, source, habitat_id, error}`. V1 success uses `goblin`, `Goblin`, `Legacy world v1 rule`, empty habitat ID. Failure uses empty IDs and explicit error; presentation says Unavailable. Model exposes `get_habitat(coord)`.
- [x] Validate/check each script and pass the new runner plus existing ownership/reload runners.

## Task 2 — Authored drawer and detached presenter

- [x] Create `Scripts/UI/world_debug_presenter.gd`, `Scripts/UI/world_debug_drawer.gd`, `Scenes/UI/world_debug_drawer.tscn`, `Tests/UI/test_world_debug_drawer.gd`.
- [x] Test presenter sections/unknown values and drawer default state, focus restoration, Escape/Tab, detached data and pointer/wheel isolation before implementation.
- [x] Presenter `format_sections(view: Dictionary) -> Dictionary` returns `hex`, `habitat`, `map`, `run`, `persistence` strings. Input includes coordinate, terrain, base/effective encounter, consumed, town index, habitat/owner results, neighbors/destinations/road links/forest memberships, seed/version/player/boss/moves/status/gold and interaction/persistence fields.
- [x] Drawer API `render(view)`, `set_open(opened, restore_focus=true)`, `reset_view()`, `is_open()`, `set_available(value)`. Collapse by default. Right-edge authored panel, full-height scrolling diagnostics, close button and edge handle. Stop pointer propagation within panel; close with Escape and contain Tab focus. Do not mutate diagnostic data or game state.

## Task 3 — HUD and runtime integration

- [x] Modify `Scripts/UI/world_map_hud.gd`, `Scenes/world_map_hud.tscn`, `Scripts/WorldMap/world_runtime_controller.gd`, `Scenes/world_map_runtime.tscn`.
- [x] Add `Tests/WorldMap/test_ac8_4_world_debug_integration.gd`: accepted/rejected moves, save failure/retry, current versus hover, reload, modal hiding, session reset and no mutation from drawer interactions.
- [x] Add HUD `set_habitat(habitat: Dictionary)`; label always refers to committed player coordinate. Controller exposes `get_debug_snapshot() -> Dictionary`, composes detached fields and refreshes at existing snapshot/publication/modal boundaries. Preview missing durable fields display Unavailable, not invented values.
- [x] Hide/close drawer for encounter, battle, party, gold reward and autosave-failure surfaces. Re-enable when world interaction resumes. No per-frame map rebuilding or persistence. Preserve existing battle drawer and map layout.

## Task 4 — Verification and delivery

- [x] Run focused new runners and existing ownership/reload, HUD, world model/scene, camera, save-coordinator, launcher, codecs v2-v5, reward and battle-drawer regression runners.
- [x] Command template: `godot.windows.opt.tools.64.exe --headless --path . --quit-after 1800 --script res://Tests/UI/test_world_debug_drawer.gd`. Capture output with Python subprocess and 120-second timeout; require exit 0, PASS and no ERROR.
- [x] GodotIQ play, verify_project_runs, console and state inspection. Exercise real pointer and keyboard input. Render 1280x720 and 1920x1080 including long seed and scroll; inspect captured images and correct clipping/overlap.
- [x] Final per-script/project validation, error and orphan checks; independent code review. Record results/screenshots in `Docs/Specs/AC8/Evidence/AC8.4-expansion/` with `.gdignore`.
- [x] Commit relevant scripts/scenes/tests/UIDs and evidence on `feat/ac8-4-world-debug-drawer`; restore unrelated local changes unstaged. Do not push without request. Keep broader filtered-offer acceptance pending AC8.5/AC8.6.
