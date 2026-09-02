# AC6.5 Commander Screen Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the AC6.5 New Run controls clearer borders and replace delayed native skill tooltips with an immediate, readable, bounded tooltip panel.

**Architecture:** Keep the behavior screen-local. The scene owns tooltip nodes and style resources; `WorldProductionLauncher` owns tooltip state, formatting, anchoring, and hover/focus precedence; the existing UI scene runner verifies the real packed scene and launcher together.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ scene/script operations, headless `SceneTree` UI tests.

---

## File ownership

- Modify `Tests/UI/test_world_run_start_scene.gd`: executable acceptance coverage for border resources, disabled arrows, tooltip formatting, synchronous presentation, wrapping, font hierarchy, and stale-exit precedence.
- Modify `Scenes/world_run_start.tscn`: screen-local tooltip panel/labels and StyleBoxFlat overrides for carousel, skill, Back, and Begin buttons.
- Modify `Scripts/Run/world_production_launcher.gd`: immediate tooltip signals, presentation normalization, active-target precedence, and clamped placement.
- Create no runtime scripts or global project settings. Do not modify commander data, battle behavior, save data, or the accepted layout.

### Task 1: Specify the tooltip and border contract in the UI runner

**Files:**
- Modify: `Tests/UI/test_world_run_start_scene.gd`
- Test: `Tests/UI/test_world_run_start_scene.gd`

- [ ] **Step 1: Extend the required-node contract**

Add the three unique tooltip nodes to `REQUIRED_UNIQUE_NODES`:

```gdscript
    &"CommanderSkillTooltip",
    &"CommanderSkillTooltipName",
    &"CommanderSkillTooltipBody",
```

- [ ] **Step 2: Add failing border assertions**

After opening New Run, assert that disabled arrows retain non-interactive behavior and a visible two-pixel disabled border, every skill has a normal border, the active-skill border color is grey, the passive border color differs, and Back/Begin have normal borders:

```gdscript
var arrow_border := previous.get_theme_stylebox("disabled") as StyleBoxFlat
_expect(previous.disabled and next.disabled, "single-entry carousel arrows are disabled")
_expect(previous.focus_mode == Control.FOCUS_NONE, "disabled previous arrow rejects keyboard focus")
_expect(next.focus_mode == Control.FOCUS_NONE, "disabled next arrow rejects keyboard focus")
_expect(
    is_instance_valid(arrow_border) and arrow_border.border_width_left == 2,
    "disabled carousel arrows retain a two-pixel border"
)

var active_style := launcher.get_node("%CommanderSkill0").get_theme_stylebox("normal") as StyleBoxFlat
var passive_style := launcher.get_node("%CommanderSkill3").get_theme_stylebox("normal") as StyleBoxFlat
_expect(is_instance_valid(active_style) and active_style.border_width_left == 2, "active skill has grey border")
_expect(is_instance_valid(passive_style) and passive_style.border_width_left == 2, "passive has matching border weight")
_expect(active_style.border_color != passive_style.border_color, "passive retains distinct gold accent")
_expect(launcher.get_node("%BackButton").has_theme_stylebox_override("normal"), "Back has screen border styling")
_expect(begin.has_theme_stylebox_override("normal"), "Begin has screen border styling")
```

- [ ] **Step 3: Add failing immediate-tooltip assertions**

Replace the native `tooltip_text` assertion with a test of the screen-owned panel. Activate skill zero through the same handler used by `mouse_entered`, then verify the required copy and layout contract synchronously:

```gdscript
var tooltip := launcher.get_node("%CommanderSkillTooltip") as PanelContainer
var tooltip_name := launcher.get_node("%CommanderSkillTooltipName") as Label
var tooltip_body := launcher.get_node("%CommanderSkillTooltipBody") as Label
var first_skill := launcher.get_node("%CommanderSkill0") as Button
launcher.call("_show_commander_skill_tooltip", 0, first_skill)
_expect(tooltip.visible, "hover handler shows tooltip without delay")
_expect(not tooltip_name.text.is_empty(), "tooltip shows the skill name")
_expect(tooltip_body.text.contains("Cooldown: 1 turn"), "cooldown uses readable singular wording")
_expect(tooltip_body.text.contains("Target:"), "target line always has its prefix")
_expect(tooltip_body.autowrap_mode != TextServer.AUTOWRAP_OFF, "tooltip body wraps")
_expect(tooltip.custom_minimum_size.x == 340.0, "tooltip width is capped at 340 pixels")
_expect(
    tooltip_name.get_theme_font_size("font_size") == tooltip_body.get_theme_font_size("font_size") + 2,
    "tooltip name is two points larger than body copy"
)
```

