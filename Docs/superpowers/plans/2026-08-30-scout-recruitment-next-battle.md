# Scout Recruitment Next-Battle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Scout recruitment placement visible above the production battle, persist the staged roster atomically, and include Scout in the next battle.

**Architecture:** The immediate defect is scene composition: production `BattleHost` renders on canvas layer 20 while `PartyHost` renders below it on UI layer 10. Promote `PartyHost` to a higher canvas layer, then make `WorldRuntimeController` stage recruitment in a candidate `RunRoster` whose save callback publishes the roster and completes the reward together.

**Tech Stack:** Godot 4.7, typed GDScript, GodotIQ scene/script operations, headless `SceneTree` contract tests.

---

## File Map

- Modify `Scenes/world_map_runtime.tscn`: make `PartyHost` a `CanvasLayer` above `BattleHost` so recruitment placement is visible and interactive.
- Modify `Scenes/world_map_runtime_preview.tscn`: mirror host types/layers so preview integration tests exercise production composition.
- Create `Tests/WorldMap/test_scout_recruitment_flow.gd`: reproduce the hidden-placement bug and cover idempotency, cancellation, stale identity, save failure/retry, and next-battle units.
- Modify `Scripts/WorldMap/world_runtime_controller.gd`: add explicit recruitment lifecycle state, candidate-roster persistence, idempotent signal handling, and atomic publish/completion.
- Keep `Scripts/Battle/battle_arena.gd`, `Scripts/Party/party_management.gd`, and `Scripts/Run/run_roster.gd` unchanged; their existing reward, placement, and snapshot APIs already provide the required boundaries.

### Task 1: Reproduce and Fix Production Placement Visibility

**Files:**
- Create: `Tests/WorldMap/test_scout_recruitment_flow.gd`
- Modify: `Scenes/world_map_runtime.tscn`
- Modify: `Scenes/world_map_runtime_preview.tscn`

- [ ] **Step 1: Create the failing visibility test**

Create `Tests/WorldMap/test_scout_recruitment_flow.gd` through `godotiq_script_ops(op="create")`. The first test must instantiate `res://Scenes/world_map_runtime.tscn`, invoke `_on_battle_requested(Vector2i.ZERO, "combat")`, complete the battle as victory, select `combat_recruit_scout`, confirm it, and assert:

```gdscript
class_name ScoutRecruitmentFlowTests
extends SceneTree

const RUNTIME_SCENE := "res://Scenes/world_map_runtime.tscn"
const SCOUT_REWARD_ID := &"combat_recruit_scout"

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(RUNTIME_SCENE) as PackedScene
	var runtime := packed.instantiate() as WorldRuntimeController
	runtime.auto_initialize_runtime = false
	root.add_child(runtime)
	await process_frame
	runtime.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
	var battle := runtime.get_node("BattleHost").get_child(0) as BattleArena
	battle.call("_complete_battle", BattleOutcome.Type.VICTORY)
	battle.select_reward(SCOUT_REWARD_ID)
	battle.confirm_reward_selection()
	await process_frame
	var party_host := runtime.get_node("PartyHost")
	var battle_host := runtime.get_node("BattleHost") as CanvasLayer
	_expect(party_host is CanvasLayer, "production PartyHost owns a dedicated canvas layer")
	_expect(
		party_host is CanvasLayer and (party_host as CanvasLayer).layer > battle_host.layer,
		"recruitment placement renders above the active battle"
	)
	_expect(party_host.get_child_count() == 1, "one recruitment placement screen opens")
	runtime.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Scout recruitment flow tests: PASS (%d/%d)" % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://Tests/WorldMap/test_scout_recruitment_flow.gd
```

Expected: FAIL because production `PartyHost` is a plain `Node` below `BattleHost` canvas layer 20, even though it owns one `PartyManagement` child.

- [ ] **Step 3: Promote both PartyHost nodes through GodotIQ**

For each runtime scene, use `scene_map(..., focus="PartyHost", detail="brief")`, then one `node_ops` batch to delete the empty `PartyHost` and add a root child with the same name:

```json
[
  {"op":"delete","node":"PartyHost"},
  {"op":"add_child","parent":".","type":"CanvasLayer","name":"PartyHost","properties":{"layer":30}}
]
```

