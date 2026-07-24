# Remove Keybind Hints Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the complete keyboard-hint overlay and every obsolete `map_move_*` InputMap action while preserving mouse map navigation.

**Architecture:** Delete the isolated `NavigationHelp` scene subtree before deleting its script so Godot can clean the scene dependency safely. Replace the stale keyboard-event assertion in the AC1.3 runtime test with direct scene-node and InputMap absence assertions.

**Tech Stack:** Godot 4.7.1, typed GDScript, GodotIQ scene/script operations, existing headless `SceneTree` tests.

---

## File Structure

- Modify: `Tests/Map/test_ac1_3_mouse_navigation.gd`
  - Replace legacy keyboard-event behavior coverage with two explicit absence checks.
- Modify: `Scenes/game_world.tscn`
  - Remove `UI/NavigationHelp` and the now-unused script external resource.
- Modify: `project.godot`
  - Remove all six `map_move_*` InputMap actions.
- Delete: `Scripts/UI/navigation_help.gd`
- Delete: `Scripts/UI/navigation_help.gd.uid`
- Delete: `Tests/Map/test_navigation_help_ui.gd`
- Delete: `Tests/Map/test_navigation_help_ui.gd.uid`

### Task 1: Write the Failing Absence Checks

- [ ] **Step 1: Update the AC1.3 test before production/configuration removal**

In `Tests/Map/test_ac1_3_mouse_navigation.gd`:

```gdscript
const REMOVED_MAP_ACTIONS: Array[StringName] = [
	&"map_move_e",
	&"map_move_ne",
	&"map_move_nw",
	&"map_move_w",
	&"map_move_sw",
	&"map_move_se",
]
const EXPECTED_TEST_COUNT := 7
```

Replace the `_test_keyboard_action_is_ignored(controller)` call with:

```gdscript
_test_navigation_help_is_absent(controller)
_test_keyboard_map_actions_are_absent()
```

Replace `_test_keyboard_action_is_ignored()` with:

```gdscript
func _test_navigation_help_is_absent(controller: MapController) -> void:
	_assert(
		not controller.has_node("UI/NavigationHelp"),
		"test_navigation_help_is_absent",
		"UI/NavigationHelp remains in game_world.tscn"
	)


func _test_keyboard_map_actions_are_absent() -> void:
	var remaining_actions: Array[StringName] = []
	for action: StringName in REMOVED_MAP_ACTIONS:
		if InputMap.has_action(action):
			remaining_actions.append(action)

	_assert(
		remaining_actions.is_empty(),
		"test_keyboard_map_actions_are_absent",
		"obsolete actions remain: %s" % remaining_actions
	)
```

- [ ] **Step 2: Run the AC1.3 test and verify RED**

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_3_mouse_navigation.gd
```

Expected: `FAIL (5/7)` with failures naming `UI/NavigationHelp` and the six remaining `map_move_*` actions. Existing mouse checks must still pass.

### Task 2: Remove the Live Hint Scene and Resources

- [ ] **Step 1: Inspect scene and dependency context**

Use GodotIQ `file_context` for `game_world.tscn`, `navigation_help.gd`, and `test_navigation_help_ui.gd`.

- [ ] **Step 2: Delete the scene subtree through the active editor**

Use GodotIQ `node_ops` to delete `UI/NavigationHelp`, then `save_scene`.

- [ ] **Step 3: Verify scene dependency cleanup before deleting the script**

Use GodotIQ `file_context(file="res://Scenes/game_world.tscn", detail="full")`.

Expected:

```text
UI/NavigationHelp node absent
res://Scripts/UI/navigation_help.gd absent from ext_resources and scripts_used
```

- [ ] **Step 4: Delete obsolete files through GodotIQ**

Delete:

```text
res://Scripts/UI/navigation_help.gd
res://Scripts/UI/navigation_help.gd.uid
res://Tests/Map/test_navigation_help_ui.gd
res://Tests/Map/test_navigation_help_ui.gd.uid
```

### Task 3: Remove Obsolete InputMap Actions

- [ ] **Step 1: Remove complete action blocks from `project.godot`**

Delete the six sections named:

```text
map_move_e
map_move_ne
map_move_nw
map_move_w
map_move_sw
map_move_se
```

Preserve the `[input]` section only if other actions remain; otherwise remove the empty section header.

- [ ] **Step 2: Run AC1.3 test and verify GREEN**

Run the Task 1 command.

Expected:

```text
AC1.3 mouse navigation tests: PASS (7/7)
```

- [ ] **Step 3: Validate changed resources**

Run GodotIQ validation on `game_world.tscn`, `project.godot`, and `test_ac1_3_mouse_navigation.gd`, followed by project parser checks.

### Task 4: Complete Regression and Runtime Verification

- [ ] **Step 1: Run the exact seven-script suite**

Run the seven commands listed in `Docs/superpowers/specs/2026-07-24-remove-keybind-hints-design.md`.

Expected suite results:

```text
AC1.1 runtime step-count check: PASS (8/8)
AC1.2 encounter determinism tests: PASS (6/6)
AC1.2 hex tile view state tests: PASS (1/1)
AC1.2 runtime encounter layout tests: PASS (5/5)
AC1.3 mouse navigation tests: PASS (7/7)
AC1.1 map logic tests: PASS (7/7)
AC1.1 runtime map controller tests: PASS (8/8)
```

- [ ] **Step 2: Verify the live scene with GodotIQ**

Run the main scene, confirm `UI/NavigationHelp` is absent from `ui_map`, click an adjacent tile, and inspect `player_coord`/`move_count`.

Expected: one adjacent click moves exactly once; debug console contains no parser, missing-resource, or runtime errors.

- [ ] **Step 3: Commit only relevant changes**

```powershell
git add Docs/superpowers/plans/2026-07-24-remove-keybind-hints.md Tests/Map/test_ac1_3_mouse_navigation.gd Tests/Map/test_ac1_3_mouse_navigation.gd.uid Scenes/game_world.tscn project.godot
git add -u Scripts/UI Tests/Map
git commit -m "chore: remove keyboard navigation hints"
```

Do not stage the pre-existing `GODOTIQ_RULES.md` modification.

## Self-Review

- Spec coverage: scene node, scene external resource, script, dedicated test, UID sidecars, and all six actions are explicitly removed.
- TDD: the two absence checks run and fail before any live resource/configuration removal.
- Test semantics: the stale `InputEventAction` assertion is removed; expected count changes from six to seven.
- Handoff reproducibility: the approved spec contains the exact seven commands and expected results.
- Scope: historical documents remain unchanged, and no replacement hint or AC1.4 behavior is introduced.
