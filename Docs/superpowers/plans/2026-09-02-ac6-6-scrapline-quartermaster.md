# AC6.6 Scrapline Quartermaster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Brakka-only Cache accrual, a visible world-HUD progress indicator, and an atomic typed pre-Combat preparation transaction that survives save/reload without consuming Cache or applying a partial bonus on failure.

**Architecture:** `WorldRunState` persists independent Cache progress/readiness and exactly one canonical `BattlePreparationRecord`. `BattleSetupIdentity` snapshots immutable encounter/unit topology, `BattlePreparationTransaction` validates and commits against that identity, `WorldRuntimeController` persists state transitions before publishing battle mutation, and `BattleArena` owns only the locked preparation UI and idempotent battle-local application.

**Tech Stack:** Godot 4, typed GDScript, `RefCounted` domain objects, JSON V2 save envelope, scene-authored Control UI, SceneTree test runners, GodotIQ validation/runtime tools.

---

## Preconditions and Required Workflow

- Start from an updated `main`, create a dedicated `feat/ac6-6-scrapline-quartermaster` branch in the primary workspace, and do not use a worktree.
- Preserve the existing unrelated untracked `.tmp/`, AC6.5 screenshot import, and `.uid` files; never stage them with AC6.6.
- Before every `.gd` or `.tscn` edit, call `file_context(file, detail="brief")`.
- Before constructor, enum, public method, or signal changes, call `impact_check(file, action, target)`.
- Edit GDScript only through `script_ops`; edit `.tscn` files through `scene_map` plus `node_ops(validate=true)`/`build_scene`, then `save_scene()`.
- After each script change, run `validate(target=<file>, detail="brief")` and `check_errors(scope=<file>)` before proceeding.
- For the two scene changes, use `scene_map` → scene operation → `save_scene()` → `explore(mode="tour")`; fix issues and tour again.
- Every test runner must use a waited process and must exit zero with its explicit PASS line.

## Non-Negotiable Risk Invariants

| Risk | Required design invariant | Required proof |
|---|---|---|
| Ad hoc preparation dictionaries | `BattlePreparationRecord` is the only preparation representation; its `State` and `Choice` enums are canonical across run state, codec, controller, arena, and tests. | Record unit tests plus repository search showing no parallel `preparation_*` dictionaries. |
| Mutable/stale setup | `BattleSetupIdentity` captures encounter coordinate/type and ordered unit identity, side, slot, and active status; its canonical key is captured before offering and recomputed immediately before commit. | Transaction tests mutate target activity and formation after offer and require rejection. |
| Silent target redirect | Frontline Briefing validates the exact stored `target_unit_id` at commit; invalid targets fail without fallback selection. | A stale-target test asserts the alternate enemy remains untouched. |
| Non-atomic save/apply | Commit candidate stores `COMMITTED` plus Cache consumption; modifier application occurs only in the save coordinator's successful publish callback. Failed save retains durable `OFFERED`, Cache ready, locked battle, and zero modifier. | Runtime failure/retry/discard tests and reload-before/after-commit tests. |
| Safe/Boss leakage | A single `encounter_type == WorldEncounterType.COMBAT` gate precedes record creation and preparation UI. | Focused Safe/Boss tests assert record `NONE`, Cache ready, and no locked panel. |

## File and Responsibility Map

### New domain files

- `Scripts/Battle/battle_setup_identity.gd` — immutable snapshot and canonical comparison key for one initialized battle setup.
- `Scripts/Battle/battle_preparation_record.gd` — sole serialized preparation value with canonical `State` and `Choice` enums.
- `Scripts/Battle/battle_preparation_transaction.gd` — choice selection, cancellation policy, commit-time revalidation, and immutable commit output.
- `Scripts/Run/quartermaster_cache_rules.gd` — pure Brakka gating and accepted-move Cache transition rules.
- `Tests/Battle/test_ac6_6_battle_preparation.gd` — setup, record, transaction, stale-state, idempotency, and lock behavior.
- `Tests/Run/test_ac6_6_quartermaster_state.gd` — accrual, pause, encounter exclusion, save/reload, and runtime atomicity.

