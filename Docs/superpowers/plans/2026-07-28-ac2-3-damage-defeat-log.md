# AC2.3 Damage, Defeat, and Battle Log Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add deterministic fixed damage, closest-enemy targeting, HP-based defeat, turn-queue removal, transient combat feedback, and a hover-inspectable bottom battle log to the AC2.2 arena.

**Architecture:** Extend `BattleUnitState` with health while preserving its existing constructor calls, then introduce focused targeting, damage-result, damage-resolver, and log-entry classes. `BattleArena` coordinates one complete debug damage turn and presentation; the scene owns stable HP/feedback/log nodes, while log rows are created dynamically from immutable battle-log data.

**Tech Stack:** Godot 4.7.1, typed GDScript, GodotIQ structured script/scene tooling, headless `SceneTree` tests.

---

## File Structure

- Modify: `Scripts/Battle/battle_unit_state.gd` — maximum/current HP and active-state contract.
- Modify: `Scripts/Battle/battle_turn_queue.gd` — health validation and inactive-unit filtering.
- Create: `Scripts/Battle/battle_target_selector.gd` — pure deterministic closest-active-enemy selection.
- Create: `Scripts/Battle/battle_damage_result.gd` — typed facts from one accepted damage mutation.
- Create: `Scripts/Battle/battle_damage_resolver.gd` — validated, clamped damage application.
- Create: `Scripts/Battle/battle_log_entry.gd` — immutable-after-construction historical damage event.
- Modify: `Scripts/Battle/battle_arena.gd` — debug action transaction, queue successor logic, log ownership, hover/transient state, and UI synchronization.
- Modify: `Scenes/battle_arena.tscn` — HP and damage labels, bounded bottom log, and damage-action button text.
- Create: `Tests/Battle/test_ac2_3_damage_defeat_log.gd` — focused 18-case domain and arena contract.
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — AC2.3 mechanic and verification detail; completion checkbox only after evidence passes.
- Modify: `Docs/superpowers/specs/2026-07-27-ac2-2-speed-order-design.md` — active-unit queue compatibility note.
- Create: `Docs/Specs/AC2/Evidence/AC2.3/2026-07-28/automated-test.log`.
- Create: `Docs/Specs/AC2/Evidence/AC2.3/2026-07-28/manual-runtime-check.md`.
- Create: `Docs/Specs/AC2/Evidence/AC2.3/2026-07-28/implementation-link.txt`.

## Fixed Contracts

```text
Starting/max HP: 20
Debug requested damage: 7
Target key: (abs(target.slot_index % 3 - attacker.slot_index % 3),
             0 if target.slot_index < 3 else 1,
             target.slot_index)
Transient feedback duration: 0.8 seconds
Focused PASS signature: AC2.3 damage and battle log tests: PASS (18/18)
```

Keep the scene identifier `%AdvanceTurnDebugButton` for AC2.2 test compatibility. Change only its visible text to `Damage Closest Enemy (Debug)` and its handler behavior.

### Task 1: Commit the Approved Plan

**Files:**

- Create: `Docs/superpowers/plans/2026-07-28-ac2-3-damage-defeat-log.md`

- [ ] **Step 1: Run the plan self-review**

```powershell
$plan = 'Docs/superpowers/plans/2026-07-28-ac2-3-damage-defeat-log.md'
$patterns = @('T' + 'BD', 'T' + 'ODO', 'implement' + ' later', 'appropriate' + ' error', 'similar' + ' to')
$patterns | ForEach-Object { rg -n --fixed-strings $_ $plan }
git diff --check
```

Expected: no placeholder matches and no whitespace errors.

- [ ] **Step 2: Commit the plan**

```powershell
git add Docs/superpowers/plans/2026-07-28-ac2-3-damage-defeat-log.md
git commit -m "docs: plan AC2.3 damage and battle log"
```

### Task 2: Write and Prove the Focused RED Contract

**Files:**

- Create: `Tests/Battle/test_ac2_3_damage_defeat_log.gd`

- [ ] **Step 1: Inspect the test boundary before creation**

```text
file_context(res://Tests/Battle/test_ac2_2_speed_order.gd, detail=brief)
file_context(res://Scenes/battle_arena.tscn, detail=brief)
```

- [ ] **Step 2: Create the typed `SceneTree` runner through GodotIQ**

