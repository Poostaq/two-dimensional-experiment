# AC5.1 Independent Run Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Certify and, only where evidence requires it, complete the existing single-slot lifecycle so Continue restores the last valid durable checkpoint and confirmed Start New Run atomically replaces it with an independent seeded run.

**Architecture:** Preserve `WorldProductionLauncher -> WorldRunStartService -> WorldSingleSlotRepository` and the existing synchronous `session_ready -> _on_session_ready` launch path. Add one focused AC5.1 acceptance runner and reproducible fixed fixtures around the current public contracts; do not add an autoload, a second session owner, or AC5.3 identity behavior.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ structured inspection/editing, headless `SceneTree` test runners, Save V2 JSON fixtures, Markdown verification evidence.

**Authoritative spec:** `Docs/superpowers/specs/2026-09-15-ac5-1-independent-run-lifecycle-design.md`

---

## File structure

- Create `Tools/Run/author_ac5_1_fixtures.gd`: deterministic authoring tool for the valid progressed-session fixture and its SHA-256 manifest.
- Create `Tests/Fixtures/Run/AC5.1/progressed-session-v2.json`: valid Save V2 checkpoint containing non-default run-owned state.
- Create `Tests/Fixtures/Run/AC5.1/corrupt-session.json`: intentionally invalid JSON fixture.
- Create `Tests/Fixtures/Run/AC5.1/fixture-hashes.sha256`: reviewable fixture-integrity manifest.
- Create `Tests/Run/test_ac5_1_independent_run_lifecycle.gd`: focused logic/integration acceptance runner.
- Modify `Tests/Run/test_world_production_launcher.gd`: only if the focused runner proves an uncovered reusable launcher regression belongs in the established launcher suite.
- Modify `Scripts/Run/world_production_launcher.gd`: only if a focused RED assertion disproves the approved contract; no speculative refactor is authorized.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: upgrade AC5.1 verification and mark it complete only after every gate passes.
- Create `Docs/Specs/AC5/Evidence/AC5.1/2026-09-15/automated-test.log`: exact commands and results.
- Create `Docs/Specs/AC5/Evidence/AC5.1/2026-09-15/manual-runtime-check.md`: binary runtime observations.
- Create `Docs/Specs/AC5/Evidence/AC5.1/2026-09-15/implementation-link.txt`: tested implementation commit SHA.

No scene change is planned: `Scenes/world_run_start.tscn` already contains Continue, Start New Run, and overwrite-confirmation UI.

## Traceability matrix

| AC5.1 contract | Class | Verification | Current evidence | Required action |
|---|---|---|---|---|
| Continue enabled only for a validated slot | Integration/UI | `test_main_menu_validation_gate` plus scene runner | Partially covered by launcher code | Add explicit corrupt/legacy/unsupported cases |
| Continue restores the durable checkpoint | Logic/integration | `test_continue_restores_progressed_checkpoint` | Repository test covers canonical state generically | Prove full progressed AC5.1 fixture |
| Existing bytes require confirmation | Integration | `test_begin_requires_confirmation_for_occupied_slot` | Existing launcher test | Retain and strengthen corrupt-slot case |
| Cancel performs zero writes | Logic/integration | `test_cancel_preserves_bytes_and_consumes_pending` | Existing launcher test | Add pending-consumption assertion |
| Confirm replaces exactly once | Logic/integration | `test_confirm_replaces_once` | Existing launcher test | Add second-confirm and decoded-state assertions |
| Failed generation/write preserves old run | Logic | `test_generation_failure_preserves_slot`, `test_atomic_failure_preserves_slot` | Split across service/repository tests | Prove through lifecycle coordinator |
| New run carries no prior roster/run state | Logic/integration | `test_replacement_is_independent` | No single AC5.1 proof | Add field-by-field comparison |
| Signals follow existing synchronous order | Integration | `test_signal_and_transition_order` | Incidental coverage only | Record ordered event list and final UI state |
| Runtime main-menu flow works | Runtime | manual checklist and GodotIQ state inspection | No AC5.1 evidence | Capture current proof |
| Canonical criterion/evidence agree | Documentation | spec row, evidence files, matching SHA | Missing | Record after PASS |

Initial AC5.1 status: **FAIL (production behavior exists, but the independence and lifecycle contract lacks complete focused evidence).**