### Modified files

- `Scripts/Run/world_run_state.gd` — typed Cache fields and canonical preparation record serialization.
- `Scripts/Save/world_run_save_codec_v2.gd` — compatible V2 defaults and structured malformed-record rejection.
- `Scripts/WorldMap/world_runtime_controller.gd` — authoritative accrual, offer/commit persistence, retry publication, reload restoration, and Safe/Boss gate.
- `Scripts/UI/world_map_hud.gd` — Brakka-only `Cache n/4`/`Cache Ready` presentation.
- `Scripts/Battle/battle_arena.gd` — immutable setup exposure, preparation lock, UI state, and idempotent modifier application.
- `Scenes/world_map_hud.tscn` — top Cache label.
- `Scenes/battle_arena.tscn` — input-blocking preparation panel and controls.
- `Tests/Save/test_world_run_save_codec_v2.gd` — V2 compatibility and typed-record round trips.
- `Tests/WorldMap/test_world_battle_entry.gd` — no-Cache regression and required-preparation battle entry.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — mark AC6.6 only after all gates pass.
- `Docs/Races/Goblins/Commanders.md` — update implementation status after evidence passes.
- `Docs/Specs/AC6/Evidence/AC6.6/2026-09-02/manual-runtime-check.md` — production evidence and AC6.7 boundary.

## Task 1: Establish the canonical preparation record and immutable setup identity

**Files:**

- Create: `Scripts/Battle/battle_setup_identity.gd`
- Create: `Scripts/Battle/battle_preparation_record.gd`
- Create: `Tests/Battle/test_ac6_6_battle_preparation.gd`

- [ ] **Step 1: Write the RED record/identity runner**

Create a waited `SceneTree` runner that dynamically loads the missing scripts and then exercises these exact contracts:

```gdscript
const SETUP_PATH := "res://Scripts/Battle/battle_setup_identity.gd"
const RECORD_PATH := "res://Scripts/Battle/battle_preparation_record.gd"

func _test_record_contract(record_script: GDScript) -> void:
	var none: RefCounted = record_script.none()
	_expect(none.get("state") == record_script.State.NONE, "default record is NONE")
	var offered: RefCounted = record_script.offered(
		&"prep-1", Vector2i(2, -1), WorldEncounterType.COMBAT, "setup-a"
	)
	_expect(is_instance_valid(offered), "valid offered record constructs")
	_expect(offered.call("to_dictionary")["state"] == "offered", "state serializes canonically")
	_expect(record_script.from_dictionary(offered.call("to_dictionary")).get("ok", false), "record round trips")
	_expect(not record_script.from_dictionary({"state": "unknown"}).get("ok", true), "unknown state rejects")
	_expect(not record_script.committed(
		&"prep-1", Vector2i(2, -1), WorldEncounterType.COMBAT,
		"setup-a", record_script.Choice.FRONTLINE_BRIEFING, &""
	), "briefing requires exact target")
```

Build two setup snapshots from the same units and assert equal keys; change one unit's `slot_index` or active state and assert a different key. Also assert the constructor duplicates input data so later caller mutation cannot change the stored key.

- [ ] **Step 2: Run RED**

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac6_6_battle_preparation.gd
```

Expected: nonzero exit because both canonical scripts are missing.

- [ ] **Step 3: Implement `BattleSetupIdentity`**

Create a typed `RefCounted` with no mutating public setters:

```gdscript
class_name BattleSetupIdentity
extends RefCounted

var encounter_coord: Vector2i
var encounter_type: String
var unit_rows: Array[Dictionary] = []
var canonical_key: String = ""

