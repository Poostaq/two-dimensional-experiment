# AC3.5 Post-Battle Recovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist victory recovery so survivors start the next battle at full HP and passed-out characters start at rounded-up 50% HP.

**Architecture:** Keep mutable between-battle HP in `WorldRunState`, keyed by character ID. Use a pure recovery helper, let `BattleArena` expose a defensive terminal player snapshot, and let `WorldRuntimeController` atomically commit the recovered map through the existing autosave transaction before the next battle consumes it.

**Tech Stack:** Godot 4, typed GDScript, SceneTree test runners, Save V2 JSON codec, GodotIQ structured editing and verification, Git.

---

## Scope and file ownership

**Create**

- `Scripts/Run/post_battle_recovery_rules.gd` — pure validation and recovery calculation.
- `Tests/Run/test_ac3_5_post_battle_recovery.gd` — rule and run-state tests.
- `Tests/WorldMap/test_ac3_5_recovery_integration.gd` — victory-to-next-battle integration tests.

**Modify**

- `Scripts/Run/world_run_state.gd` — durable `character_hp`, validation, serialization, canonical key, and defensive access.
- `Scripts/Save/world_run_save_codec_v2.gd` — backward-compatible decode path for saves without health.
- `Scripts/Run/run_roster.gd` — initialize battle units from durable HP.
- `Scripts/Battle/battle_arena.gd` — defensive terminal player-health snapshot.
- `Scripts/WorldMap/world_runtime_controller.gd` — victory-only recovery and atomic autosave integration.
- Relevant retained tests under `Tests/Run`, `Tests/Save`, `Tests/Battle`, and `Tests/WorldMap` when existing fixtures require the new state field.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — mark AC3.5 complete and replace the manual-only verification path after evidence exists.

## Mandatory execution rules

Before every `.gd` edit, call GodotIQ `file_context(detail="brief")`; before signature changes, call `impact_check`. Edit GDScript only through `script_ops`. After each script change, call `validate(target=<file>, detail="brief")` and `check_errors(scope=<file>)`. Follow RED–GREEN–REFACTOR: no production change precedes its failing test.

### Task 1: Add pure recovery rules

**Files:** Create `Tests/Run/test_ac3_5_post_battle_recovery.gd`; create `Scripts/Run/post_battle_recovery_rules.gd`.

- [ ] Write a SceneTree test runner that expects survivor `7/20 -> 20`, defeated even `0/20 -> 10`, defeated odd `0/19 -> 10`, and rejection of empty IDs, negative/final-over-max HP, and non-positive maximum HP.
- [ ] Run `godot --headless --path . --script res://Tests/Run/test_ac3_5_post_battle_recovery.gd`; expect RED because `PostBattleRecoveryRules` does not exist.
- [ ] Create `class_name PostBattleRecoveryRules extends RefCounted` with `static func calculate_next_hp(character_id: StringName, final_hp: int, max_hp: int) -> int`; return `-1` for invalid input, otherwise `max_hp` for survivors and `(max_hp + 1) / 2` for defeated characters.
- [ ] Validate/check the new script and rerun the test; expect PASS.
- [ ] Commit: `git commit -m "feat: add AC3.5 recovery rules"`.

### Task 2: Persist character health in run state and Save V2

**Files:** Modify `Tests/Run/test_ac3_5_post_battle_recovery.gd`, `Tests/Save/test_world_run_save_codec_v2.gd`, `Scripts/Run/world_run_state.gd`, and `Scripts/Save/world_run_save_codec_v2.gd`.

- [ ] Add failing tests for a typed `Dictionary[StringName, int]` health snapshot, defensive copying, formation/health identity consistency, valid bounds, canonical-key changes, Save V2 round trip, and old payloads without `character_hp` loading with an empty migration marker.
- [ ] Run both test runners; expect RED on missing health API/state.
- [ ] Add `character_hp`, `get_character_hp_snapshot()`, and `set_character_hp_snapshot()` to `WorldRunState`; include deterministic string-keyed health in `to_dictionary()` and parse it in `from_dictionary()`.
- [ ] Keep absent `character_hp` backward-compatible; reject present malformed dictionaries, duplicate normalized IDs, non-integer values, or HP outside `1..max_hp` when catalog validation is applied by the controller.
- [ ] Update canonical-key material to include sorted character-health entries.
- [ ] Validate/check each modified script, rerun both tests, and expect PASS.
- [ ] Commit: `git commit -m "feat: persist run character health"`.