### Task 1: Establish the implementation branch and baseline

**Files:**
- Verify: `Docs/superpowers/specs/2026-09-15-ac5-1-independent-run-lifecycle-design.md`
- Verify: `Scripts/Run/world_production_launcher.gd`
- Verify: `Scripts/Run/world_run_start_service.gd`
- Verify: `Scripts/Run/world_single_slot_repository.gd`

- [ ] **Step 1: Update integration state and create the required task branch**

```powershell
git status --short --branch
git pull --ff-only origin main
git switch -c feat/ac5-1-independent-run-lifecycle
```

Expected: clean worktree on `feat/ac5-1-independent-run-lifecycle`, containing the approved AC5.1 design commits. If unrelated local changes exist, stash only those paths before pulling and restore them unstaged after switching.

- [ ] **Step 2: Run the pre-change project baseline**

Use GodotIQ:

```text
validate(target="project", detail="brief")
check_errors(scope="project")
```

Then run the existing lifecycle suite:

```powershell
$tests = @(
  'Tests/Run/test_world_production_launcher.gd',
  'Tests/Run/test_world_run_start_service.gd',
  'Tests/Run/test_world_single_slot_repository.gd',
  'Tests/UI/test_world_run_start_scene.gd',
  'Tests/Save/test_world_run_save_codec_v2.gd'
)
foreach ($test in $tests) {
  & godot --headless --path . --script ('res://' + ($test -replace '\\','/'))
  if ($LASTEXITCODE -ne 0) { throw "BASELINE FAILED: $test" }
}
```

Expected: validation has no new blocking issue and all five runners exit `0`. Record any pre-existing warning separately; do not hide it in AC5.1 work.

- [ ] **Step 3: Inspect exact edit boundaries**

```text
file_context(file="res://Scripts/Run/world_production_launcher.gd", detail="normal")
file_context(file="res://Scripts/Run/world_run_start_service.gd", detail="normal")
file_context(file="res://Scripts/Run/world_single_slot_repository.gd", detail="normal")
file_context(file="res://Scripts/Run/world_run_state.gd", detail="normal")
file_context(file="res://Tests/Run/test_world_production_launcher.gd", detail="normal")
dependency_graph(file="res://Scripts/Run/world_production_launcher.gd", depth=2, detail="normal")
```

Expected: launcher remains the sole UI lifecycle coordinator, repository remains the single durable-slot boundary, and no public signature change is required.

### Task 2: Write the focused acceptance runner in RED

**Files:**
- Create: `Tests/Run/test_ac5_1_independent_run_lifecycle.gd`

- [ ] **Step 1: Create the typed runner skeleton through GodotIQ**

Use `script_ops(op="create")` with this structure:

```gdscript
class_name Ac5_1IndependentRunLifecycleTests
extends SceneTree

static var LAUNCHER_SCRIPT: GDScript = load("res://Scripts/Run/world_production_launcher.gd")
static var REPOSITORY_SCRIPT: GDScript = load("res://Scripts/Run/world_single_slot_repository.gd")
static var SAVE_CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_run_save_codec_v2.gd")
const VALID_FIXTURE := "res://Tests/Fixtures/Run/AC5.1/progressed-session-v2.json"
const CORRUPT_FIXTURE := "res://Tests/Fixtures/Run/AC5.1/corrupt-session.json"
const TEST_ROOT := "user://tests/ac5-1-independent-run"
const TEST_SLOT := TEST_ROOT + "/active-world-run.json"

var _failures: Array[String] = []
var _events: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_fixture_exists()
	_finish()


func _test_fixture_exists() -> void:
	_expect(FileAccess.file_exists(VALID_FIXTURE), "progressed Save V2 fixture exists")
	_expect(FileAccess.file_exists(CORRUPT_FIXTURE), "corrupt fixture exists")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS test_ac5_1_independent_run_lifecycle")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
```

- [ ] **Step 2: Validate the new runner**

```text
validate(target="res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd", detail="brief")
check_errors(scope="res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd")
```

Expected: parser/convention PASS.

- [ ] **Step 3: Run RED**

```powershell
godot --headless --path . --script res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd
```

Expected: exit `1`, reporting that both AC5.1 fixtures are absent.

- [ ] **Step 4: Commit the RED runner**

```powershell
git add -- Tests/Run/test_ac5_1_independent_run_lifecycle.gd
git commit -m "test: define AC5.1 lifecycle acceptance"
```