static func capture(coord: Vector2i, type: String, units: Array[BattleUnitState]) -> BattleSetupIdentity:
	var normalized_type := type.to_lower()
	if normalized_type != WorldEncounterType.COMBAT:
		return null
	var seen: Dictionary[StringName, bool] = {}
	var rows: Array[Dictionary] = []
	for unit: BattleUnitState in units:
		if not is_instance_valid(unit) or unit.unit_id.is_empty() or seen.has(unit.unit_id):
			return null
		seen[unit.unit_id] = true
		rows.append({
			"unit_id": String(unit.unit_id),
			"side": int(unit.side),
			"slot_index": unit.slot_index,
			"active": unit.is_active(),
		})
	rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_key := "%d:%02d:%s" % [left["side"], left["slot_index"], left["unit_id"]]
		var right_key := "%d:%02d:%s" % [right["side"], right["slot_index"], right["unit_id"]]
		return left_key < right_key
	)
	var identity := BattleSetupIdentity.new()
	identity.encounter_coord = coord
	identity.encounter_type = normalized_type
	identity.unit_rows = rows.duplicate(true)
	identity.canonical_key = JSON.stringify(identity.to_dictionary()).sha256_text()
	return identity

func to_dictionary() -> Dictionary:
	return {
		"encounter_coord": [encounter_coord.x, encounter_coord.y],
		"encounter_type": encounter_type,
		"units": unit_rows.duplicate(true),
	}

func matches(other: BattleSetupIdentity) -> bool:
	return is_instance_valid(other) and canonical_key == other.canonical_key
```

The implementation must store only copied scalar row values. Never retain unit references in the identity.

- [ ] **Step 4: Implement the sole `BattlePreparationRecord` state machine**

Use these canonical enums and fields everywhere:

```gdscript
class_name BattlePreparationRecord
extends RefCounted

enum State { NONE, OFFERED, COMMITTED }
enum Choice { NONE, FRONTLINE_BRIEFING, SPARE_PLATING }

var state: State = State.NONE
var preparation_id: StringName = &""
var encounter_coord: Vector2i = Vector2i.ZERO
var encounter_type: String = ""
var setup_key: String = ""
var choice: Choice = Choice.NONE
var target_unit_id: StringName = &""
```

Provide `none()`, `offered(...)`, `committed(...)`, `is_valid()`, `to_dictionary()`, and `from_dictionary()`; serialize enum values as `none|offered|committed` and `none|frontline_briefing|spare_plating`. `NONE` must contain no transaction payload. `OFFERED` requires regular Combat, nonempty ID/key, `Choice.NONE`, and no target. `COMMITTED` requires a real choice; Frontline Briefing requires a target and Spare Plating forbids one.

- [ ] **Step 5: Run GREEN and validate**

Expected: `PASS test_ac6_6_battle_preparation`. Then run per-file GodotIQ validation/error checks for both new scripts.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_setup_identity.gd Scripts/Battle/battle_preparation_record.gd Tests/Battle/test_ac6_6_battle_preparation.gd
git commit -m "feat: add canonical battle preparation state"
```

## Task 2: Persist Brakka Cache state and the canonical record

**Files:**

- Create: `Scripts/Run/quartermaster_cache_rules.gd`
- Create: `Tests/Run/test_ac6_6_quartermaster_state.gd`
- Modify: `Scripts/Run/world_run_state.gd`
- Modify: `Scripts/Save/world_run_save_codec_v2.gd`
- Modify: `Tests/Save/test_world_run_save_codec_v2.gd`

- [ ] **Step 1: Extend the RED tests**

Add exact assertions for this pure API:

```gdscript
var state: Dictionary = QuartermasterCacheRules.after_accepted_move(
	&"brakka_rustbanner", 3, false
)
_expect(state == {"progress": 0, "ready": true}, "fourth accepted move fills Cache")
_expect(
	QuartermasterCacheRules.after_accepted_move(&"brakka_rustbanner", 0, true)
	== {"progress": 0, "ready": true},
	"ready Cache freezes progress"
)
_expect(
	QuartermasterCacheRules.after_accepted_move(&"other", 2, false)
	== {"progress": 2, "ready": false},
	"non-Brakka run does not accrue"
)
```