Run against `Scenes/world_map_runtime.tscn` and `Scenes/world_map_runtime_preview.tscn`, then call `save_scene()` after each. Keep `BattleHost` at layer 20.

- [ ] **Step 4: Verify GREEN and scene structure**

Run the focused test again. Expected: PASS. Then run:

```text
godotiq_validate(target="res://Scenes/world_map_runtime.tscn", detail="brief")
godotiq_validate(target="res://Scenes/world_map_runtime_preview.tscn", detail="brief")
godotiq_check_errors(scope="scene")
```

Use `scene_map(..., focus="PartyHost", detail="normal")` to confirm both hosts are `CanvasLayer` with `layer = 30`.

- [ ] **Step 5: Commit the visibility fix**

```powershell
git add -- Tests/WorldMap/test_scout_recruitment_flow.gd Tests/WorldMap/test_scout_recruitment_flow.gd.uid Scenes/world_map_runtime.tscn Scenes/world_map_runtime_preview.tscn
git commit -m "fix: show recruitment placement above battle"
```

### Task 2: Add Recruitment Transaction Regression Coverage

**Files:**
- Modify: `Tests/WorldMap/test_scout_recruitment_flow.gd`

- [ ] **Step 1: Extend the test with explicit lifecycle assertions**

Add helpers that start a victory recruitment flow and inspect controller state. Add assertions for these exact behaviors:

```gdscript
_expect(
	int(runtime.call("get_recruitment_state"))
		== WorldRuntimeController.RecruitmentState.PLACEMENT_OPEN,
	"Scout confirmation enters placement_open"
)
var first_party := runtime.get_node("PartyHost").get_child(0)
runtime.call("_on_recruitment_placement_requested", battle.get_selected_reward())
_expect(runtime.get_node("PartyHost").get_child_count() == 1, "duplicate request opens no second placement")
_expect(runtime.get_node("PartyHost").get_child(0) == first_party, "duplicate request preserves placement identity")
_expect(
	(runtime.get("_pending_recruit") as RunCharacter).character_id == &"scout",
	"duplicate request preserves one Scout identity"
)
```

Exercise `placement_cancelled.emit()` and assert the state returns to `REWARD_SELECTED`, PartyHost is empty, the battle remains active, and `battle.get_selected_reward().reward_id == SCOUT_REWARD_ID`. Confirm again and assert one fresh placement session opens.

For a full roster fixture, emit replacement with a wrong occupant ID and wrong recruit ID and assert the live formation and lifecycle state are unchanged. Then emit valid identities and assert only the candidate roster changes before save publication.

- [ ] **Step 2: Add a deterministic failing repository**

Add this test double to the test script and configure the runtime through its existing `apply_session(session, repository)` boundary:

```gdscript
class FailingOnceRepository:
	extends RefCounted

	var _attempts: int = 0
	var _bytes: PackedByteArray = PackedByteArray()

	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		_attempts += 1
		if _attempts == 1:
			return {"ok": false, "value": null, "error": WorldSaveError.new("forced", "forced save failure")}
		_bytes = bytes.duplicate()
		return {"ok": true, "value": null, "error": null}

	func load_bytes() -> Dictionary:
		return {"ok": not _bytes.is_empty(), "value": _bytes.duplicate(), "error": null}
```

Use the same generated plan/run-state session fixture as `Tests/WorldMap/test_world_runtime_save_coordinator.gd`; copy its complete fixture construction rather than mocking `WorldRuntimeSaveCoordinator`.

- [ ] **Step 3: Assert failure and retry atomicity**

After valid Scout placement against `FailingOnceRepository`, assert:

```gdscript
_expect(runtime.call("is_autosave_blocked"), "failed recruitment save blocks repeated placement input")
_expect(
	int(runtime.call("get_recruitment_state")) == WorldRuntimeController.RecruitmentState.SAVE_FAILED,
	"failed recruitment save enters save_failed"
)
_expect(not (runtime.get("_roster") as RunRoster).has_character(&"scout"), "failed save does not publish Scout")
_expect(runtime.call("has_active_battle"), "failed save keeps battle open")
_expect(runtime.call("has_active_party_management"), "failed save keeps the same placement screen alive")
```

Capture the party instance and pending recruit instance, call `retry_autosave()`, then assert retry succeeds, both identities were reused, the state is `REWARD_COMPLETED`, the live roster contains Scout once, durable formation contains `"scout"` once, and the battle/placement screens close.

