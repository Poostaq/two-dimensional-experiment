# Skill Hover Tooltip Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace AC2.7's fixed right-docked skill preview with a shared scene-owned tooltip that is visible exactly while a skill button is hovered.

**Architecture:** Keep authored description data in `CharacterSkill` and click-selection state in `BattleArena`, but move description presentation into one floating root-level `SkillTooltipPanel`. Generated buttons bind hover signals to guarded arena handlers; a generation counter prevents stale deferred placement, and deterministic constants position the panel above the button with clamping and a below fallback.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ scene/script operations, headless `SceneTree` test runners, PowerShell verification.

**Required baseline:** Work on a dedicated task branch containing `feat/ac2-7-skill-preview` commit `95ca733` or its integrated equivalent. The task branch `plan/skill-hover-tooltip` contains that baseline through merge commit `f8b8fba`.

---

## File responsibility map

- `Scenes/battle_arena.tscn`: owns the single floating tooltip subtree and removes the fixed preview subtree.
- `Scripts/Battle/battle_arena.gd`: binds button hover signals, renders tooltip content, guards lifecycle state, and calculates placement.
- `Tests/Battle/test_ac2_7_skill_preview.gd`: proves hover-only visibility, exact content, non-actionability, lifecycle safety, defensive event handling, and placement.
- `Docs/superpowers/specs/2026-07-30-ac2-7-skill-preview-design.md`: records that only the earlier fixed-layout presentation is superseded.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: states the current AC2.7 verification contract.
- `Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/*`: captures test/runtime evidence tied to one implementation SHA.

### Task 1: Replace fixed-preview assertions with failing hover-tooltip tests

**Files:**

- Modify: `Tests/Battle/test_ac2_7_skill_preview.gd`

- [ ] **Step 1: Inspect impact and establish the focused baseline**

Use GodotIQ:

```text
file_context(file="res://Tests/Battle/test_ac2_7_skill_preview.gd", detail="brief")
impact_check(file="res://Tests/Battle/test_ac2_7_skill_preview.gd", action="modify", target="hover tooltip assertions")
```

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: exit `0` with `AC2.7 tests passed` before test changes.

- [ ] **Step 2: Change the runner to execute tooltip-focused tests**

In `_run()`, retain metadata tests and replace the three fixed-preview calls with:

```gdscript
await _test_tooltip_scene_and_hover_content()
await _test_tooltip_lifecycle_and_non_actionability()
await _test_tooltip_placement_and_event_guards()
```

- [ ] **Step 3: Add exact scene and hover-content assertions**

Replace `_test_preview_scene_and_content()` with a test that asserts `%SkillPreviewPanel` is absent; `%SkillTooltipPanel`, `%SkillTooltipNameLabel`, `%SkillTooltipKindLabel`, `%SkillTooltipEffectLabel`, `%SkillTooltipTargetingLabel`, `%SkillTooltipRequirementsLabel`, and `%SkillTooltipCooldownLabel` exist; and the panel is initially hidden. Use this interaction helper:

```gdscript
func _emit_skill_hover(button: Button, entered: bool) -> void:
	if entered:
		button.mouse_entered.emit()
	else:
		button.mouse_exited.emit()
```

Use this button lookup helper:

```gdscript
func _skill_button(arena: BattleArena, skill_id: StringName) -> Button:
	var skills := arena.get_node("%SkillInspectorSkills") as HBoxContainer
	for child: Node in skills.get_children():
		var button := child as Button
		if is_instance_valid(button) and button.get_meta("skill_id", &"") == skill_id:
			return button
	return null
```

Use this tooltip text helper:

```gdscript
func _tooltip_text(arena: BattleArena) -> Array[String]:
	var result: Array[String] = []
	for node_name: String in [
		"SkillTooltipNameLabel",
		"SkillTooltipKindLabel",
		"SkillTooltipEffectLabel",
		"SkillTooltipTargetingLabel",
		"SkillTooltipRequirementsLabel",
		"SkillTooltipCooldownLabel",
	]:
		var label := arena.get_node_or_null("%%%s" % node_name) as Label
		result.append(label.text if is_instance_valid(label) else "")
	return result
```

Inspect `player_0`, hover `shield_bash`, await one process frame, and assert the panel is visible with:

```gdscript
[
	"Shield Bash",
	"Active",
	"Effect: Deal 7 damage.",
	"Targeting: Closest active enemy.",
	"Requirements: User must occupy a front-row slot.",
	"Cooldown: 1 turn after use.",
]
```