Extend the save runner to assert missing V2 fields decode to zero/not-ready/NONE; valid offered and committed records round-trip; out-of-range progress, unknown state, committed briefing without target, and Safe/Boss preparation records return `SAVE_ENVELOPE_INVALID` with constraint `run_state`.

- [ ] **Step 2: Run both RED runners**

```powershell
godot --headless --path . --script res://Tests/Run/test_ac6_6_quartermaster_state.gd
godot --headless --path . --script res://Tests/Save/test_world_run_save_codec_v2.gd
```

Expected: failures for the missing rules API and missing run-state fields/defaults.

- [ ] **Step 3: Implement pure Cache rules**

Create only these transitions:

```gdscript
class_name QuartermasterCacheRules
extends RefCounted

const BRAKKA_ID := &"brakka_rustbanner"
const MOVES_PER_CACHE := 4

static func after_accepted_move(
	commander_id: StringName, progress: int, ready: bool
) -> Dictionary:
	if commander_id != BRAKKA_ID or ready:
		return {"progress": progress, "ready": ready}
	var next_progress := progress + 1
	return (
		{"progress": 0, "ready": true}
		if next_progress >= MOVES_PER_CACHE
		else {"progress": next_progress, "ready": false}
	)
```

Do not read or change `move_count`, movement range, reveal data, or encounter generation here.

- [ ] **Step 4: Extend `WorldRunState` with typed fields**

Add `cache_move_progress: int`, `cache_ready: bool`, and `battle_preparation: BattlePreparationRecord`. Extend `create(...)` with typed/defaulted parameters at the end to retain callers, enforce `0..3`, and require `battle_preparation.is_valid()`.

Compatibility rule in `from_dictionary()`:

```gdscript
var progress := int(value.get("cache_move_progress", 0))
var ready := bool(value.get("cache_ready", false))
var preparation_result := BattlePreparationRecord.from_dictionary(
	value.get("battle_preparation", {"state": "none"})
)
```

Reject inconsistent combinations: `OFFERED` requires `cache_ready == true`; `COMMITTED` requires `cache_ready == false`; `NONE` permits either. Include all three fields in `to_dictionary()` and therefore `canonical_key()`.

- [ ] **Step 5: Keep V2 envelope compatibility explicit**

Do not bump `SAVE_VERSION`. Let `WorldRunState.from_dictionary()` supply defaults for older V2 state dictionaries and return `{ "ok": false }` for malformed typed state so `_decode_v2()` continues returning the structured `SAVE_ENVELOPE_INVALID/run_state` failure.

- [ ] **Step 6: Run GREEN, regression, and validate**

Run both focused runners and the existing world save-coordinator runner. Expected: all explicit PASS lines and zero parser errors.

- [ ] **Step 7: Commit**

```powershell
git add Scripts/Run/quartermaster_cache_rules.gd Scripts/Run/world_run_state.gd Scripts/Save/world_run_save_codec_v2.gd Tests/Run/test_ac6_6_quartermaster_state.gd Tests/Save/test_world_run_save_codec_v2.gd
git commit -m "feat: persist Scrapline Quartermaster Cache"
```

## Task 3: Implement commit-time preparation validation and idempotent application

**Files:**

- Create: `Scripts/Battle/battle_preparation_transaction.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac6_6_battle_preparation.gd`

- [ ] **Step 1: Add RED transaction cases**

Test the exact API:

```gdscript
var tx := BattlePreparationTransaction.begin(offered_record, offered_identity)
_expect(not tx.cancel(), "required preparation rejects cancellation")
_expect(tx.select_choice(BattlePreparationRecord.Choice.FRONTLINE_BRIEFING), "briefing selects")
_expect(tx.select_target(&"enemy_a"), "active enemy selects")
var committed: Dictionary = tx.commit(BattleSetupIdentity.capture(coord, "combat", units), units)
_expect(committed.get("ok", false), "matching setup commits")
```