Open a second battle through `_on_battle_requested(...)`, obtain its `BattleArena.get_turn_queue()`, and assert exactly one player unit has `unit_id == &"scout"`. This verifies `RunRoster.create_battle_units()` output rather than UI text.

- [ ] **Step 4: Run the expanded test and verify RED**

Run the focused test. Expected: FAIL because the controller has no explicit lifecycle getter and mutates `_roster` before save succeeds.

- [ ] **Step 5: Commit the failing transaction tests**

```powershell
git add -- Tests/WorldMap/test_scout_recruitment_flow.gd Tests/WorldMap/test_scout_recruitment_flow.gd.uid
git commit -m "test: cover Scout recruitment transaction"
```

### Task 3: Implement Atomic Recruitment State in the Runtime Controller

**Files:**
- Modify: `Scripts/WorldMap/world_runtime_controller.gd`

- [ ] **Step 1: Run mandatory pre-edit checks**

```text
godotiq_file_context(file="res://Scripts/WorldMap/world_runtime_controller.gd", detail="brief")
godotiq_impact_check(file="res://Scripts/WorldMap/world_runtime_controller.gd", action="modify_function", target="_on_recruitment_placement_requested", change_description="Add idempotent recruitment lifecycle and candidate-roster publication", detail="brief")
godotiq_validate(target="project", detail="brief")
```

- [ ] **Step 2: Add lifecycle and candidate state**

Patch the controller through `godotiq_script_ops(op="patch")` with:

```gdscript
enum RecruitmentState {
	IDLE,
	REWARD_SELECTED,
	RECRUITMENT_PENDING,
	PLACEMENT_OPEN,
	PLACEMENT_CONFIRMED,
	PLACEMENT_CANCELLED,
	SAVE_FAILED,
	REWARD_COMPLETED,
}

var _recruitment_state: RecruitmentState = RecruitmentState.IDLE
var _pending_recruitment_roster: RunRoster


func get_recruitment_state() -> RecruitmentState:
	return _recruitment_state
```

- [ ] **Step 3: Make placement creation idempotent**

At the start of `_on_recruitment_placement_requested`, accept only `IDLE` or `REWARD_SELECTED`. Transition through `RECRUITMENT_PENDING`, create the recruit once, create exactly one `PartyManagement`, then set `PLACEMENT_OPEN`. On invalid or duplicate recruit, restore the battle reward and reset to `REWARD_SELECTED` without creating a party instance.

Connect both recruitment-mode close signals to `_on_recruitment_cancelled`:

```gdscript
_active_party.placement_cancelled.connect(_on_recruitment_cancelled)
_active_party.close_requested.connect(_on_recruitment_cancelled)
```

- [ ] **Step 4: Stage add/replacement on a candidate roster**

Replace direct mutations of `_roster` in both recruitment handlers with:

```gdscript
var candidate := RunRoster.new(_roster.get_slot_snapshot())
var result := candidate.try_add_at(_pending_recruit, destination_slot)
if result != RunRoster.AddResult.ADDED:
	return
_commit_recruitment_candidate(candidate)
```

For replacement, call `candidate.try_replace_at(...)` and proceed only on `RunRoster.ReplaceResult.REPLACED`. Both handlers must first require `PLACEMENT_OPEN`, matching pending recruit identity, and `not is_autosave_blocked()`.

- [ ] **Step 5: Persist and publish through one callback**

Add:

```gdscript
func _commit_recruitment_candidate(candidate: RunRoster) -> void:
	_recruitment_state = RecruitmentState.PLACEMENT_CONFIRMED
	_pending_recruitment_roster = candidate
	if not is_instance_valid(_save_coordinator):
		_publish_recruitment_state(_build_candidate_state(_model, false, candidate))
		return
	var candidate_state := _build_candidate_state(_model, false, candidate)
	var saved: Dictionary = _save_coordinator.call(
		"commit_candidate",
		candidate_state,
		Callable(self, "_publish_recruitment_state"),
		"recruitment_completion"
	)
	if bool(saved.get("ok", false)):
		return
	_recruitment_state = RecruitmentState.SAVE_FAILED
	_model.set_surface_blocked(true)
	_apply_snapshot(_model.get_snapshot())
	autosave_failed.emit(saved.get("error") as RefCounted)


func _publish_recruitment_state(state: RefCounted) -> void:
	if not is_instance_valid(_pending_recruitment_roster) or not is_instance_valid(state):
		return
	_roster = _pending_recruitment_roster
	_durable_run_state = state
	_recruitment_state = RecruitmentState.REWARD_COMPLETED
	var option := _pending_recruitment_option
	_close_recruitment_party(false)
	if has_active_battle() and is_instance_valid(option):
		_active_battle.complete_pending_recruitment(option)
```