Exit and assert the panel is hidden and `_tooltip_text(arena)` equals six empty strings. Repeat with `frontline_guard` and assert `Passive` plus `Cooldown: None` without clicking either button.

- [ ] **Step 4: Add lifecycle, placement, and duplicate-event assertions**

Adapt the existing lifecycle snapshots so hover entry/exit preserves current unit, round, log count, HP snapshot, inspected unit ID, and selected skill ID. Add assertions that:

- clicking while hovered may set `_selected_skill_id`, but exit still hides the tooltip;
- moving from one button to another displays only the new skill;
- a stale exit emitted from the old button does not hide the new tooltip;
- duplicate enters retain the correct visible tooltip;
- `inspect_unit()`, `configure_units()`, and button-row rebuilding hide the tooltip;
- an invalid skill passed through `arena.call("_on_skill_button_mouse_entered", null, button)` hides safely;
- a freed button passed to deferred placement cannot restore a tooltip.

At `1152x648`, assert the tooltip is fully inside `Rect2(Vector2.ZERO, Vector2(1152, 648))`. For normal placement assert:

```gdscript
var button_rect := button.get_global_rect()
var tooltip_rect := tooltip.get_global_rect()
_expect(tooltip_rect.end.y <= button_rect.position.y - 8.0 + 0.5, "tooltip should prefer above")
_expect(abs(tooltip_rect.get_center().x - button_rect.get_center().x) <= 0.5, "unclamped tooltip should center")
```

For deterministic fallback and edge checks, create a test-only `Button`, set `custom_minimum_size = Vector2(88, 88)`, add it directly to `arena`, and use a valid `CharacterSkill` from `player_0.skills`. Position the anchor at `Vector2(500, 4)`, call `arena.call("_on_skill_button_mouse_entered", skill, anchor)`, await one process frame, and assert `tooltip_rect.position.y >= button_rect.end.y + 8.0 - 0.5`. Repeat at `x = 0` and `x = 1152 - 88`; assert `tooltip_rect.position.x >= 12.0` and `tooltip_rect.end.x <= 1140.0`. Free the synthetic anchor after exiting hover.

- [ ] **Step 5: Run the focused test and verify the intended failure**

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: exit `1` because `%SkillTooltipPanel` does not exist and `%SkillPreviewPanel` still exists. The failure must be assertion-based, not a parser error.

- [ ] **Step 6: Validate the changed test file**

Use GodotIQ:

```text
validate(target="res://Tests/Battle/test_ac2_7_skill_preview.gd", detail="brief")
check_errors(scope="res://Tests/Battle/test_ac2_7_skill_preview.gd")
```

Expected: no parser errors.

- [ ] **Step 7: Commit the failing contract tests**

```powershell
git add -- Tests/Battle/test_ac2_7_skill_preview.gd
git commit -m "test: define skill hover tooltip contract"
```

### Task 2: Replace the fixed scene subtree with the shared tooltip

**Files:**

- Modify: `Scenes/battle_arena.tscn`

- [ ] **Step 1: Inspect the live scene before mutation**

Use GodotIQ:

```text
file_context(file="res://Scenes/battle_arena.tscn", detail="brief")
scene_map(scene="res://Scenes/battle_arena.tscn", focus="Margin/VBox/SkillInspectorPanel", radius=5, detail="brief")
```

- [ ] **Step 2: Remove the fixed preview and normalize selection layout**

Use one validated `node_ops` batch to delete `Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel`, then set `SkillSelectionRegion` to horizontal expand/fill and stretch ratio `1.0`. Do not delete `SkillInspectorBody` or the skill-selection nodes.

- [ ] **Step 3: Add the exact tooltip subtree**

Use one validated `node_ops` batch to add under the scene root:

```text
SkillTooltipPanel (PanelContainer)
└── SkillTooltipMargin (MarginContainer)
    └── SkillTooltipContent (VBoxContainer)
        ├── SkillTooltipNameLabel (Label)
        ├── SkillTooltipKindLabel (Label)
        ├── SkillTooltipEffectLabel (Label)
        ├── SkillTooltipTargetingLabel (Label)
        ├── SkillTooltipRequirementsLabel (Label)
        └── SkillTooltipCooldownLabel (Label)
```