Then mutate `enemy_a.current_hp = 0` and assert commit fails, `enemy_b` receives no Advantage, and no redirect occurs. Move a frontline ally after offer and assert setup mismatch. Cover allied/missing target, Spare Plating, repeated commit, and wrong encounter.

- [ ] **Step 2: Run RED**

Expected: nonzero exit because the transaction script and arena preparation API do not exist.

- [ ] **Step 3: Implement the transaction as validation only**

`BattlePreparationTransaction` stores the offered record, captured setup key, choice, and exact target ID. `commit(current_identity, units)` must:

1. require an uncommitted offered transaction;
2. require `current_identity.canonical_key == offered.setup_key`;
3. for Frontline Briefing, locate only `target_unit_id`, then require enemy side and `is_active()`;
4. for Spare Plating, require at least one active player unit in canonical frontline slots;
5. return a new canonical committed record plus resolved IDs without mutating units;
6. mark itself committed only after producing that result.

Return `{ "ok": false, "reason": <stable StringName> }` on failure. Never choose a fallback target.

- [ ] **Step 4: Add narrow idempotent arena APIs**

Add these public boundaries to `BattleArena`:

```gdscript
func get_setup_identity() -> BattleSetupIdentity
func configure_preparation(record: BattlePreparationRecord) -> bool
func apply_committed_preparation(record: BattlePreparationRecord) -> bool
func is_preparation_required() -> bool
func is_battle_input_locked() -> bool
```

`apply_committed_preparation()` must recompute identity first, reject mismatches, check `_applied_preparation_ids`, and then apply exactly one effect:

- Frontline Briefing calls `target.apply_advantage(source, 1)` on the exact active enemy ID.
- Spare Plating calls `add_armor(2)` on each active player unit in canonical frontline slots.

Record the preparation ID only after all preconditions pass. Do not partially mutate while validating.

- [ ] **Step 5: Run GREEN and existing Armor/Advantage regressions**

Expected: preparation, AC6.2 keyword, and AC6.5 Brakka runners pass.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_preparation_transaction.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac6_6_battle_preparation.gd
git commit -m "feat: validate and apply battle preparation"
```

## Task 4: Add the Brakka-only world HUD indicator

**Files:**

- Modify: `Scenes/world_map_hud.tscn`
- Modify: `Scripts/UI/world_map_hud.gd`
- Modify: `Scripts/WorldMap/world_runtime_controller.gd`
- Modify: `Tests/Run/test_ac6_6_quartermaster_state.gd`

- [ ] **Step 1: Add RED HUD assertions**

Instantiate the HUD scene and require:

```gdscript
hud.set_cache_state(true, 0, false)
_expect(cache_label.visible and cache_label.text == "Cache 0/4", "Brakka sees empty progress")
hud.set_cache_state(true, 3, false)
_expect(cache_label.text == "Cache 3/4", "Brakka sees progress")
hud.set_cache_state(true, 0, true)
_expect(cache_label.text == "Cache Ready", "ready state is explicit")
hud.set_cache_state(false, 0, false)
_expect(not cache_label.visible, "non-Brakka run hides Cache")
```

- [ ] **Step 2: Run RED**

Expected: missing `%CacheStatusLabel`/`set_cache_state` failure.

- [ ] **Step 3: Build the scene-authored top label**

Use `scene_map(scene="res://Scenes/world_map_hud.tscn", focus=".", radius=3, detail="brief")`, then add one unique-name `Label` named `CacheStatusLabel` inside the existing top status layout. Do not create the label in code. Save and validate the scene.

- [ ] **Step 4: Implement presentation and controller feed**

Add:

```gdscript
func set_cache_state(has_brakka: bool, progress: int, ready: bool) -> void:
	_cache_status_label.visible = has_brakka
	if not has_brakka:
		return
	_cache_status_label.text = "Cache Ready" if ready else "Cache %d/4" % progress