- [ ] **Step 4: Add failing precedence and clamping assertions**

Exercise two activations and a stale exit; the most recent target must remain visible. After one frame, verify the eight-pixel viewport margin:

```gdscript
var second_skill := launcher.get_node("%CommanderSkill1") as Button
launcher.call("_show_commander_skill_tooltip", 0, first_skill)
launcher.call("_show_commander_skill_tooltip", 1, second_skill)
launcher.call("_hide_commander_skill_tooltip", first_skill)
_expect(tooltip.visible, "stale exit cannot hide the newer tooltip target")
await process_frame
var viewport_size := launcher.get_viewport_rect().size
_expect(tooltip.global_position.x >= 8.0 and tooltip.global_position.y >= 8.0, "tooltip respects top-left viewport margin")
_expect(tooltip.global_position.x + tooltip.size.x <= viewport_size.x - 8.0, "tooltip clamps to viewport right margin")
_expect(tooltip.global_position.y + tooltip.size.y <= viewport_size.y - 8.0, "tooltip clamps to viewport bottom margin")
launcher.call("_hide_commander_skill_tooltip", second_skill)
_expect(not tooltip.visible, "active target exit hides tooltip")
```

- [ ] **Step 5: Validate the edited runner and prove RED**

Run GodotIQ `validate(target="res://Tests/UI/test_world_run_start_scene.gd", detail="brief")`, then `check_errors(scope="res://Tests/UI/test_world_run_start_scene.gd")`.

Run:

```powershell
$godot = 'D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe'
$process = Start-Process -FilePath $godot -ArgumentList '--headless','--path','.','--script','res://Tests/UI/test_world_run_start_scene.gd' -NoNewWindow -Wait -PassThru
exit $process.ExitCode
```

Expected: exit code `1`, with failures for missing tooltip nodes/styles or missing `_show_commander_skill_tooltip`; no parser error.

- [ ] **Step 6: Commit the executable contract**

```powershell
git add -- Tests/UI/test_world_run_start_scene.gd
git commit -m "test: specify commander screen tooltip polish"
```

### Task 2: Add scene-owned tooltip presentation and border styles

**Files:**
- Modify: `Scenes/world_run_start.tscn`
- Test: `Tests/UI/test_world_run_start_scene.gd`

- [ ] **Step 1: Inspect before editing**

Use GodotIQ `file_context(file="res://Scenes/world_run_start.tscn", detail="brief")`, then `scene_map(scene="res://Scenes/world_run_start.tscn", focus="NewRunCenter", radius=8, detail="brief")`.

- [ ] **Step 2: Add the tooltip nodes with GodotIQ scene operations**

Under the New Run screen's overlay-capable Control, add this hierarchy with unique names enabled on the three named nodes:

```text
CommanderSkillTooltip (PanelContainer, hidden, z_index 20, mouse_filter IGNORE, custom_minimum_size 340x0)
└── TooltipMargin (MarginContainer, 12 px on every side)
    └── TooltipContent (VBoxContainer, separation 6)
        ├── CommanderSkillTooltipName (Label, font_size 18, autowrap WORD_SMART)
        └── CommanderSkillTooltipBody (Label, font_size 16, autowrap WORD_SMART)
```

Give the panel the existing dark-blue panel fill and existing light-grey outline so the body maintains contrast. Set `clip_contents` on the appropriate tooltip container and size the panel to 340 pixels; the launcher will calculate height from wrapped content.

- [ ] **Step 3: Add the palette-backed button borders**

Using StyleBoxFlat resources in the scene, apply two-pixel borders as follows:

```text
PreviousCommanderButton / NextCommanderButton:
  disabled: existing dark button fill + existing light-grey border at strongest disabled opacity
  normal/hover/focus: same light-grey token, with hover/focus brighter than normal

CommanderSkill0..2:
  normal: existing skill fill + restrained light-grey border
  hover/focus: same token at higher contrast

CommanderSkill3:
  normal/hover/focus: preserve existing passive-gold border color, two-pixel width

BackButton / BeginButton:
  normal/hover/focus: existing fills plus restrained light-grey border
```

Reuse the colors already present in this scene's panel/button palette; do not invent a second grey or gold hue. Set disabled arrows to `focus_mode = Control.FOCUS_NONE` in addition to `disabled = true`.