Set the panel to `visible=false`, `unique_name_in_owner=true`, `z_index=20`, `mouse_filter=2`, and `custom_minimum_size=Vector2(288, 0)`. Set all labels to `mouse_filter=2`; set all four description labels to `autowrap_mode=2` and `custom_minimum_size=Vector2(268, 0)` so first-frame wrapped-height measurement is deterministic. Mark all six labels unique in owner.

- [ ] **Step 4: Save and verify the scene once**

Use GodotIQ:

```text
save_scene()
file_context(file="res://Scenes/battle_arena.tscn", detail="brief")
validate(target="res://Scenes/battle_arena.tscn", detail="brief")
check_errors(scope="res://Scenes/battle_arena.tscn")
```

Expected: the scene owns one `%SkillTooltipPanel`, owns no `%SkillPreviewPanel`, and has no missing script references.

- [ ] **Step 5: Run the focused test**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: still exits `1` because hover handlers/content are not implemented, while scene-node existence assertions now pass.

- [ ] **Step 6: Commit the scene structure**

```powershell
git add -- Scenes/battle_arena.tscn
git commit -m "refactor: replace fixed skill preview with tooltip scene"
```

### Task 3: Implement guarded hover rendering and deterministic placement

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Test: `Tests/Battle/test_ac2_7_skill_preview.gd`

- [ ] **Step 1: Inspect script context and change impact**

Use GodotIQ:

```text
file_context(file="res://Scripts/Battle/battle_arena.gd", detail="brief")
impact_check(file="res://Scripts/Battle/battle_arena.gd", action="modify", target="skill preview node references and hover handlers")
```

- [ ] **Step 2: Replace preview references and state**

Remove the seven `_skill_preview_*` references. Add:

```gdscript
const SKILL_TOOLTIP_VIEWPORT_MARGIN: float = 12.0
const SKILL_TOOLTIP_ANCHOR_GAP: float = 8.0

@onready var _skill_tooltip_panel: PanelContainer = %SkillTooltipPanel
@onready var _skill_tooltip_name_label: Label = %SkillTooltipNameLabel
@onready var _skill_tooltip_kind_label: Label = %SkillTooltipKindLabel
@onready var _skill_tooltip_effect_label: Label = %SkillTooltipEffectLabel
@onready var _skill_tooltip_targeting_label: Label = %SkillTooltipTargetingLabel
@onready var _skill_tooltip_requirements_label: Label = %SkillTooltipRequirementsLabel
@onready var _skill_tooltip_cooldown_label: Label = %SkillTooltipCooldownLabel

var _hovered_skill_button: Button
var _skill_tooltip_generation: int = 0
```

- [ ] **Step 3: Bind hover events when each button is created**

After the existing `pressed` connection in `_create_skill_button()`, add:

```gdscript
button.mouse_entered.connect(_on_skill_button_mouse_entered.bind(skill, button))
button.mouse_exited.connect(_on_skill_button_mouse_exited.bind(button))
```

- [ ] **Step 4: Replace fixed-preview rendering with tooltip handlers**

Delete `_get_selected_skill()`, `_refresh_skill_preview()`, and `_clear_skill_preview_text()`. Remove calls to `_refresh_skill_preview()` from `select_skill()`, `_refresh_skill_inspector()`, and `_clear_skill_inspector()`.

Add these complete handlers:

```gdscript
func _on_skill_button_mouse_entered(skill: CharacterSkill, button: Button) -> void:
	if not is_instance_valid(skill) or not skill.is_valid() or not is_instance_valid(button):
		_hide_skill_tooltip()
		return
	_hovered_skill_button = button
	_skill_tooltip_generation += 1
	var generation := _skill_tooltip_generation
	_skill_tooltip_name_label.text = skill.display_name
	_skill_tooltip_kind_label.text = "Active" if skill.kind == CharacterSkill.Kind.ACTIVE else "Passive"
	_skill_tooltip_effect_label.text = "Effect: %s" % skill.effect_text
	_skill_tooltip_targeting_label.text = "Targeting: %s" % skill.targeting_text
	_skill_tooltip_requirements_label.text = "Requirements: %s" % skill.requirements_text
	_skill_tooltip_cooldown_label.text = "Cooldown: %s" % skill.cooldown_text
	_skill_tooltip_panel.visible = true
	_skill_tooltip_panel.reset_size()
	call_deferred("_position_skill_tooltip", button, generation)


func _on_skill_button_mouse_exited(button: Button) -> void:
	if button != _hovered_skill_button:
		return
	_hide_skill_tooltip()


func _position_skill_tooltip(button_value: Variant, generation: int) -> void:
	if not is_instance_valid(button_value) or not button_value is Button:
		return
	var button := button_value as Button
	if (
		not _skill_tooltip_panel.visible
		or button != _hovered_skill_button
		or generation != _skill_tooltip_generation
	):
		return
	_skill_tooltip_panel.size = _skill_tooltip_panel.get_combined_minimum_size()
	var button_rect := button.get_global_rect()
	var tooltip_size := _skill_tooltip_panel.size
	var viewport_size := get_viewport_rect().size
	var centered_x := button_rect.position.x + (button_rect.size.x - tooltip_size.x) * 0.5
	var max_x := maxf(
		SKILL_TOOLTIP_VIEWPORT_MARGIN,
		viewport_size.x - SKILL_TOOLTIP_VIEWPORT_MARGIN - tooltip_size.x
	)
	var x := clampf(centered_x, SKILL_TOOLTIP_VIEWPORT_MARGIN, max_x)
	var above_y := button_rect.position.y - SKILL_TOOLTIP_ANCHOR_GAP - tooltip_size.y
	var below_y := button_rect.end.y + SKILL_TOOLTIP_ANCHOR_GAP
	var max_y := maxf(
		SKILL_TOOLTIP_VIEWPORT_MARGIN,
		viewport_size.y - SKILL_TOOLTIP_VIEWPORT_MARGIN - tooltip_size.y
	)
	var y := above_y if above_y >= SKILL_TOOLTIP_VIEWPORT_MARGIN else clampf(
		below_y,
		SKILL_TOOLTIP_VIEWPORT_MARGIN,
		max_y
	)
	_skill_tooltip_panel.global_position = Vector2(x, y)


func _hide_skill_tooltip() -> void:
	_skill_tooltip_generation += 1
	_hovered_skill_button = null
	if not is_node_ready():
		return
	_skill_tooltip_panel.visible = false
	_skill_tooltip_name_label.text = ""
	_skill_tooltip_kind_label.text = ""
	_skill_tooltip_effect_label.text = ""
	_skill_tooltip_targeting_label.text = ""
	_skill_tooltip_requirements_label.text = ""
	_skill_tooltip_cooldown_label.text = ""
```

- [ ] **Step 5: Make every rebuild and lifecycle clear the tooltip**

Call `_hide_skill_tooltip()` at the start of `_clear_skill_rows()` and `_clear_skill_inspector()`. Keep the existing inspected-unit and selected-skill behavior unchanged. Because `configure_units()` already calls `_clear_skill_inspector()`, reconfiguration inherits the same cleanup.

- [ ] **Step 6: Validate the production script immediately**

Use GodotIQ:

```text
validate(target="res://Scripts/Battle/battle_arena.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_arena.gd")
```

Expected: no convention or parser errors.

- [ ] **Step 7: Run the focused test and make only evidence-driven corrections**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: exit `0` with `AC2.7 tests passed`. If a placement assertion fails, adjust only sizing/coordinate behavior defined by the approved constants; do not restore a fixed preview or add hover delays.

- [ ] **Step 8: Revalidate the test after any correction**

Use GodotIQ:

```text
validate(target="res://Tests/Battle/test_ac2_7_skill_preview.gd", detail="brief")
check_errors(scope="res://Tests/Battle/test_ac2_7_skill_preview.gd")
```

- [ ] **Step 9: Commit the implementation**

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_7_skill_preview.gd
git commit -m "feat: show skill descriptions on hover"
```

### Task 4: Run regression and runtime visual gates

**Files:**

- No production changes unless a gate exposes a defect.

- [ ] **Step 1: Validate the complete project and signal graph**

Use GodotIQ:

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans")
```

Expected: no new convention, parser, or orphan-signal errors.

- [ ] **Step 2: Run AC2.1 through AC2.7 runners**