```

In `_apply_snapshot()`, derive `has_brakka` from `_roster.has_character(GoblinCommanderCatalog.BRAKKA_ID)` and feed only the durable Cache fields. Do not derive progress from `snapshot.move_count`.

- [ ] **Step 5: Run GREEN and visual QA**

Run the focused state/UI runner, save the scene, play the production world, tour the HUD at 0/4 and Ready, and confirm the label remains top-aligned without overlapping move/boss status.

- [ ] **Step 6: Commit**

```powershell
git add Scenes/world_map_hud.tscn Scripts/UI/world_map_hud.gd Scripts/WorldMap/world_runtime_controller.gd Tests/Run/test_ac6_6_quartermaster_state.gd
git commit -m "feat: show Quartermaster Cache progress"
```

## Task 5: Build the locked preparation panel and target interaction

**Files:**

- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac6_6_battle_preparation.gd`

- [ ] **Step 1: Add RED scene/input-lock tests**

Require unique nodes `%PreparationBlocker`, `%FrontlineBriefingButton`, `%SparePlatingButton`, `%PreparationMessageLabel`, and `%PreparationConfirmButton`. Configure an offered record and assert the blocker is visible; all action/debug buttons are disabled; enemy selection is restricted to active enemy slots; confirm stays disabled until the choice is valid; cancel/escape does not close the panel.

- [ ] **Step 2: Run RED**

Expected: missing preparation nodes and lock behavior.

- [ ] **Step 3: Build the scene panel**

Use `scene_map` focused on the battle root and existing action region. Add a full-rect input-blocking `Control` with a centered `PanelContainer`, title, explanatory copy, two choice buttons, message label, and confirm button. Keep it hidden by default and above battle controls. Connect buttons through the scene to typed arena handlers.

- [ ] **Step 4: Centralize the action lock**

Introduce one `_is_action_input_allowed()` predicate that requires battle incomplete, no action in progress, and preparation not required. Route Default Attack, Default Swap/formation movement, skill begin/confirm, advance/debug damage, and turn advancement through it. Refresh every affected button from the same predicate.

- [ ] **Step 5: Wire transaction-driven selection**

Choice handlers update the transaction only. Enemy slot presses pass the exact unit ID. Confirm calls a signal such as:

```gdscript
signal preparation_commit_requested(
	choice: BattlePreparationRecord.Choice,
	target_unit_id: StringName,
	expected_setup_key: String
)
```

The arena must not consume Cache in this handler. It remains locked until the controller publishes a committed record back through `apply_committed_preparation()`.

- [ ] **Step 6: Run GREEN, validate, and tour**

Expected: focused preparation tests pass; existing battle action tests remain green; visual tour shows a readable blocking panel and selectable enemy feedback.

- [ ] **Step 7: Commit**

```powershell
git add Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Tests/Battle/test_ac6_6_battle_preparation.gd
git commit -m "feat: add pre-battle preparation UI"
```

## Task 6: Orchestrate atomic accrual, commit, retry, and reload

**Files:**

- Modify: `Scripts/WorldMap/world_runtime_controller.gd`
- Modify: `Tests/Run/test_ac6_6_quartermaster_state.gd`
- Modify: `Tests/WorldMap/test_world_battle_entry.gd`

- [ ] **Step 1: Add RED production-boundary tests**

Cover these scenarios with a fake repository that can fail `replace_atomic()`:

1. A Brakka fourth accepted move persists Ready before the Combat overlay opens.
2. On regular Combat request, the controller captures setup identity and persists `OFFERED` before enabling the prompt.
3. A valid commit persists `COMMITTED` plus `cache_ready == false`; only the publish callback applies the modifier and unlocks battle.
4. Failed commit save leaves durable `OFFERED`, Cache ready, battle locked, and all units unchanged.
5. Retry success publishes exactly one modifier; discard restores offered state and remains locked.
6. Reload of `OFFERED` recreates the matching locked battle/prompt.
7. Reload of `COMMITTED` recreates the battle, reapplies once, and unlocks.
8. Safe and Boss requests leave record `NONE`, Cache ready, and preparation UI absent.