Create the test using `script_ops(op=create)` with this runner contract:

```gdscript
class_name Ac2_3DamageDefeatLogTests
extends SceneTree

const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 18
const EXPECTED_STARTING_HP := 20
const EXPECTED_DAMAGE := 7

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_debug_units_start_at_full_hp()
	_test_fixed_damage_reduces_hp()
	_test_damage_clamps_at_zero()
	_test_same_row_targeting()
	_test_front_column_targeting_tie()
	_test_slot_index_targeting_tie()
	_test_defeated_target_is_ignored()
	await _test_defeated_slot_remains_visible()
	_test_defeated_unit_leaves_queue()
	await _test_defeat_preserves_next_actor()
	await _test_one_action_one_turn()
	await _test_one_action_one_log_entry()
	await _test_defeat_log_entry()
	await _test_no_opponent_no_op()
	await _test_resolution_feedback()
	await _test_hover_feedback()
	await _test_hover_exit_restores_current()
	await _test_reconfigure_resets_battle_state()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _unit(
	id: StringName,
	side: int,
	slot_index: int,
	speed: int = 5,
	max_hp: int = EXPECTED_STARTING_HP
) -> BattleUnitState:
	return BattleUnitState.new(id, str(id), side, slot_index, speed, max_hp)


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC2.3 damage and battle log tests: PASS (%d/%d)" % [
			EXPECTED_TEST_COUNT,
			EXPECTED_TEST_COUNT,
		])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
```

Implement all 18 named cases in the same file. Use real scripts and `res://Scenes/battle_arena.tscn`; do not mock `BattleArena`. Exact core assertions:

```gdscript
# Full HP
unit.max_hp == 20 and unit.current_hp == 20 and unit.is_active()

# Fixed hit
result.applied_damage == 7 and receiver.current_hp == 13

# Lethal clamp from 6 HP
result.applied_damage == 6 and receiver.current_hp == 0 and result.caused_defeat

# Target priority
same_row.unit_id == &"same_row"
front_tie.unit_id == &"front"
slot_tie.unit_id == &"slot_0"

# Queue exclusion
not BattleTurnQueue.build(units).has(defeated)

# One action
log_after == log_before + 1 and current_after != current_before

# No opponent
hp_after == hp_before and log_after == log_before and current_after == current_before

# Hover metadata and damage label
attacker_slot.get_meta("highlight_role") == &"attacker"
receiver_slot.get_meta("highlight_role") == &"receiver"
damage_label.text == "-7"
```

- [ ] **Step 3: Validate and prove RED**