### Task 3: Feed durable HP into fresh battle units

**Files:** Modify `Tests/Run/test_ac3_1_run_roster.gd`, `Tests/Run/test_ac3_3_party_formation.gd`, and `Scripts/Run/run_roster.gd`.

- [ ] Add failing tests for `create_battle_units(character_hp)` using stored values, rejecting incomplete/unknown/out-of-range data, and preserving health by identity after moves/replacement.
- [ ] Run the two roster runners; expect RED because battle creation always initializes full HP.
- [ ] Extend `create_battle_units(character_hp: Dictionary[StringName, int] = {})` so an empty dictionary retains legacy full-HP behavior while a provided map must contain one valid value for every occupied roster character.
- [ ] Ensure recruitment uses full max HP and replacement removes the dismissed identity at the controller-owned health-map boundary.
- [ ] Validate/check `run_roster.gd`; rerun both tests and expect PASS.
- [ ] Commit: `git commit -m "feat: initialize battles from run health"`.

### Task 4: Expose the terminal player snapshot

**Files:** Modify `Tests/Battle/test_ac2_4_battle_results.gd` and `Scripts/Battle/battle_arena.gd`.

- [ ] Add failing tests for `get_terminal_player_health_snapshot()` returning player-only dictionaries with `character_id`, `final_hp`, and `max_hp`, unavailable before completion, and defensively copied.
- [ ] Run the battle-results runner; expect RED on the missing API.
- [ ] Implement the read-only API from arena-owned player units without exposing `BattleUnitState` references.
- [ ] Validate/check `battle_arena.gd`; rerun AC2.4 and expect PASS.
- [ ] Commit: `git commit -m "feat: expose terminal player health"`.

### Task 5: Commit victory recovery atomically

**Files:** Create `Tests/WorldMap/test_ac3_5_recovery_integration.gd`; modify `Scripts/WorldMap/world_runtime_controller.gd` and affected WorldMap fixtures.

- [ ] Add failing integration cases proving victory maps survivors to max and defeated characters to rounded-up half, commits once, survives save/reload, initializes the following battle, and leaves durable state unchanged on defeat/debug closure or autosave failure.
- [ ] Run the new runner; expect RED because `_on_battle_completed` does not commit recovery.
- [ ] In the existing completion listener, validate the arena snapshot against the active roster/catalog, calculate the complete candidate map, update a copied `WorldRunState`, and submit it through the existing save coordinator. Guard the active battle against duplicate completion.
- [ ] On successful save, publish candidate state and synchronize roster battle creation; on failure, retain prior durable state and existing retry/discard semantics.
- [ ] Update recruitment/replacement paths so new identities receive max HP and dismissed identities are removed without slot coupling.
- [ ] Validate/check the controller and rerun the new integration test plus `test_world_battle_entry.gd` and `test_ac6_7_goblin_integration.gd`; expect PASS.
- [ ] Commit: `git commit -m "feat: integrate AC3.5 victory recovery"`.

### Task 6: Verify, document, and record evidence

**Files:** Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`; create evidence under `Docs/Specs/AC3/Evidence/AC3.5/2026-09-14/`.

- [ ] Run project validation, project parser checks, and signal-orphan checks.
- [ ] Run AC2.4, AC2.5, AC3.1, AC3.3, AC3.5, AC6.7, World battle-entry, WorldRunState, and Save V2 runners; save stdout/stderr evidence.
- [ ] Use GodotIQ `verify_project_runs(scene="main")`, inspect the debug console, and stop the game cleanly.
- [ ] Perform the manual two-battle AC3.5 flow from the design, including save/reload; record exact observed HP values.
- [ ] Mark AC3.5 complete and update its verification path with exact automated runners and evidence directory.
- [ ] Run `git diff --check`, confirm only AC3.5 files are staged, and commit: `git commit -m "docs: complete AC3.5 recovery evidence"`.