- [ ] **Step 2: Run RED**

Run both focused AC6.6 runners and `test_world_battle_entry.gd`. Expected: new orchestration assertions fail.

- [ ] **Step 3: Accrue Cache in the accepted-move candidate**

In `request_move()`, after `create_move_candidate()` reports an accepted result but before `commit_candidate()`, clone the durable data and apply `QuartermasterCacheRules.after_accepted_move()` only when the roster contains Brakka. Store the result in the same candidate state as the accepted move so the fourth-move boundary is atomic and immediately visible to encounter processing.

- [ ] **Step 4: Gate preparation before record creation**

In `_on_battle_requested()`, normalize once and branch first:

```gdscript
var requires_preparation := (
	normalized_encounter == WorldEncounterType.COMBAT
	and is_instance_valid(_durable_run_state)
	and bool(_durable_run_state.get("cache_ready"))
	and _roster.has_character(GoblinCommanderCatalog.BRAKKA_ID)
)
```

Only that branch may capture a setup identity or create `OFFERED`. Safe and Boss flow directly through the existing unlocked battle path and must not alter Cache.

- [ ] **Step 5: Persist before publishing mutation**

For offer, save a candidate containing the canonical `OFFERED` record, then publish it by configuring the already-created arena with the prompt. For commit, validate the exact current identity and target, build a candidate with `cache_ready = false` and canonical `COMMITTED`, and call `commit_candidate()` with a publish callback that:

1. updates `_durable_run_state`;
2. passes the committed record to `BattleArena.apply_committed_preparation()`;
3. unlocks only on successful matching application;
4. leaves the committed record durable until battle cleanup.

Never apply a bonus before `replace_atomic()` succeeds.

- [ ] **Step 6: Restore offered/committed records on session load**

After roster/model/persistence restoration, inspect the canonical record. `OFFERED` recreates the deterministic Combat and prompt using the stored coordinate/setup key. `COMMITTED` recreates that Combat, verifies the same setup key, idempotently applies the stored bonus, and unlocks. Any mismatch fails closed with world/battle input blocked and a diagnostic; it must not clear or reinterpret the record.

- [ ] **Step 7: Clear only after safe battle exit**

During `_on_battle_closed()`, include `BattlePreparationRecord.none()` in the same authoritative encounter-resolution candidate that consumes the encounter. Do not clear on panel interaction, battle scene creation, failed save, or transient reload.

- [ ] **Step 8: Run GREEN and affected regression suite**

Run:

```powershell
godot --headless --path . --script res://Tests/Run/test_ac6_6_quartermaster_state.gd
godot --headless --path . --script res://Tests/Battle/test_ac6_6_battle_preparation.gd
godot --headless --path . --script res://Tests/WorldMap/test_world_battle_entry.gd
godot --headless --path . --script res://Tests/Save/test_world_run_save_codec_v2.gd
godot --headless --path . --script res://Tests/Run/test_world_cutover_entry.gd
```

Expected: every runner exits zero with its PASS line.

- [ ] **Step 9: Commit**

```powershell
git add Scripts/WorldMap/world_runtime_controller.gd Tests/Run/test_ac6_6_quartermaster_state.gd Tests/WorldMap/test_world_battle_entry.gd
git commit -m "feat: integrate atomic Quartermaster preparation"
```

## Task 7: Complete project verification and AC6.6 evidence

**Files:**

- Create: `Docs/Specs/AC6/Evidence/AC6.6/2026-09-02/manual-runtime-check.md`
- Create: `Docs/Specs/AC6/Evidence/AC6.6/2026-09-02/green/*.log`
- Create: `Docs/Specs/AC6/Evidence/AC6.6/2026-09-02/screenshots/*.png`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Modify: `Docs/Races/Goblins/Commanders.md`