```text
validate(res://Tests/Battle/test_ac2_3_damage_defeat_log.gd, detail=brief)
check_errors(res://Tests/Battle/test_ac2_3_damage_defeat_log.gd)
```

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script Tests/Battle/test_ac2_3_damage_defeat_log.gd
```

Expected: nonzero exit because the AC2.3 classes, APIs, and scene nodes do not exist. The PASS signature must be absent.

- [ ] **Step 4: Commit the red contract**

```powershell
git add Tests/Battle/test_ac2_3_damage_defeat_log.gd
git commit -m "test: specify AC2.3 damage and battle log"
```

### Task 3: Add Health and Active Queue Participation

**Files:**

- Modify: `Scripts/Battle/battle_unit_state.gd`
- Modify: `Scripts/Battle/battle_turn_queue.gd`
- Test: `Tests/Battle/test_ac2_3_damage_defeat_log.gd`
- Regression: `Tests/Battle/test_ac2_2_speed_order.gd`

- [ ] **Step 1: Inspect both scripts and signature impact**

```text
file_context(res://Scripts/Battle/battle_unit_state.gd, detail=brief)
file_context(res://Scripts/Battle/battle_turn_queue.gd, detail=brief)
impact_check(res://Scripts/Battle/battle_unit_state.gd, action=add_parameter, target=_init, change_description="append optional max_hp_value=20 without breaking AC2.2 constructor calls")
impact_check(res://Scripts/Battle/battle_turn_queue.gd, action=modify_function, target=build, change_description="reject invalid max HP and exclude defeated units")
```

- [ ] **Step 2: Patch `BattleUnitState` through GodotIQ**

Append a defaulted parameter so every existing five-argument AC2.2 constructor call remains valid:

```gdscript
const DEFAULT_MAX_HP := 20

var max_hp: int
var current_hp: int


func _init(
	id: StringName,
	name: String,
	unit_side: int,
	unit_slot_index: int,
	unit_speed: int,
	max_hp_value: int = DEFAULT_MAX_HP
) -> void:
	unit_id = id
	display_name = name
	side = unit_side
	slot_index = unit_slot_index
	speed = unit_speed
	max_hp = max_hp_value
	current_hp = max_hp_value


func is_active() -> bool:
	return current_hp > 0
```

- [ ] **Step 3: Validate and parse the unit script**

```text
validate(res://Scripts/Battle/battle_unit_state.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_unit_state.gd)
```

Expected: no convention or parser errors.

- [ ] **Step 4: Patch queue validation and filtering**

Inside `build()`, validate maximum and current HP before occupancy registration, then append only active units:

```gdscript
if unit.max_hp <= 0:
	print("BattleTurnQueue rejected: unit %s has invalid max HP %d" % [unit.unit_id, unit.max_hp])
	return []
if unit.current_hp < 0 or unit.current_hp > unit.max_hp:
	print("BattleTurnQueue rejected: unit %s has invalid current HP %d/%d" % [
		unit.unit_id,
		unit.current_hp,
		unit.max_hp,
	])
	return []
# Keep occupancy validation for inactive units so invalid battle configuration
# cannot be hidden by defeat.
occupied[occupancy_key] = true
if unit.is_active():
	ordered.append(unit)
```

- [ ] **Step 5: Validate, parse, and run the health subset**

```text
validate(res://Scripts/Battle/battle_turn_queue.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_turn_queue.gd)
```

Run AC2.3. Expected: cases 1 and 9 pass; damage, targeting, log, and arena cases remain red.

Run AC2.2 independently. Expected: exact `AC2.2 speed order tests: PASS (12/12)` and exit `0`.

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Battle/battle_unit_state.gd Scripts/Battle/battle_turn_queue.gd
git commit -m "feat: add battle unit health and active queue state"
```

### Task 4: Implement Deterministic Closest-Enemy Selection

**Files:**

- Create: `Scripts/Battle/battle_target_selector.gd`
- Test: `Tests/Battle/test_ac2_3_damage_defeat_log.gd`

- [ ] **Step 1: Create the selector through GodotIQ**

Use `script_ops(op=create)` with:

```gdscript
class_name BattleTargetSelector
extends RefCounted

const FRONT_COLUMN_END := 3


static func find_closest_enemy(
	attacker: BattleUnitState,
	units: Array[BattleUnitState]
) -> BattleUnitState:
	if not is_instance_valid(attacker) or not attacker.is_active():
		return null
	var candidates: Array[BattleUnitState] = []
	for unit: BattleUnitState in units:
		if (
			is_instance_valid(unit)
			and unit.is_active()
			and unit.side != attacker.side
			and (
				unit.side == BattleUnitState.Side.PLAYER
				or unit.side == BattleUnitState.Side.ENEMY
			)
		):
			candidates.append(unit)
	if candidates.is_empty():
		return null
	candidates.sort_custom(
		func(first: BattleUnitState, second: BattleUnitState) -> bool:
			return _comes_before(attacker, first, second)
	)
	return candidates[0]


static func _comes_before(
	attacker: BattleUnitState,
	first: BattleUnitState,
	second: BattleUnitState
) -> bool:
	var first_key := _target_key(attacker, first)
	var second_key := _target_key(attacker, second)
	if first_key.x != second_key.x:
		return first_key.x < second_key.x
	if first_key.y != second_key.y:
		return first_key.y < second_key.y
	return first_key.z < second_key.z


static func _target_key(attacker: BattleUnitState, target: BattleUnitState) -> Vector3i:
	var attacker_row := attacker.slot_index % 3
	var target_row := target.slot_index % 3
	var row_distance := absi(target_row - attacker_row)
	var column_priority := 0 if target.slot_index < FRONT_COLUMN_END else 1
	return Vector3i(row_distance, column_priority, target.slot_index)
```

- [ ] **Step 2: Validate, parse, and run targeting cases**

```text
validate(res://Scripts/Battle/battle_target_selector.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_target_selector.gd)
```

Run AC2.3. Expected: targeting cases 4–7 pass; resolver and arena cases remain red.

- [ ] **Step 3: Commit**

```powershell
git add Scripts/Battle/battle_target_selector.gd
git commit -m "feat: select closest active battle enemy"
```

### Task 5: Implement Typed Damage and Log Data

**Files:**

- Create: `Scripts/Battle/battle_damage_result.gd`
- Create: `Scripts/Battle/battle_damage_resolver.gd`
- Create: `Scripts/Battle/battle_log_entry.gd`
- Test: `Tests/Battle/test_ac2_3_damage_defeat_log.gd`

- [ ] **Step 1: Create `BattleDamageResult`**

```gdscript
class_name BattleDamageResult
extends RefCounted

var attacker_id: StringName
var receiver_id: StringName
var requested_damage: int
var applied_damage: int
var receiver_hp_after: int
var caused_defeat: bool


func _init(
	result_attacker_id: StringName,
	result_receiver_id: StringName,
	result_requested_damage: int,
	result_applied_damage: int,
	result_receiver_hp_after: int,
	result_caused_defeat: bool
) -> void:
	attacker_id = result_attacker_id
	receiver_id = result_receiver_id
	requested_damage = result_requested_damage
	applied_damage = result_applied_damage
	receiver_hp_after = result_receiver_hp_after
	caused_defeat = result_caused_defeat
```

- [ ] **Step 2: Validate and parse `BattleDamageResult`**

```text
validate(res://Scripts/Battle/battle_damage_result.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_damage_result.gd)
```

- [ ] **Step 3: Create `BattleDamageResolver`**

```gdscript
class_name BattleDamageResolver
extends RefCounted

const DEBUG_DAMAGE := 7


static func apply_damage(
	attacker: BattleUnitState,
	receiver: BattleUnitState,
	amount: int
) -> BattleDamageResult:
	if (
		not is_instance_valid(attacker)
		or not is_instance_valid(receiver)
		or amount <= 0
		or not attacker.is_active()
		or not receiver.is_active()
		or attacker.side == receiver.side
	):
		return null
	var hp_before := receiver.current_hp
	var applied_damage := mini(amount, hp_before)
	receiver.current_hp = maxi(0, hp_before - amount)
	return BattleDamageResult.new(
		attacker.unit_id,
		receiver.unit_id,
		amount,
		applied_damage,
		receiver.current_hp,
		hp_before > 0 and receiver.current_hp == 0
	)
```

- [ ] **Step 4: Validate and parse `BattleDamageResolver`**

```text
validate(res://Scripts/Battle/battle_damage_resolver.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_damage_resolver.gd)
```

- [ ] **Step 5: Create `BattleLogEntry`**

```gdscript
class_name BattleLogEntry
extends RefCounted

var sequence_number: int
var round_number: int
var attacker_id: StringName
var receiver_id: StringName
var applied_damage: int
var receiver_hp_after: int
var caused_defeat: bool


func _init(
	entry_sequence_number: int,
	entry_round_number: int,
	result: BattleDamageResult
) -> void:
	sequence_number = entry_sequence_number
	round_number = entry_round_number
	attacker_id = result.attacker_id
	receiver_id = result.receiver_id
	applied_damage = result.applied_damage
	receiver_hp_after = result.receiver_hp_after
	caused_defeat = result.caused_defeat
```

- [ ] **Step 6: Validate, parse, and run domain cases**

```text
validate(res://Scripts/Battle/battle_log_entry.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_log_entry.gd)
```

Run AC2.3. Expected: domain cases 1–7 and 9 pass; arena/log presentation cases remain red.

- [ ] **Step 7: Commit**

```powershell
git add Scripts/Battle/battle_damage_result.gd Scripts/Battle/battle_damage_resolver.gd Scripts/Battle/battle_log_entry.gd
git commit -m "feat: resolve typed battle damage events"
```

### Task 6: Add HP, Feedback, and Bottom Log Scene Nodes

**Files:**

- Modify: `Scenes/battle_arena.tscn`

- [ ] **Step 1: Inspect scene structure**

```text
file_context(res://Scenes/battle_arena.tscn, detail=brief)
```

- [ ] **Step 2: Add per-slot scene-authored nodes through GodotIQ**

For each player and enemy slot `0–5`, add under its existing `UnitInfo`:

```text
HealthLabel: Label
  text = "HP 20/20"
  horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

DamageFeedbackLabel: Label
  text = ""
  horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
  modulate = Color(1.0, 0.35, 0.35, 1.0)
```

Use one batched `node_ops(validate=true)` operation. Preserve the existing semantic slot layout and names.

- [ ] **Step 3: Add the full-width bottom log**

Under `Margin/VBox`, after the formations and before debug controls, add:

```text
BattleLogPanel: PanelContainer
  custom_minimum_size.y = 150
  BattleLogMargin: MarginContainer
    BattleLogVBox: VBoxContainer
      BattleLogTitle: Label
        text = "Battle Log"
      BattleLogScroll: ScrollContainer
        unique_name_in_owner = true
        custom_minimum_size.y = 110
        horizontal_scroll_mode = SCROLL_MODE_DISABLED
        vertical_scroll_mode = SCROLL_MODE_AUTO
        BattleLogEntries: VBoxContainer
          unique_name_in_owner = true
          size_flags_horizontal = SIZE_EXPAND_FILL
```

Keep the node name and unique identifier `AdvanceTurnDebugButton`; change its text to:

```text
Damage Closest Enemy (Debug)
```

- [ ] **Step 4: Save and validate**

```text
save_scene(expected_scene=res://Scenes/battle_arena.tscn)
validate(res://Scenes/battle_arena.tscn, detail=brief)
undo_history(detail=brief)
```

Expected: scene saves successfully, all 24 new per-slot labels exist, the bottom log is below formations, and there are no empty required UI nodes.

- [ ] **Step 5: Commit**

```powershell
git add Scenes/battle_arena.tscn
git commit -m "feat: add AC2.3 battle health and log UI"
```

### Task 7: Implement the Complete Arena Damage Transaction

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Test: `Tests/Battle/test_ac2_3_damage_defeat_log.gd`
- Regression: `Tests/Battle/test_ac2_2_speed_order.gd`

- [ ] **Step 1: Inspect arena context and impact**

```text
file_context(res://Scripts/Battle/battle_arena.gd, detail=normal)
impact_check(res://Scripts/Battle/battle_arena.gd, action=modify_function, target=configure_units, change_description="reset AC2.3 log, hover, feedback, health UI, queue, and round")
impact_check(res://Scripts/Battle/battle_arena.gd, action=modify_function, target=_on_advance_debug_pressed, change_description="replace advance-only behavior with one fixed-damage action plus one turn advance")
```

- [ ] **Step 2: Add typed state and public test seams**

Add:

```gdscript
const CURRENT_SLOT_COLOR := Color(1.0, 0.82, 0.32, 1.0)
const ATTACKER_SLOT_COLOR := Color(0.35, 0.9, 0.5, 1.0)
const RECEIVER_SLOT_COLOR := Color(1.0, 0.35, 0.4, 1.0)
const FEEDBACK_DURATION_SECONDS := 0.8

@onready var _battle_log_scroll: ScrollContainer = %BattleLogScroll
@onready var _battle_log_entries_container: VBoxContainer = %BattleLogEntries

var _battle_log_entries: Array[BattleLogEntry] = []
var _hovered_log_index: int = -1
var _feedback_generation: int = 0
var _transient_log_entry: BattleLogEntry
var _action_in_progress: bool = false


func get_battle_log_entries() -> Array[BattleLogEntry]:
	return _battle_log_entries.duplicate()


func get_unit_by_id(unit_id: StringName) -> BattleUnitState:
	for unit: BattleUnitState in _units:
		if is_instance_valid(unit) and unit.unit_id == unit_id:
			return unit
	return null


func preview_log_entry(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= _battle_log_entries.size():
		return
	_hovered_log_index = entry_index
	_refresh_highlights()


func clear_log_entry_preview() -> void:
	_hovered_log_index = -1
	_refresh_highlights()
```

- [ ] **Step 3: Reset all AC2.3 battle state in `configure_units()`**

Before rebuilding the queue:

```gdscript
_feedback_generation += 1
_action_in_progress = false
_hovered_log_index = -1
_battle_log_entries.clear()
_clear_log_controls()
_clear_all_damage_feedback()
```

Then duplicate units, build the queue, reset index and round to `1`, and refresh the UI exactly once.

- [ ] **Step 4: Implement one accepted damage action**

```gdscript
func perform_debug_damage() -> void:
	if _action_in_progress:
		return
	var attacker := get_current_unit()
	var receiver := BattleTargetSelector.find_closest_enemy(attacker, _units)
	if not is_instance_valid(attacker) or not is_instance_valid(receiver):
		_refresh_turn_ui()
		return
	_action_in_progress = true
	var action_round := round_number
	var result := BattleDamageResolver.apply_damage(
		attacker,
		receiver,
		BattleDamageResolver.DEBUG_DAMAGE
	)
	if not is_instance_valid(result):
		_action_in_progress = false
		return
	var entry := BattleLogEntry.new(
		_battle_log_entries.size() + 1,
		action_round,
		result
	)
	_battle_log_entries.append(entry)
	_append_log_control(entry, _battle_log_entries.size() - 1)
	_show_resolution_feedback(entry)
	_advance_after_action(attacker.unit_id)
	_action_in_progress = false
	_refresh_turn_ui()
```

- [ ] **Step 5: Preserve the correct successor after queue rebuilding**

```gdscript
func _advance_after_action(attacker_id: StringName) -> void:
	_turn_queue = BattleTurnQueue.build(_units)
	if _turn_queue.is_empty():
		_current_turn_index = 0
		return
	var attacker_index := -1
	for index: int in _turn_queue.size():
		if _turn_queue[index].unit_id == attacker_id:
			attacker_index = index
			break
	if attacker_index < 0:
		_current_turn_index = 0
		return
	_current_turn_index = attacker_index + 1
	if _current_turn_index >= _turn_queue.size():
		round_number += 1
		_current_turn_index = 0
```

The attacker remains active, so `attacker_index < 0` is defensive only. This algorithm handles receivers removed before or after the attacker in sorted order without repeating the attacker.

- [ ] **Step 6: Render HP and defeated slots**

In `_render_units()`, initialize empty slots with blank health/feedback labels. For valid units:

```gdscript
health_label.text = (
	"HP %d/%d" % [unit.current_hp, unit.max_hp]
	if unit.is_active()
	else "Defeated — HP 0/%d" % unit.max_hp
)
```

Set every slot's `highlight_role` metadata to `&"neutral"` during reset.

- [ ] **Step 7: Create log controls and automatic scrolling**

```gdscript
func _append_log_control(entry: BattleLogEntry, entry_index: int) -> void:
	var attacker := get_unit_by_id(entry.attacker_id)
	var receiver := get_unit_by_id(entry.receiver_id)
	var row := Label.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.text = "R%d · %s dealt %d damage to %s · %d/%d HP%s" % [
		entry.round_number,
		attacker.display_name,
		entry.applied_damage,
		receiver.display_name,
		entry.receiver_hp_after,
		receiver.max_hp,
		" · Defeated" if entry.caused_defeat else "",
	]
	row.mouse_entered.connect(preview_log_entry.bind(entry_index))
	row.mouse_exited.connect(clear_log_entry_preview)
	_battle_log_entries_container.add_child(row)
	await get_tree().process_frame
	_battle_log_scroll.scroll_vertical = int(_battle_log_scroll.get_v_scroll_bar().max_value)
```

`_clear_log_controls()` queues every child of `%BattleLogEntries` for deletion.

- [ ] **Step 8: Implement transient and hover feedback**

`_refresh_highlights()` first resets all slots to neutral, clears feedback labels, and then applies this precedence:

```text
hovered historical entry
current transient resolution entry
normal current unit
```

Use `highlight_role` metadata values `&"attacker"`, `&"receiver"`, `&"current"`, and `&"neutral"` with their approved colors.

`_show_resolution_feedback(entry)` increments `_feedback_generation`, stores the entry as current transient feedback, calls `_refresh_highlights()`, and starts:

```gdscript
func _expire_feedback(generation: int) -> void:
	await get_tree().create_timer(FEEDBACK_DURATION_SECONDS).timeout
	if generation != _feedback_generation:
		return
	_transient_log_entry = null
	_refresh_highlights()
```

The receiver's `DamageFeedbackLabel` displays:

```gdscript
"-%d" % entry.applied_damage
```

- [ ] **Step 9: Update button state and handler**

The button is enabled only when:

```gdscript
is_instance_valid(get_current_unit())
and is_instance_valid(BattleTargetSelector.find_closest_enemy(get_current_unit(), _units))
and not _action_in_progress
```

Keep `_on_advance_debug_pressed()` for signal and AC2.2 compatibility, but replace its body:

```gdscript
func _on_advance_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	perform_debug_damage()
```

Keep `advance_turn()` as a public AC2.2 regression seam; production debug pointer input uses `perform_debug_damage()`.

- [ ] **Step 10: Validate, parse, and prove GREEN**

```text
validate(res://Scripts/Battle/battle_arena.gd, detail=brief)
check_errors(res://Scripts/Battle/battle_arena.gd)
```

Run AC2.3. Expected:

```text
AC2.3 damage and battle log tests: PASS (18/18)
```

Run AC2.2. Expected:

```text
AC2.2 speed order tests: PASS (12/12)
```

- [ ] **Step 11: Commit**

```powershell
git add Scripts/Battle/battle_arena.gd
git commit -m "feat: resolve AC2.3 debug damage turns"
```

### Task 8: Run Regression and Runtime UI Verification

**Files:**

- Verify: all `Tests/Map/*.gd`
- Verify: all `Tests/Battle/*.gd`
- Verify: `Scenes/battle_arena.tscn`

- [ ] **Step 1: Run every headless test independently**

```powershell
$godot = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$tests = Get-ChildItem -Path 'Tests\Map','Tests\Battle' -Filter '*.gd' | Sort-Object FullName
foreach ($test in $tests) {
	& $godot --headless --path . --script $test.FullName
	if ($LASTEXITCODE -ne 0) { throw "Test failed: $($test.FullName)" }
}
```

Expected: every runner exits `0`, no output contains `FAILED:`, AC2.2 prints `PASS (12/12)`, and AC2.3 prints `PASS (18/18)`.

- [ ] **Step 2: Run structured GodotIQ gates**

```text
validate(project, detail=brief)
check_errors(project)
signal_map(scope=all, find=orphans, detail=brief)
signal_map(scope=all, find=missing, detail=brief)
```

Expected: no new AC2.3 convention, parser, orphan, or missing-signal errors.

- [ ] **Step 3: Verify runtime startup**

```text
run(action=play, scene=main, detail=brief)
verify_project_runs()
read_debug_console()
```

Expected: main scene runs and the debugger contains no AC2.3 errors.

- [ ] **Step 4: Verify the real Combat pointer path**

Call `ui_map(detail=normal)` before every pointer-input sequence. Enter a Combat battle through the map UI and click `%AdvanceTurnDebugButton` once. Use `state_inspect` to verify:

```text
attacker highlight_role = attacker during feedback
receiver highlight_role = receiver during feedback
receiver DamageFeedbackLabel.text = -7
receiver HealthLabel.text = HP 13/20
BattleLogEntries child count = 1
current unit changed exactly once
```

Hover the first log row with pointer input. Verify green attacker, red receiver, and `-7`; move the pointer away and verify the gold current highlight returns.

- [ ] **Step 5: Verify defeat and no-op behavior**

Continue real debug actions until a receiver reaches zero. Verify final applied damage `-6`, `Defeated — HP 0/20`, `· Defeated` in the log, queue exclusion, historical hover, and automatic log scrolling.

Use controlled `configure_units()` state through `exec(context=game)` only for the no-op edge: one active unit on one side and no active opponent. Verify the damage button is disabled and direct `perform_debug_damage()` changes no HP, log count, current unit, or round.

- [ ] **Step 6: Verify Boss and exit behavior**

Exit through the existing debug button, confirm map/run state is preserved, enter a Boss battle, and confirm `20/20 HP`, target selection, damage, and logging initialize identically.

- [ ] **Step 7: Capture one final visual verification**

Use one screenshot after a populated Combat log contains a defeating entry. Confirm both formations remain readable, the bottom log does not overlap debug controls, and the defeated slot and hover feedback are legible. Stop the game:

```text
run(action=stop, detail=brief)
```

### Task 9: Update Documentation and Create Same-Commit Evidence

**Files:**

- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Modify: `Docs/superpowers/specs/2026-07-27-ac2-2-speed-order-design.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.3/2026-07-28/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.3/2026-07-28/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.3/2026-07-28/implementation-link.txt`

- [ ] **Step 1: Update the MVP mechanic and verification text**

Add to the Combat System description:

```markdown
- Battle units have maximum and current HP. AC2.3 debug fixtures start at 20/20 HP.
- The temporary AC2.3 action deals 7 damage from the current unit to the deterministic closest active enemy, then advances the turn.
- Units at 0 HP remain visible as defeated but are removed immediately from targeting and turn order.
- The battle screen retains a scrollable action log. Damage briefly marks attacker/receiver and shows a negative damage value; hovering a log entry reproduces those participants and that value.
```

Replace the AC2.3 verification path with:

```markdown
| `AC2.3` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_3_damage_defeat_log.gd`, then use the debug damage action in Combat and Boss battles. Verify deterministic closest-enemy targeting, fixed 7 damage with zero clamping, immediate defeated-unit queue/target exclusion, one turn advance and log entry per action, transient negative damage feedback, scroll-to-newest history, and green-attacker/red-receiver hover inspection. |
```

Leave AC2.3 unchecked at this step.

- [ ] **Step 2: Update the AC2.2 compatibility note**

Replace the speculative AC2.3 future-extension paragraph with:

```markdown
AC2.3 extends `BattleUnitState` with HP and active participation. `BattleTurnQueue` excludes defeated units while preserving AC2.2's descending-speed and semantic formation tie-break contract for every active unit.
```

- [ ] **Step 3: Record automated evidence**

Create `automated-test.log` containing:

```text
AC2.3 AUTOMATED VERIFICATION
Date: 2026-07-28
Branch: <task branch>
Tested commit: <implementation commit>
Godot: 4.7.1

Focused:
AC2.3 damage and battle log tests: PASS (18/18)

Regression:
<every runner path, PASS signature, and exit code 0>

GodotIQ:
project validation: PASS
project parser check: PASS
orphan signals: no new AC2.3 issues
missing signals: no new AC2.3 issues
runtime startup: PASS
debug console: no AC2.3 errors
```

Replace angle-bracket fields with exact observed values.

- [ ] **Step 4: Record manual evidence**

Create `manual-runtime-check.md` with PASS/FAIL rows for every Task 8 observation: Combat initialization, closest target, `20→13`, one log/turn, transient colors and `-7`, hover and restore, `6→0` clamp with `-6`, defeated display, queue/target exclusion, historical hover, scroll behavior, no-opponent disabled/no-op state, debug exit/map preservation, and Boss initialization.

- [ ] **Step 5: Record implementation linkage**

Create `implementation-link.txt` with exact source spec, approved design, this plan, task branch, final implementation commit, changed scripts/scene/test/docs, and all three evidence paths.

- [ ] **Step 6: Mark AC2.3 complete only after evidence matches**

Confirm all three artifacts identify the same tested implementation commit. Then change:

```markdown
- [ ] AC2.3 — Unit takes damage; at 0 HP, removed from battle
```

to:

```markdown
- [x] AC2.3 — Unit takes damage; at 0 HP, removed from battle
```

- [ ] **Step 7: Rerun final verification**

Rerun every headless test and the four GodotIQ gates from Task 8. Expected: all remain passing after documentation changes.

- [ ] **Step 8: Commit documentation and evidence**

```powershell
git add Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/superpowers/specs/2026-07-27-ac2-2-speed-order-design.md Docs/Specs/AC2/Evidence/AC2.3/2026-07-28
git commit -m "docs: record AC2.3 verification evidence"
```

## Self-Review

- Every approved AC2.3 scope item maps to an exact file and task.
- Missing scripts, focused tests, scene behavior, documentation, and evidence from the validation review are explicit delivery outputs.
- The AC2.2 `%AdvanceTurnDebugButton`, `advance_turn()`, five-argument unit constructor, ordering key, formation nodes, and debug-exit behavior remain compatible.
- Target priority, HP values, damage values, applied-damage clamping, successor logic, highlight precedence, hover behavior, reset behavior, success signature, and evidence fields are explicit.
- AC2.4 victory/loss behavior remains excluded; AC2.3 only exposes the disabled/no-op state when one side has no active opponents.
- No skill, action, roster, reward, animation, audio, or generalized effect framework is introduced.
