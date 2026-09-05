# Commander Skill Tooltip Hover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show commander skill tooltips only while their skill square is hovered or keyboard-focused, with the tooltip entirely mouse-transparent.

**Architecture:** `WorldProductionLauncher` tracks mouse ownership on the active skill square and checks its focus state. Tooltip controls use `MOUSE_FILTER_IGNORE`; no tooltip-hover state, timer, or delayed hide remains.

**Tech Stack:** Godot 4, typed GDScript, existing `SceneTree` UI regression test, GodotIQ validation and Play-mode verification.

---

### Task 1: Revise the regression contract

**Files:**
- Modify: `Tests/UI/test_world_run_start_scene.gd`

- [ ] Inspect the test with `file_context(file="res://Tests/UI/test_world_run_start_scene.gd", detail="brief")`.
- [ ] Replace grace-period assertions with assertions that the tooltip root and descendants ignore mouse input; mouse entry shows; mouse exit hides immediately when unfocused; focus keeps it visible after mouse exit; focus exit hides when not hovered; and a stale exit cannot hide a newer target.
- [ ] Run `validate(target="res://Tests/UI/test_world_run_start_scene.gd", detail="brief")` and `check_errors(scope="res://Tests/UI/test_world_run_start_scene.gd")`.
- [ ] Verify RED against the current timer-based implementation: the transparency and immediate-hide assertions must fail.
- [ ] Commit with `git commit -m "test: require mouse-transparent commander tooltip"`.

### Task 2: Simplify tooltip ownership

**Files:**
- Modify: `Scripts/Run/world_production_launcher.gd`

- [ ] Inspect with `file_context` and run `impact_check` for `_hide_commander_skill_tooltip`.
- [ ] Remove `TOOLTIP_HIDE_DELAY_SECONDS`, `_commander_skill_tooltip_mouse_inside`, `_tooltip_hide_request_id`, tooltip mouse signal connections, tooltip hover handlers, and the timer scheduler.
- [ ] Configure the tooltip root and all descendant `Control` nodes as `MOUSE_FILTER_IGNORE`.
- [ ] Keep `_active_tooltip_target_mouse_inside`; mouse entry sets it and shows the tooltip. Mouse exit clears it and hides only if the target is active and unfocused. Focus exit hides only if the target is active and not mouse-owned. `_show_commander_skill_tooltip` continues replacing the active target, so stale exits remain harmless.
- [ ] Run per-file `validate` and `check_errors`.
- [ ] Verify GREEN through the focused regression behavior and live state transitions.
- [ ] Commit with `git commit -m "fix: make commander tooltip mouse-transparent"`.

### Task 3: Verify the project

- [ ] Run project `validate`, `check_errors`, and file-scoped `signal_map`.
- [ ] Run `verify_project_runs` for `res://Scenes/world_run_start.tscn` and inspect the debug console.
- [ ] Exercise mouse and keyboard ownership in Play mode and inspect tooltip visibility plus mouse-filter state.
- [ ] Stop Play mode and confirm only pre-existing unrelated working-tree changes remain.