- [ ] **Step 1: Run the full affected automated gate**

Run every focused runner from Tasks 1–6 plus existing tests covering world movement/model, save coordinator/repository, battle entry, action lock, Armor, Advantage, Brakka, and world cutover. Capture complete stdout/stderr and exit codes in `green/`.

- [ ] **Step 2: Run the GodotIQ project gate**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
verify_project_runs(scene="main", check_scope="project", stop_after=false)
```

Expected: zero new convention errors, zero parser/script errors, no preparation-signal orphans, clean startup, and no runtime errors.

- [ ] **Step 3: Execute the production runtime walkthrough**

Using production entry points and GodotIQ runtime/UI inspection:

1. Start a Brakka run and record `Cache 0/4` at the top HUD.
2. Complete three accepted moves and record `Cache 3/4`; prove a rejected move does not change it.
3. Make the fourth accepted move enter Combat and record `Cache Ready` plus the locked preparation panel.
4. Prove Default Attack, movement, skills, turn advance, and debug mutation cannot run while locked.
5. Choose Frontline Briefing, select an active enemy, commit, and record exact Advantage target/log state.
6. Reload an offered preparation and prove Cache remains ready and the prompt reopens.
7. Reload a committed preparation and prove the bonus exists once and battle is unlocked.
8. Exercise the failed-save path and prove Cache remains ready, units unchanged, and battle locked until retry.
9. Accrue a second Cache from four new accepted moves, choose Spare Plating, and record `+2 Armor` only on active frontline allies.
10. While Cache is ready, cross a Safe encounter and a Boss encounter; record unchanged Cache and absence of the preparation panel.
11. Read the debug console, record zero new errors, and stop Play.

- [ ] **Step 4: Record evidence and update status narrowly**

The manual record must include commands, commit SHA, PASS lines, screenshots, inspected state values, save/reload checkpoints, and explicit results for all five risk invariants. Mark AC6.6 complete only if every gate passes. Leave AC6.7 and aggregate AC6 incomplete.

- [ ] **Step 5: Final self-review**

Search the implementation for preparation state represented outside `BattlePreparationRecord`, verify every comparison uses `BattleSetupIdentity.canonical_key`, and confirm the Safe/Boss gate precedes `BattlePreparationRecord.offered()`. Run `git diff --check` and confirm only AC6.6 files are staged.

- [ ] **Step 6: Commit**

```powershell
git add Docs/Specs/AC6/Evidence/AC6.6 Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Races/Goblins/Commanders.md
git commit -m "docs: evidence AC6.6 Quartermaster flow"
```

## Plan Self-Review Results

- **Spec coverage:** Every approved rule maps to Tasks 1–7; Cache cadence/pausing is Task 2/6, HUD is Task 4, both choices and action lock are Tasks 3/5, atomic durability is Task 6, and evidence is Task 7.
- **Canonical type:** One `BattlePreparationRecord` and its two enums are named as the sole representation. No controller/arena dictionary state is permitted.
- **Staleness:** Immutable scalar setup snapshots and commit-time key comparison are required, including exact target revalidation and no redirect.
- **Atomicity:** Save success precedes modifier publication; failed saves retain offered state, ready Cache, locked battle, and unchanged units.
- **Encounter exclusion:** The regular-Combat gate is specified before record creation and has focused Safe/Boss tests.
- **Compatibility:** Existing V2 saves receive explicit defaults without a version bump; malformed new fields fail through the existing structured error.
- **Type consistency:** `BattlePreparationRecord.State`, `BattlePreparationRecord.Choice`, `BattleSetupIdentity.canonical_key`, and arena/controller signatures use the same names throughout all tasks.
- **Scope:** AC6.7 integration, rewards, progression, and unrelated refactors remain outside this plan.
