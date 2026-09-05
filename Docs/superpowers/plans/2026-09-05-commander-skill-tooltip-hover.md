# Commander Skill Tooltip Hover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent commander skill tooltip flicker while allowing the pointer to move between a skill square and its tooltip across the existing gap.

**Architecture:** Keep tooltip ownership in `WorldProductionLauncher`. Track whether the active skill button or tooltip is hovered, cancel stale hide requests with a monotonically increasing request ID, and recheck hover/focus after a 100 ms timer before hiding.

**Tech Stack:** Godot 4, typed GDScript, the existing `SceneTree` UI regression test, GodotIQ validation and runtime verification.

---

## File structure

- Modify `Tests/UI/test_world_run_start_scene.gd`: specify grace-period, tooltip-hover, final-hide, and stale-request behavior.
- Modify `Scripts/Run/world_production_launcher.gd`: implement logical hover ownership and delayed hiding.

### Task 1: Add the failing tooltip hover regression

**Files:**
- Modify: `Tests/UI/test_world_run_start_scene.gd:301`
- Test: `Tests/UI/test_world_run_start_scene.gd`

- [ ] **Step 1: Inspect the test file with GodotIQ before editing**

Run `file_context(file="res://Tests/UI/test_world_run_start_scene.gd", detail="brief")`.

- [ ] **Step 2: Replace the immediate-hide assertions with the grace-period contract**

Use `script_ops(op="patch")` to replace the existing stale-exit/final-hide block with:

```gdscript
    var second_skill := launcher.get_node("%CommanderSkill1") as Button
    launcher.call("_on_commander_skill_mouse_entered", 0, first_skill)
    launcher.call("_hide_commander_skill_tooltip", first_skill)
    _expect(tooltip.visible, "skill exit keeps tooltip visible during grace period")
    launcher.call("_on_commander_skill_tooltip_mouse_entered")
    await create_timer(0.12).timeout
    _expect(tooltip.visible, "tooltip entry cancels the pending hide")
    launcher.call("_on_commander_skill_tooltip_mouse_exited")
    await create_timer(0.12).timeout
    _expect(not tooltip.visible, "leaving both hover regions hides after grace period")

    launcher.call("_on_commander_skill_mouse_entered", 0, first_skill)
    launcher.call("_hide_commander_skill_tooltip", first_skill)
    launcher.call("_on_commander_skill_mouse_entered", 1, second_skill)
    await create_timer(0.12).timeout
    _expect(tooltip.visible, "stale hide request cannot hide a newer tooltip target")
```

- [ ] **Step 3: Validate the changed test file**

Run `validate(target="res://Tests/UI/test_world_run_start_scene.gd", detail="brief")`, then `check_errors(scope="res://Tests/UI/test_world_run_start_scene.gd")`.

- [ ] **Step 4: Run the focused test and verify RED**

Run:

```powershell
godot --headless --path . --script res://Tests/UI/test_world_run_start_scene.gd
```

Expected: FAIL because `_on_commander_skill_mouse_entered` and tooltip hover handlers do not exist, and the current exit handler hides immediately.

- [ ] **Step 5: Commit the regression test**

```powershell
git add -- Tests/UI/test_world_run_start_scene.gd
git commit -m "test: reproduce commander skill tooltip flicker"
```

### Task 2: Implement one logical hover region

**Files:**
- Modify: `Scripts/Run/world_production_launcher.gd:15-48,128-134,509-539`
- Test: `Tests/UI/test_world_run_start_scene.gd`

- [ ] **Step 1: Inspect impact before changing the launcher**

Run `file_context(file="res://Scripts/Run/world_production_launcher.gd", detail="brief")`. Because private handler signatures and connections change, also run `impact_check(file="res://Scripts/Run/world_production_launcher.gd", action="change_signature", target="_hide_commander_skill_tooltip")`.

- [ ] **Step 2: Add the delay and hover state**

Use `script_ops(op="patch")` to add:

```gdscript
const TOOLTIP_HIDE_DELAY_SECONDS: float = 0.1
```

and:

```gdscript
var _active_tooltip_target_mouse_inside: bool = false
var _commander_skill_tooltip_mouse_inside: bool = false
var _tooltip_hide_request_id: int = 0
```

- [ ] **Step 3: Route mouse events through ownership handlers**

Replace the skill-button mouse connections and add tooltip connections:

```gdscript
        button.mouse_entered.connect(_on_commander_skill_mouse_entered.bind(index, button))
        button.mouse_exited.connect(_hide_commander_skill_tooltip.bind(button))
        button.focus_entered.connect(_show_commander_skill_tooltip.bind(index, button))
        button.focus_exited.connect(_hide_commander_skill_tooltip.bind(button))
    _commander_skill_tooltip.mouse_entered.connect(
        _on_commander_skill_tooltip_mouse_entered
    )
    _commander_skill_tooltip.mouse_exited.connect(
        _on_commander_skill_tooltip_mouse_exited
    )
```

- [ ] **Step 4: Implement delayed, stale-safe hiding**

Replace the tooltip hide behavior and add handlers:

```gdscript
func _on_commander_skill_mouse_entered(index: int, target: Control) -> void:
    _active_tooltip_target_mouse_inside = true
    _show_commander_skill_tooltip(index, target)


func _on_commander_skill_tooltip_mouse_entered() -> void:
    _commander_skill_tooltip_mouse_inside = true
    _tooltip_hide_request_id += 1


func _on_commander_skill_tooltip_mouse_exited() -> void:
    _commander_skill_tooltip_mouse_inside = false
    _schedule_commander_skill_tooltip_hide(_active_tooltip_target)


func _hide_commander_skill_tooltip(target: Control) -> void:
    if target != _active_tooltip_target:
        return
    _active_tooltip_target_mouse_inside = false
    _schedule_commander_skill_tooltip_hide(target)


func _schedule_commander_skill_tooltip_hide(target: Control) -> void:
    if not is_instance_valid(target):
        return
    _tooltip_hide_request_id += 1
    var request_id: int = _tooltip_hide_request_id
    await get_tree().create_timer(TOOLTIP_HIDE_DELAY_SECONDS).timeout
    if request_id != _tooltip_hide_request_id or target != _active_tooltip_target:
        return
    if (
        _active_tooltip_target_mouse_inside
        or _commander_skill_tooltip_mouse_inside
        or target.has_focus()
    ):
        return
    _active_tooltip_target = null
    _commander_skill_tooltip.hide()
```

At the start of `_show_commander_skill_tooltip`, increment `_tooltip_hide_request_id` so every new owner invalidates an older timer. When refreshing or clearing the presentation, also reset both hover booleans and increment the request ID before hiding.

- [ ] **Step 5: Validate and compile the launcher**

Run `validate(target="res://Scripts/Run/world_production_launcher.gd", detail="brief")`, then `check_errors(scope="res://Scripts/Run/world_production_launcher.gd")`.

- [ ] **Step 6: Run the focused test and verify GREEN**

Run:

```powershell
godot --headless --path . --script res://Tests/UI/test_world_run_start_scene.gd
```

Expected: exit code 0 and `PASS test_world_run_start_scene`.

- [ ] **Step 7: Commit the implementation**

```powershell
git add -- Scripts/Run/world_production_launcher.gd
git commit -m "fix: stabilize commander skill tooltip hover"
```

### Task 3: Project and Play-mode verification

**Files:**
- Verify: `Scripts/Run/world_production_launcher.gd`
- Verify: `Tests/UI/test_world_run_start_scene.gd`

- [ ] **Step 1: Run project checks**

Run `validate(target="project", detail="brief")`, `check_errors(scope="project")`, and `signal_map(scope="file:res://Scripts/Run/world_production_launcher.gd", find="all", detail="brief")`.

- [ ] **Step 2: Verify the scene launches cleanly**

Run `run(action="play")`, `verify_project_runs(scene="res://Scenes/world_run_start.tscn", check_scope="scene", stop_after=false)`, and `read_debug_console()`.

Expected: Play starts, scripts compile, and the console contains no failing errors.

- [ ] **Step 3: Exercise the interaction**

Open New Run, hover a commander skill square, move across the gap into the tooltip, remain over the tooltip, then leave both regions. Confirm the tooltip stays visible through the crossing and while hovered, then disappears once after the grace period without flicker.

- [ ] **Step 4: Stop Play mode and inspect repository state**

Run `run(action="stop")`, then `git status --short` and `git log -3 --oneline`.

Expected: only the user’s pre-existing unrelated changes remain unstaged; the design, test, and fix commits are present on `fix/brakka-banner-holder-tooltip-flicker`.