### Task 3: Author deterministic AC5.1 fixtures

**Files:**
- Create: `Tools/Run/author_ac5_1_fixtures.gd`
- Create: `Tests/Fixtures/Run/AC5.1/progressed-session-v2.json`
- Create: `Tests/Fixtures/Run/AC5.1/corrupt-session.json`
- Create: `Tests/Fixtures/Run/AC5.1/fixture-hashes.sha256`

- [ ] **Step 1: Create the fixture author through GodotIQ**

The author must generate `golden-alpha`, choose valid plan coordinates from the generated plan, construct this non-default state, encode it through `WorldRunSaveCodecV2`, and write the two fixture files:

```gdscript
var preparation: RefCounted = BattlePreparationRecord.committed(
	&"ac5_1_preparation",
	consumed_coord,
	"combat",
	"ac5-1-fixture",
	BattlePreparationRecord.Choice.SPARE_PLATING,
	&"scout"
)
var formation: Array[StringName] = [
	&"scout", &"brakka_rustbanner", &"player_2", &"player_0", &"", &""
]
var state: RefCounted = WorldRunState.create(
	player_coord,
	boss_coord,
	31,
	true,
	false,
	[consumed_coord],
	formation,
	3,
	false,
	preparation
)
var hp: Dictionary[StringName, int] = {
	&"scout": 7,
	&"brakka_rustbanner": 18,
	&"player_2": 11,
	&"player_0": 9,
}
if not state.set_character_hp_snapshot(hp):
	_fail("fixture HP rejected")
	return
var bytes: PackedByteArray = WorldRunSaveCodecV2.encode(plan, "golden-alpha", state)
```

Use `FileAccess.open(..., FileAccess.WRITE)` only inside this dedicated author tool. Write `{"not":"valid save v2"` to the corrupt fixture. Compute each committed fixture's `sha256_text()` and write sorted `<hash>  <relative-path>` rows to `fixture-hashes.sha256`. Guard the output root by asserting its globalized path ends with `/Tests/Fixtures/Run/AC5.1` before writing.

- [ ] **Step 2: Validate and execute the author**

```text
validate(target="res://Tools/Run/author_ac5_1_fixtures.gd", detail="brief")
check_errors(scope="res://Tools/Run/author_ac5_1_fixtures.gd")
```

```powershell
godot --headless --path . --script res://Tools/Run/author_ac5_1_fixtures.gd
```

Expected: `PASS author_ac5_1_fixtures`, three files under `Tests/Fixtures/Run/AC5.1`, and exit `0`.

- [ ] **Step 3: Verify fixture integrity and GREEN the skeleton**

```powershell
Get-FileHash -Algorithm SHA256 'Tests/Fixtures/Run/AC5.1/progressed-session-v2.json','Tests/Fixtures/Run/AC5.1/corrupt-session.json'
godot --headless --path . --script res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd
```

Expected: hashes match the manifest and the focused runner prints its PASS signature.

- [ ] **Step 4: Commit fixture production**

```powershell
git add -- Tools/Run/author_ac5_1_fixtures.gd Tests/Fixtures/Run/AC5.1
git commit -m "test: add AC5.1 run lifecycle fixtures"
```

### Task 4: Expand the focused runner to the complete lifecycle contract

**Files:**
- Modify: `Tests/Run/test_ac5_1_independent_run_lifecycle.gd`

- [ ] **Step 1: Add isolated slot helpers and spies**

Add helpers that copy fixture bytes into `TEST_SLOT`, read bytes, decode with `WorldRunSaveCodecV2.decode_any()`, and safely remove only the exact `user://tests/ac5-1-independent-run` directory. Add:

```gdscript
class RepositorySpy:
	extends RefCounted

	var delegate: RefCounted
	var replace_count: int = 0
	var load_count: int = 0
	var fail_replace: bool = false

	func _init(repository: RefCounted) -> void:
		delegate = repository

	func has_save() -> bool:
		return bool(delegate.call("has_save"))

	func load_validated() -> Dictionary:
		load_count += 1
		return delegate.call("load_validated") as Dictionary

	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		replace_count += 1
		if fail_replace:
			return {"ok": false, "value": null, "error": WorldSaveError.new(
				"SAVE_WRITE_FAILED", "ac5-1 forced replacement failure"
			)}
		return delegate.call("replace_atomic", bytes) as Dictionary
```

