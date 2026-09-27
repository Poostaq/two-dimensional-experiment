# AC9.1 Clan Selection and Direct Start Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the player select a playable clan and an owning commander, then atomically replace a run without an overwrite confirmation.

**Architecture:** `RunCharacterCatalog` is the only playable-clan and commander-ownership authority. `RunClanSelection` validates a typed selection. `WorldRunSaveCodecV6` persists the pair in the `world` envelope and delegates older saves to V5.

**Tech Stack:** Godot 4, typed GDScript, headless SceneTree tests, GodotIQ.

---

## File structure

- Create `Scripts/Run/run_clan_selection.gd`: immutable validated selection.
- Modify `Scripts/Run/run_character_catalog.gd`: ordered playable clans and clan-filtered commander lookup.
- Create `Scripts/Save/world_run_save_codec_v6.gd`; modify `Scripts/Save/world_run_save_envelope.gd`: V6 selection persistence and V5 fallback.
- Modify `Scripts/Run/world_run_start_service.gd`, `Scripts/Run/world_production_launcher.gd`, and `Scenes/world_run_start.tscn`: direct launch UI and candidate flow.
- Create `Tests/Run/test_ac9_clan_selection.gd` and `Tests/Save/test_world_run_save_codec_v6.gd`.

### Task 1: Catalog-backed selection value

**Files:** Create `Scripts/Run/run_clan_selection.gd`; modify `Scripts/Run/run_character_catalog.gd`; test `Tests/Run/test_ac9_clan_selection.gd`.

- [ ] Write a failing test that expects stable playable clan order, each filtered commander to own its clan, a valid Orc/Goruk selection to succeed, and empty, unknown, and cross-clan pairs to fail.
- [ ] Run `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Run/test_ac9_clan_selection.gd`; expect nonzero because the new API/value is absent.
- [ ] Implement `get_playable_clans() -> Array[StringName]`, `get_player_commander_ids_for_clan(clan_id: StringName) -> Array[StringName]`, and `RunClanSelection.create(...) -> Dictionary`. The factory must use only `RunCharacterCatalog` and return `{ "ok", "value", "error" }`, never a partial selection.
- [ ] Re-run the focused test; validate and parser-check each changed script; commit `feat: add validated AC9 clan selection`.

### Task 2: V6 save contract

**Files:** Create `Scripts/Save/world_run_save_codec_v6.gd`; modify `Scripts/Save/world_run_save_envelope.gd`; test `Tests/Save/test_world_run_save_codec_v6.gd`.

- [ ] Write failing tests for V6 root fields `world.main_clan_id` and `world.commander_id`, a valid round trip, rejection of missing/unknown/cross-clan values, and unchanged V2–V5 decode through the V6 fallback.
- [ ] Run `godot.windows.opt.tools.64.exe --headless --path . --script res://Tests/Save/test_world_run_save_codec_v6.gd`; expect nonzero because V6 is absent.
- [ ] Implement V6 dispatch: parse `save_version == 6` through the envelope and otherwise call `WorldRunSaveCodecV5.decode_any`. Extend only V6 envelope encode/decode/strict key validation to require the two stable strings and validate them through `RunClanSelection`.
- [ ] Re-run V6 and V5 codec tests; validate/parser-check both scripts; commit `feat: persist clan selection in save v6`.

### Task 3: Direct launcher start

**Files:** Modify `Scripts/Run/world_run_start_service.gd`, `Scripts/Run/world_production_launcher.gd`, `Scenes/world_run_start.tscn`, and `Tests/Run/test_ac9_clan_selection.gd`.

- [ ] Write failing tests with a repository spy holding prior bytes: direct Start with an existing save performs one replacement and never returns `confirmation_required`; duplicate requests during flight do not re-run generation/replacement; generator, encoder, and store failures preserve the bytes exactly.
- [ ] Run the focused selection test; expect nonzero because confirmation is still shown.
- [ ] Change start service input to a validated `RunClanSelection` and return it with the candidate. Add a clan `OptionButton` to the New Run screen, filter/reset its commander carousel through catalog APIs, and pass selection to the V6 encoder/session. Add `_start_in_flight`, disable Begin during candidate generation/encode/replace, and reset it in all failure paths.
- [ ] Delete `Screen.OVERWRITE_CONFIRM`, pending seed/commander state, overwrite methods/references, `OverwriteDimmer`, `OverwriteCenter`, their descendants, and their two button signal connections. Continue remains load-only.
- [ ] Run focused tests, validate changed scripts and scene, `check_errors(scope="project")`, and `signal_map(find="orphans")`; commit `feat: start selected clan without confirmation`.

### Task 4: Acceptance verification

**Files:** Create `Docs/Specs/AC9/Evidence/AC9.1/` only after passing gates; update `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` only with supported evidence.

- [ ] Run AC9 selection, V6 codec, existing start-service, V5 codec, launcher/repository, and AC9.0 identity regressions; every process exits `0`.
- [ ] Run GodotIQ play verification, inspect the debug console, and inspect clan selection at 1152×648 and 1920×1080. Confirm filtered commander presentation and no modal after Start over an existing save.
- [ ] Store command output and capture references under the AC9.1 evidence directory; leave AC9.2/AC9.3 unchecked.
- [ ] Commit evidence with `docs: record AC9.1 verification evidence`.