Change `_build_candidate_state` and `_formation_ids` to accept an optional roster argument and serialize the candidate without publishing it:

```gdscript
func _formation_ids(roster: RunRoster = null) -> Array[String]:
	var source := roster if is_instance_valid(roster) else _roster
	var formation: Array[String] = []
	for character: RunCharacter in source.get_slot_snapshot():
		formation.append(String(character.character_id) if is_instance_valid(character) else "")
	return formation
```

- [ ] **Step 6: Make retry, discard, cancel, and close transitions explicit**

On `retry_autosave()`, let the save coordinator invoke `_publish_recruitment_state`; do not recreate placement or recruit. On successful retry, preserve the published `REWARD_COMPLETED` state.

When `discard_pending_autosave()` runs in `SAVE_FAILED`, clear only `_pending_recruitment_roster`, set `PLACEMENT_OPEN`, refresh the existing party from `_roster.get_slot_snapshot()`, and keep the same recruit.

Allow `_on_recruitment_cancelled()` only in `PLACEMENT_OPEN`; close party, clear candidate/recruit/option, set `PLACEMENT_CANCELLED`, call `BattleArena.restore_pending_recruitment(option)`, then set `REWARD_SELECTED`. Make `_close_recruitment_party(reset_state: bool = true)` clear candidate state and return to `IDLE` only when requested by ordinary battle cleanup.

- [ ] **Step 7: Validate the controller immediately**

```text
godotiq_validate(target="res://Scripts/WorldMap/world_runtime_controller.gd", detail="brief")
godotiq_check_errors(scope="res://Scripts/WorldMap/world_runtime_controller.gd")
```

Fix every parser error before continuing.

- [ ] **Step 8: Run focused and adjacent tests**

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://Tests/WorldMap/test_scout_recruitment_flow.gd
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://Tests/WorldMap/test_world_runtime_migrated_flows.gd
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://Tests/UI/test_ac3_3_party_management.gd
```

Expected: all four exit 0 with PASS and no parser/runtime errors.

- [ ] **Step 9: Commit the controller fix**

```powershell
git add -- Scripts/WorldMap/world_runtime_controller.gd Tests/WorldMap/test_scout_recruitment_flow.gd Tests/WorldMap/test_scout_recruitment_flow.gd.uid
git commit -m "fix: persist Scout recruitment atomically"
```

### Task 4: Project and Runtime Verification

**Files:**
- Verify only; no planned production edits.

- [ ] **Step 1: Run GodotIQ project gates**

```text
godotiq_validate(target="project", detail="brief")
godotiq_check_errors(scope="project")
godotiq_signal_map(find="orphans", detail="brief")
```

Expected: no new convention, parser, or orphan-signal errors.

- [ ] **Step 2: Verify production startup**

```text
godotiq_verify_project_runs(scene="main", check_scope="project", stop_after=true)
```

Expected: PASS with a clean debug console.

- [ ] **Step 3: Perform visual QA of the changed modal layering**

Run the production scene, reproduce victory reward confirmation, and use `godotiq_explore(mode="inspect")` once at the placement screen. Confirm the party placement fills the viewport above the battle and the autosave failure surface, when present, remains above placement. Stop the game afterward.

- [ ] **Step 4: Run the full targeted suite once more**

Run every command from Task 3 Step 8. Expected: all exit 0.

- [ ] **Step 5: Review and commit any verification-only metadata deliberately**

Do not stage the pre-existing unrelated files `Tests/Battle/test_active_turn_skill_lock.gd.uid` or `Tests/Run/test_world_cutover_entry.gd.uid`. If Godot creates `Tests/WorldMap/test_scout_recruitment_flow.gd.uid`, stage it with the test. Verify:

```powershell
git status --short
git diff --check
git log -5 --oneline
```

Expected: only the two known unrelated UID files remain untracked, and the task commits are present.