The spy uses the existing `WorldSaveError(error_code: String, constraint: String)` constructor and does not modify production error types.

- [ ] **Step 2: Add the nine named cases from the design**

Call these in order from `_run()`:

```gdscript
_test_main_menu_validation_gate()
_test_continue_restores_progressed_checkpoint()
_test_begin_requires_confirmation_for_occupied_slot()
_test_cancel_preserves_bytes_and_consumes_pending()
_test_confirm_replaces_once()
_test_generation_failure_preserves_slot()
_test_atomic_failure_preserves_slot()
_test_replacement_is_independent()
_test_signal_and_transition_order()
```

Each case creates a fresh launcher with injected repository/service/world spies, connects `session_ready`, `launch_failed`, and `screen_changed` to append exact labels to `_events`, and frees the launcher before cleanup. Assert:

```gdscript
_expect(restored.call("canonical_key") == fixture_state.call("canonical_key"),
	"Continue restores the progressed canonical checkpoint")
_expect(before_cancel == _read_bytes(TEST_SLOT), "Cancel performs zero writes")
_expect(not bool(second_confirm.get("ok", true)), "second Confirm fails closed")
_expect(repository_spy.replace_count == 1, "confirmed request replaces exactly once")
_expect(replacement_state.move_count == 0, "replacement resets move count")
_expect(replacement_state.consumed_encounters.is_empty(), "replacement resets encounters")
_expect(not replacement_state.has_character_hp_snapshot(), "replacement has no inherited HP")
_expect(not replacement_state.formation.has(&"scout"), "replacement omits prior recruit")
_expect(replacement_state.cache_move_progress == 0, "replacement resets cache progress")
_expect(int(replacement_state.battle_preparation.state) == BattlePreparationRecord.State.NONE,
	"replacement resets preparation")
```

For corrupt, legacy, and unsupported slot cases, instantiate the real `world_run_start.tscn`, inject the isolated repository through its `_repository` property before adding it to the tree, await readiness, and assert `%ContinueButton.disabled == true`, `_events.is_empty()`, and bytes unchanged. Assert corrupt bytes still cause `request_start()` to return `confirmation_required == true`.

- [ ] **Step 3: Validate and run the complete focused runner**

```text
validate(target="res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd", detail="brief")
check_errors(scope="res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd")
```

```powershell
godot --headless --path . --script res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd
```

Expected: `PASS test_ac5_1_independent_run_lifecycle`, exit `0`. If any assertion fails, stop here: retain the RED result, identify the smallest production mismatch, and execute Task 5. If all assertions pass, document Task 5 as unnecessary and proceed to Task 6 without touching production code.

- [ ] **Step 4: Commit the focused acceptance proof**

```powershell
git add -- Tests/Run/test_ac5_1_independent_run_lifecycle.gd
git commit -m "test: prove AC5.1 independent run lifecycle"
```

### Task 5: Correct only a proven launcher mismatch

**Files:**
- Modify if RED proves necessary: `Scripts/Run/world_production_launcher.gd`
- Modify: `Tests/Run/test_world_production_launcher.gd`

- [ ] **Step 1: Perform required impact checks before a production patch**

```text
file_context(file="res://Scripts/Run/world_production_launcher.gd", detail="normal")
impact_check(file="res://Scripts/Run/world_production_launcher.gd", action="modify_function", target="request_start", change_description="Correct the focused AC5.1 lifecycle mismatch without changing public signatures", detail="normal")
impact_check(file="res://Scripts/Run/world_production_launcher.gd", action="modify_function", target="confirm_overwrite", change_description="Correct the focused AC5.1 confirmation mismatch without changing public signatures", detail="normal")
impact_check(file="res://Scripts/Run/world_production_launcher.gd", action="modify_function", target="continue_saved_run", change_description="Correct the focused AC5.1 continuation mismatch without changing public signatures", detail="normal")
```

- [ ] **Step 2: Add the minimal reusable RED assertion**

Move only the failing reusable launcher behavior into `test_world_production_launcher.gd`. Preserve the AC5.1 end-to-end assertion in the focused runner. Run both and confirm the same behavior fails.

- [ ] **Step 3: Apply the smallest GodotIQ patch**