```powershell
$battleTests = @(
  'Tests/Map/test_ac2_1_battle_arena.gd',
  'Tests/Battle/test_ac2_2_speed_order.gd',
  'Tests/Battle/test_ac2_3_damage_defeat_log.gd',
  'Tests/Battle/test_ac2_4_battle_results.gd',
  'Tests/Battle/test_ac2_5_reward_selection.gd',
  'Tests/Battle/test_ac2_6_character_skills.gd',
  'Tests/Battle/test_ac2_7_skill_preview.gd'
)
foreach ($testScript in $battleTests) {
  & godot --headless --path . --script ("res://" + ($testScript -replace '\\','/'))
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: seven exit-code `0` results.

- [ ] **Step 3: Run the complete test corpus**

```powershell
$allTests = Get-ChildItem -LiteralPath Tests -Recurse -Filter '*.gd' | Sort-Object FullName
foreach ($testFile in $allTests) {
  $relative = [IO.Path]::GetRelativePath((Get-Location).Path, $testFile.FullName) -replace '\\','/'
  & godot --headless --path . --script ("res://" + $relative)
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: every runner exits `0`.

- [ ] **Step 4: Verify runtime behavior**

Use GodotIQ:

```text
run(action="play")
verify_project_runs(scene="main", check_scope="project", stop_after=false)
read_debug_console()
```

At `1152x648`, hover player active `Shield Bash`, player passive `Frontline Guard`, enemy active `Savage Blow`, and enemy passive `Blood Scent`. Confirm immediate appearance, exact content, above placement, immediate exit dismissal, no pinning after click, and no pointer flicker.

- [ ] **Step 5: Perform visual QA and stop**

Use GodotIQ:

```text
explore(mode="tour")
read_debug_console()
run(action="stop")
```

Expected: the tooltip is fully visible, the skill inspector has no fixed description column, skill buttons use the released width, and the debugger has no new errors.

### Task 5: Update AC2.7 documentation and traceable evidence

**Files:**

- Modify: `Docs/superpowers/specs/2026-07-30-ac2-7-skill-preview-design.md`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/implementation-link.txt`

- [ ] **Step 1: Record the verified implementation SHA**

```powershell
$implementationSha = git rev-parse HEAD
if ($implementationSha -notmatch '^[0-9a-f]{40}$') { throw 'Expected full implementation SHA.' }
```

- [ ] **Step 2: Update design and MVP wording**

Add a supersession note to the 2026-07-30 design pointing to `Docs/superpowers/specs/2026-07-31-skill-hover-tooltip-design.md`. In the AC2.7 verification row of `GAME_DESIGN_SPEC_MVP.md`, replace fixed right-docked width requirements with: hover any active or passive skill without clicking; verify all six structured fields; exit and verify immediate dismissal; click then exit and verify no pinning; verify above placement, horizontal clamping, below fallback, and full visibility at `1152x648`.

- [ ] **Step 3: Write the evidence package with the exact tested SHA**

`automated-test.log` records the seven AC2 commands from Task 4, their PASS results, and `$implementationSha`. `manual-runtime-check.md` records the four named active/passive fixtures, immediate show/hide behavior, click non-pinning, placement/clamping/fallback, target viewport, and no debugger errors against `$implementationSha`. `implementation-link.txt` contains only `$implementationSha` and a trailing newline.

- [ ] **Step 4: Validate evidence consistency**

```powershell
$sha = (Get-Content -Raw 'Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/implementation-link.txt').Trim()
$auto = Get-Content -Raw 'Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/automated-test.log'
$manual = Get-Content -Raw 'Docs/Specs/AC2/Evidence/AC2.7/2026-07-31/manual-runtime-check.md'
if ($sha -notmatch '^[0-9a-f]{40}$') { throw 'Invalid implementation SHA.' }
if (-not $auto.Contains($sha) -or -not $manual.Contains($sha)) { throw 'Evidence SHA mismatch.' }
if (-not $auto.Contains('Result: PASS') -or -not $manual.Contains('Result: PASS')) { throw 'Evidence is not passing.' }
```

Expected: no output and exit `0`.

- [ ] **Step 5: Commit documentation and evidence**

```powershell
git add -- Docs/superpowers/specs/2026-07-30-ac2-7-skill-preview-design.md Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.7/2026-07-31
git commit -m "docs: record skill hover tooltip verification"
```

### Task 6: Final completion gate

**Files:**

- No changes expected.

- [ ] **Step 1: Re-run focused verification after documentation commit**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
git diff --check
git status --short
```

Expected: the test exits `0`, `git diff --check` emits nothing, and only intentionally ignored/untracked local companion artifacts may remain.

- [ ] **Step 2: Confirm commit scope**

```powershell
git log --oneline --decorate -6
git diff --stat main...HEAD
```

Expected: implementation, test, scene, design, and evidence commits are present; no unrelated user files are staged or modified.
