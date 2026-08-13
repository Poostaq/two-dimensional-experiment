# Two-Enemy Debug Battle Fixture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce the default debug enemy team to `enemy_0` and `enemy_4` while retaining all six enemy formation slots.

**Architecture:** Keep the existing `BattleArena` fixture builder and remove four enemy entries only. Extend the AC2.1 real-scene test to distinguish formation capacity from occupied default enemy units.

**Tech Stack:** Godot 4.7.1, typed GDScript, GodotIQ, headless SceneTree tests.

---

### Task 1: Specify and implement the two-enemy fixture

**Files:**
- Modify: `Tests/Map/test_ac2_1_battle_arena.gd`
- Modify: `Scripts/Battle/battle_arena.gd`

- [ ] **Step 1: Add the failing fixture test**

Raise `EXPECTED_TEST_COUNT` from 11 to 12. Call `_test_default_enemy_fixture_has_front_and_back()` after the slot tests and add:

```gdscript
func _test_default_enemy_fixture_has_front_and_back() -> void:
	var arena := _instantiate_arena()
	var enemy_units: Array[BattleUnitState] = []
	for unit: BattleUnitState in arena.call("get_turn_queue"):
		if unit.side == BattleUnitState.Side.ENEMY:
			enemy_units.append(unit)
	var enemy_ids: Array[StringName] = []
	var enemy_slots: Array[int] = []
	for unit: BattleUnitState in enemy_units:
		enemy_ids.append(unit.unit_id)
		enemy_slots.append(unit.slot_index)
	enemy_ids.sort()
	enemy_slots.sort()
	var unoccupied_count := 0
	for slot: Control in arena.call("get_enemy_slots"):
		if String(slot.get_meta("unit_id", &"")).is_empty():
			unoccupied_count += 1
	_assert(
		enemy_ids == [&"enemy_0", &"enemy_4"]
		and enemy_slots == [0, 4]
		and unoccupied_count == 4,
		"default enemy fixture has front and back",
		"expected enemy_0/slot 0, enemy_4/slot 4, and four unoccupied slots"
	)
	arena.queue_free()
```

- [ ] **Step 2: Run RED**

```powershell
& 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe' --headless --path . --script res://Tests/Map/test_ac2_1_battle_arena.gd
```

Expected: FAIL because the default fixture still contains six enemy units.

- [ ] **Step 3: Inspect impact before editing**

```text
file_context(file="res://Scripts/Battle/battle_arena.gd", detail="brief")
impact_check(file="res://Scripts/Battle/battle_arena.gd", action="modify_function", target="_create_debug_units", change_description="Remove enemy_1, enemy_2, enemy_3, and enemy_5 from the default fixture", detail="normal")
```

- [ ] **Step 4: Apply the minimal production change**

Use GodotIQ `script_ops(op="patch")` to delete only these four entries from the array returned by `_create_debug_units()`:

```gdscript
BattleUnitState.new(&"enemy_1", "Enemy Front 2", BattleUnitState.Side.ENEMY, 1, 7),
BattleUnitState.new(&"enemy_2", "Enemy Front 3", BattleUnitState.Side.ENEMY, 2, 6, 20, ...),
BattleUnitState.new(&"enemy_3", "Enemy Back 1", BattleUnitState.Side.ENEMY, 3, 4),
BattleUnitState.new(&"enemy_5", "Enemy Back 3", BattleUnitState.Side.ENEMY, 5, 2),
```

Retain `enemy_0` and `enemy_4` unchanged.

- [ ] **Step 5: Validate and run GREEN**

```text
validate(target="res://Scripts/Battle/battle_arena.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_arena.gd")
```

Run AC2.1. Expected: `AC2.1 battle arena tests: PASS (12/12)`.

- [ ] **Step 6: Run focused regressions**

Run:

```powershell
& $godotExe --headless --path . --script res://Tests/Battle/test_ac2_4_battle_results.gd
& $godotExe --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
& $godotExe --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
& $godotExe --headless --path . --script res://Tests/Map/test_ac3_1_recruitment_integration.gd
```

Expected: every runner exits 0 with its documented PASS signature.

- [ ] **Step 7: Run project gates**

Run the complete sorted `Tests/**/test_*.gd` corpus, then:

```text
validate(target="project", detail="brief")
check_errors(scope="project")
run(action="play")
verify_project_runs(scene="main", check_scope="project", stop_after=true)
```

Expected: all runners exit 0, no new validation errors, and the project run gate passes.

- [ ] **Step 8: Commit**

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Map/test_ac2_1_battle_arena.gd
git commit -m "test: reduce default battle to two enemies"
```

Preserve unrelated untracked UID files.