Use `script_ops(op="patch")`. Allowed correction boundaries are limited to:

- `_refresh_continue_button()` validating rather than trusting existence;
- pending seed/commander clearing on cancel or consumed confirm;
- `_create_and_persist()` writing before `session_ready`;
- generation/replacement failures emitting no session and preserving prior bytes;
- `_on_session_ready()` keeping the launcher visible when world application fails.

Do not introduce an autoload, change the four public result dictionaries, rename signals, or serialize active battle/reward UI.

- [ ] **Step 4: Validate one changed script and run GREEN**

```text
validate(target="res://Scripts/Run/world_production_launcher.gd", detail="brief")
check_errors(scope="res://Scripts/Run/world_production_launcher.gd")
```

```powershell
godot --headless --path . --script res://Tests/Run/test_world_production_launcher.gd
godot --headless --path . --script res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd
```

Expected: both PASS. If Task 4 was already GREEN, this task creates no diff and no empty commit.

- [ ] **Step 5: Commit only a test-led correction**

```powershell
git add -- Scripts/Run/world_production_launcher.gd Tests/Run/test_world_production_launcher.gd
git commit -m "fix: enforce AC5.1 run lifecycle boundaries"
```

Run this commit command only when those files contain the proven correction.

### Task 6: Run regression, GodotIQ, and runtime gates

**Files:**
- Verify: lifecycle, save, roster, formation, recovery, and Goblin integration systems

- [ ] **Step 1: Run the focused regression matrix**

```powershell
$tests = @(
  'Tests/Run/test_ac5_1_independent_run_lifecycle.gd',
  'Tests/Run/test_world_production_launcher.gd',
  'Tests/Run/test_world_run_start_service.gd',
  'Tests/Run/test_world_single_slot_repository.gd',
  'Tests/UI/test_world_run_start_scene.gd',
  'Tests/Save/test_world_run_save_codec_v2.gd',
  'Tests/WorldMap/test_world_runtime_model.gd',
  'Tests/WorldMap/test_world_runtime_save_coordinator.gd',
  'Tests/Run/test_ac3_1_run_roster.gd',
  'Tests/Run/test_ac3_3_party_formation.gd',
  'Tests/Run/test_ac3_5_post_battle_recovery.gd',
  'Tests/WorldMap/test_ac3_5_recovery_integration.gd',
  'Tests/Battle/test_ac6_5_brakka.gd',
  'Tests/WorldMap/test_ac6_7_goblin_integration.gd'
)
foreach ($test in $tests) {
  & godot --headless --path . --script ('res://' + ($test -replace '\\','/'))
  if ($LASTEXITCODE -ne 0) { throw "FAILED: $test" }
}
```

Expected: fourteen PASS signatures and exit `0` for every runner.

- [ ] **Step 2: Run project-wide structured gates**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(scope="all", find="missing", detail="brief")
signal_map(scope="all", find="orphans", detail="brief")
```

Expected: no parser/convention/missing-signal regression. Record unrelated pre-existing orphan signals without changing them.

- [ ] **Step 3: Verify the production main scene**

```text
run(action="play", scene="main", detail="brief")
verify_project_runs(scene="main", check_scope="project", stop_after=false)
read_debug_console()
```

Expected: clean start and no failing debug entry.

- [ ] **Step 4: Execute the manual AC5.1 flow**

Use the production UI and `state_inspect`:

1. Install/load the progressed fixture into the test slot used by the launcher test configuration.
2. Verify Continue restores seed `golden-alpha`, the rearranged formation including `scout`, the HP snapshot, move count `31`, one consumed encounter, cache progress `3`, and committed preparation.
3. Return to Main; request a different seed; cancel overwrite; Continue again and verify the same canonical state.
4. Request the different seed again; confirm overwrite; verify the prior `scout`, HP snapshot, consumed encounter, move count, cache progress, and preparation are absent/reset.
5. Return to Main and Continue; verify it restores the replacement checkpoint rather than the old fixture.

Use at most one screenshot of the overwrite confirmation because the acceptance evidence is primarily state-based. Stop Play after inspection.

### Task 7: Record completion evidence and canonical status

**Files:**
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC5/Evidence/AC5.1/2026-09-15/automated-test.log`
- Create: `Docs/Specs/AC5/Evidence/AC5.1/2026-09-15/manual-runtime-check.md`
- Create: `Docs/Specs/AC5/Evidence/AC5.1/2026-09-15/implementation-link.txt`