- [ ] **Step 4: Save and validate the scene**

Use GodotIQ `save_scene()`, then `validate(target="res://Scenes/world_run_start.tscn", detail="brief")`.

Expected: no missing-resource or incomplete-Control findings.

- [ ] **Step 5: Run the UI runner and confirm it remains RED only for launcher behavior**

Run the Task 1 PowerShell command.

Expected: tooltip nodes and border assertions pass; runner still exits `1` because the launcher tooltip handlers do not exist.

- [ ] **Step 6: Commit scene presentation**

```powershell
git add -- Scenes/world_run_start.tscn
git commit -m "feat: style commander selection controls"
```

### Task 3: Implement immediate tooltip behavior

**Files:**
- Modify: `Scripts/Run/world_production_launcher.gd`
- Test: `Tests/UI/test_world_run_start_scene.gd`

- [ ] **Step 1: Inspect launcher impact before editing**

Use GodotIQ `file_context(file="res://Scripts/Run/world_production_launcher.gd", detail="brief")`. The added methods remain private, so no public-signature impact check is required.

- [ ] **Step 2: Add tooltip constants, state, and node references**

Add:

```gdscript
const TOOLTIP_WIDTH: float = 340.0
const TOOLTIP_OFFSET := Vector2(10.0, 8.0)
const TOOLTIP_VIEWPORT_MARGIN: float = 8.0

var _presented_commander_skills: Array[CharacterSkill] = []
var _active_tooltip_target: Control

@onready var _commander_skill_tooltip: PanelContainer = %CommanderSkillTooltip
@onready var _commander_skill_tooltip_name: Label = %CommanderSkillTooltipName
@onready var _commander_skill_tooltip_body: Label = %CommanderSkillTooltipBody
```

- [ ] **Step 3: Wire immediate hover and focus activation**

In `_ready()`, connect each populated button by index. Bind the source button into both show and hide callbacks so stale exits can be ignored:

```gdscript
for index: int in _commander_skill_buttons.size():
    var button: Button = _commander_skill_buttons[index]
    button.mouse_entered.connect(_show_commander_skill_tooltip.bind(index, button))
    button.mouse_exited.connect(_hide_commander_skill_tooltip.bind(button))
    button.focus_entered.connect(_show_commander_skill_tooltip.bind(index, button))
    button.focus_exited.connect(_hide_commander_skill_tooltip.bind(button))
```

This produces last-activation-wins behavior: every hover/focus activation replaces `_active_tooltip_target`; an exit hides only when its source is still active.

- [ ] **Step 4: Retain authoritative skills without native delayed tooltips**

In `_refresh_commander_ui()`, assign the presentation array to `_presented_commander_skills`, clear `button.tooltip_text`, and keep disabled slots empty. Do not alter skill resources:

```gdscript
_presented_commander_skills.clear()
for value: Variant in skills:
    var skill := value as CharacterSkill
    if is_instance_valid(skill):
        _presented_commander_skills.append(skill)

button.tooltip_text = ""
```

Hide the panel if the commander presentation refresh invalidates the current target.

- [ ] **Step 5: Add readable formatting helpers**

Add presentation-only helpers:

```gdscript
func _format_cooldown(value: String) -> String:
    var compact := value.strip_edges()
    if compact.begins_with("CD") and compact.substr(2).is_valid_int():
        var turns := compact.substr(2).to_int()
        return "Cooldown: %d %s" % [turns, "turn" if turns == 1 else "turns"]
    if compact.begins_with("Cooldown:"):
        return compact
    return "Cooldown: %s" % compact


func _format_target(value: String) -> String:
    var target := value.strip_edges()
    return target if target.begins_with("Target:") else "Target: %s" % target
```

- [ ] **Step 6: Add immediate show/hide and clamped placement**

Add:

```gdscript
func _show_commander_skill_tooltip(index: int, target: Control) -> void:
    if index < 0 or index >= _presented_commander_skills.size():
        return
    var skill: CharacterSkill = _presented_commander_skills[index]
    _active_tooltip_target = target
    _commander_skill_tooltip_name.text = skill.display_name
    _commander_skill_tooltip_body.text = "\n".join([
        _format_cooldown(skill.cooldown_text),
        skill.effect_text,
        _format_target(skill.targeting_text),
    ])
    _commander_skill_tooltip.show()
    _position_commander_skill_tooltip.call_deferred(target)


func _hide_commander_skill_tooltip(target: Control) -> void:
    if target != _active_tooltip_target:
        return
    _active_tooltip_target = null
    _commander_skill_tooltip.hide()


func _position_commander_skill_tooltip(target: Control) -> void:
    if target != _active_tooltip_target or not _commander_skill_tooltip.visible:
        return
    _commander_skill_tooltip.reset_size()
    _commander_skill_tooltip.size.x = TOOLTIP_WIDTH
    var viewport_size := get_viewport_rect().size
    var desired := target.global_position + Vector2(target.size.x, 0.0) + TOOLTIP_OFFSET
    var maximum := viewport_size - _commander_skill_tooltip.size - Vector2.ONE * TOOLTIP_VIEWPORT_MARGIN
    _commander_skill_tooltip.global_position = desired.clamp(
        Vector2.ONE * TOOLTIP_VIEWPORT_MARGIN,
        maximum
    )
```

If Godot requires the width before resolving wrapped height, set width, await one deferred layout pass, then clamp; preserve the same public behavior and constants.

- [ ] **Step 7: Validate the launcher after the code change**

Run GodotIQ `validate(target="res://Scripts/Run/world_production_launcher.gd", detail="brief")`, then `check_errors(scope="res://Scripts/Run/world_production_launcher.gd")`.

Expected: zero parser/type errors and no new convention findings.

- [ ] **Step 8: Run the focused test to prove GREEN**

Run the Task 1 PowerShell command.

Expected: exit code `0` and `PASS test_world_run_start_scene`.

- [ ] **Step 9: Commit launcher behavior**

```powershell
git add -- Scripts/Run/world_production_launcher.gd
git commit -m "feat: show immediate commander skill tooltips"
```

### Task 4: Runtime and regression verification

**Files:**
- Verify: `Scenes/world_run_start.tscn`
- Verify: `Scripts/Run/world_production_launcher.gd`
- Verify: `Tests/UI/test_world_run_start_scene.gd`

- [ ] **Step 1: Run project-level static checks**

Use GodotIQ `validate(target="project", detail="brief")`, `check_errors(scope="project")`, and `signal_map(find="orphans")`.

Expected: no new errors and no orphan signals introduced by the tooltip wiring.

- [ ] **Step 2: Run the launcher-focused regression set**

Run each test with the exact `Start-Process` pattern from Task 1:

```text
res://Tests/UI/test_world_run_start_scene.gd
res://Tests/Run/test_world_production_launcher.gd
res://Tests/Run/test_world_run_start_service.gd
res://Tests/Save/test_world_run_save_codec_v2.gd
res://Tests/Run/test_world_cutover_entry.gd
```

Expected for every runner: process exit code `0`, its `PASS ...` marker, and no `SCRIPT ERROR` or `ERROR:` lines.

- [ ] **Step 3: Verify live launch and visual behavior**

Use GodotIQ `run(action="play")`, `verify_project_runs(scene="main", check_scope="project", stop_after=false)`, and `read_debug_console()`; open New Run through the production UI. Use `ui_map` to obtain exact skill-button coordinates, move the pointer onto each of the four skill squares, and take one screenshot at the verification point.

Explicit manual checks:

```text
[ ] Previous/next arrows are disabled, cannot receive focus/click activation, and retain bright grey borders.
[ ] Active skill squares have restrained grey borders; Banner Holder remains gold-accented.
[ ] Back and Begin borders are visible and Begin remains visually primary.
[ ] Each tooltip appears on pointer entry without the native delay.
[ ] Each tooltip title is visibly larger than its wrapped body text.
[ ] Cooldown reads “Cooldown: 1 turn” for one-turn skills; target starts with “Target:”.
[ ] Tooltip stays within an eight-pixel viewport margin, including the rightmost skill.
[ ] Moving quickly between skills leaves the newest skill tooltip visible; leaving it hides the panel.
[ ] Keyboard focus presents the same content and disabled arrows remain absent from focus navigation.
```

Stop with GodotIQ `run(action="stop")`.

- [ ] **Step 4: Confirm the worktree contains only intended changes**

```powershell
git status --short
git diff --check HEAD~3..HEAD
git log -5 --oneline
```

Expected: only the three owned implementation files and their focused commits are present; preserve the pre-existing untracked `Docs/Specs/AC6/Evidence/AC6.5/2026-09-02/screenshots/new-run.png.import` without staging or deleting it.