- [ ] **Step 1: Record automated evidence**

Include the exact focused and regression commands, PASS signatures, exit codes, fixture hashes, GodotIQ validation/error/signal results, runtime gate result, branch name, and full tested implementation SHA. Do not summarize a failed or skipped runner as PASS.

- [ ] **Step 2: Create the binary manual record**

```markdown
# AC5.1 Manual Runtime Check

- Implementation commit: `<full tested SHA>`
- Continue availability: PASS/FAIL/BLOCKED — valid slot enabled; missing/corrupt/legacy/unsupported slots disabled.
- Continue restoration: PASS/FAIL/BLOCKED — progressed seed, formation, HP, movement, encounter, cache, and preparation match the durable fixture.
- Overwrite cancellation: PASS/FAIL/BLOCKED — original canonical state remains loadable after Cancel.
- Confirmed replacement: PASS/FAIL/BLOCKED — replacement seed launches and old recruit/run state is absent.
- Replacement continuation: PASS/FAIL/BLOCKED — Continue restores the replacement checkpoint.
- Signal/transition health: PASS/FAIL/BLOCKED — no duplicate session, failure, or screen transition observed.
- Runtime health: PASS/FAIL/BLOCKED — production main scene has no failing debug entry.

Overall: PASS/FAIL/BLOCKED
```

- [ ] **Step 3: Upgrade the canonical AC5.1 verification row**

Replace it with:

```markdown
| `AC5.1` | Automated integration and manual runtime check | Run `Tests/Run/test_ac5_1_independent_run_lifecycle.gd` plus the launcher, start-service, single-slot repository, Save V2, runtime model/coordinator, roster, formation, recovery, and Goblin integration regressions. Verify validated Continue gating, exact durable-checkpoint restoration, confirmation and cancellation, atomic failure preservation, one-shot replacement, lifecycle signal order, and field-by-field run independence. Then use the production main menu to Continue a progressed session, cancel one overwrite without mutation, confirm a different seeded run, and verify no prior roster or mutable run state carries over. Evidence: `Docs/Specs/AC5/Evidence/AC5.1/2026-09-15/`. |
```

Change only AC5.1 from `[ ]` to `[x]` after every automated and manual item is PASS. Leave AC5.2 and AC5.3 unchecked.

- [ ] **Step 4: Record the implementation link and self-review**

```powershell
git rev-parse HEAD | Set-Content 'Docs/Specs/AC5/Evidence/AC5.1/2026-09-15/implementation-link.txt'
rg -n "T(BD)|T(ODO)|implement la[t]er|fill in det[a]ils|appropriate error handl[i]ng|Similar to Ta[s]k" `
  'Docs/superpowers/plans/2026-09-15-ac5-1-independent-run-lifecycle.md', `
  'Docs/Specs/AC5/Evidence/AC5.1/2026-09-15'
rg -n "AC5\.1|PASS|FAIL|BLOCKED|canonical|fixture" `
  'Docs/Specs/GAME_DESIGN_SPEC_MVP.md', `
  'Docs/Specs/AC5/Evidence/AC5.1/2026-09-15'
git diff --check
```

Expected: no placeholder or whitespace issue; automated, manual, and link evidence name the same tested SHA.

- [ ] **Step 5: Commit evidence and verify branch state**

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC5/Evidence/AC5.1/2026-09-15
git commit -m "docs: record AC5.1 completion evidence"
godot --headless --path . --script res://Tests/Run/test_ac5_1_independent_run_lifecycle.gd
git status --short --branch
git log -10 --oneline
```

Expected: focused PASS on committed state, only relevant AC5.1 commits on the task branch, and a clean worktree. Push only when remote handoff or review is requested.

## Completion boundary

AC5.1 is complete only when the progressed fixture and corrupt fixture have reviewed hashes; the focused runner proves validated Continue gating, exact checkpoint restoration, zero-write cancel, one-shot confirmed replacement, generation/write failure preservation, lifecycle signal ordering, and field-by-field independence; the full regression and GodotIQ gates pass; the production menu flow is manually verified; and all evidence names the same implementation commit. Any prior recruit, formation, HP, movement, encounter, cache, preparation, or pending state leak keeps AC5.1 unchecked.
