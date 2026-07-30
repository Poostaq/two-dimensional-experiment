# AC2.7 Structured Skill Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every existing player and enemy fixture skill a validated four-field description and show the selected active or passive skill in a measurable right-docked preview before any action is committed.

**Architecture:** Extend `CharacterSkill` so identity, kind, and preview metadata share one defensively copied value contract. Keep `BattleArena` presentation-only: it reads the selected unit's skill, renders a scene-owned preview in the existing inspector, and never executes or enforces the described mechanics.

**Tech Stack:** Godot 4, typed GDScript, scene-owned `Control`/`Container` UI, standalone headless `SceneTree` test runners, GodotIQ validation and runtime inspection.

---

## File map

- Modify `Scripts/Battle/character_skill.gd`: add and validate four read-only preview fields and preserve them during duplication.
- Modify `Scripts/Battle/battle_arena.gd`: author exact fixture previews and render selected-skill preview state.
- Modify `Scenes/battle_arena.tscn`: split the existing inspector body into a 70/30 selection/preview layout.
- Modify `Tests/Battle/test_ac2_6_character_skills.gd`: keep AC2.6 fixtures valid under the expanded required constructor without changing AC2.6 assertions.
- Create `Tests/Battle/test_ac2_7_skill_preview.gd`: focused model, fixture, UI, lifecycle, non-actionability, and layout coverage.
- Create `Tests/Battle/test_ac2_7_skill_preview.gd.uid`: Godot-generated UID companion.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: check AC2.7 and replace its manual-only verification row after every gate passes.
- Create `Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/automated-test.log`: captured focused and regression output from the tested implementation commit.
- Create `Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/manual-runtime-check.md`: measurable runtime and readability record.
- Create `Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/implementation-link.txt`: exact tested commit SHA.

Do not modify AC2.8 or AC2.9 implementation state. Do not add skill execution, cooldown state, targeting enforcement, passive application, or combo logic.

### Task 1: Expand the CharacterSkill contract test-first

**Files:**

- Modify: `Scripts/Battle/character_skill.gd`
- Modify: `Tests/Battle/test_ac2_6_character_skills.gd`
- Create: `Tests/Battle/test_ac2_7_skill_preview.gd`

- [ ] **Step 1: Inspect the affected APIs and signature impact**

Use GodotIQ:

```text
file_context(res://Scripts/Battle/character_skill.gd, detail=brief)
impact_check(
  res://Scripts/Battle/character_skill.gd,
  action=add_parameter,
  target=_init,
  change_description="Require effect, targeting, requirements, and cooldown preview text."
)
file_context(res://Tests/Battle/test_ac2_6_character_skills.gd, detail=brief)
```

Expected: callers include the battle fixtures and AC2.6 tests; no signal contract changes.

- [ ] **Step 2: Create the focused runner with failing model tests**

Create `Tests/Battle/test_ac2_7_skill_preview.gd` as a standalone `SceneTree` runner. The first test batch must exercise this exact valid definition:

```gdscript
const ARENA_PATH := "res://Scenes/battle_arena.tscn"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_structured_preview_contract()
	_test_blank_preview_rejection()
	_test_preview_duplication()
	if _failures.is_empty():
		print("AC2.7 tests passed")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_structured_preview_contract() -> void:
	var skill := CharacterSkill.create(
		&"shield_bash",
		"Shield Bash",
		CharacterSkill.Kind.ACTIVE,
		"Deal 7 damage.",
		"Closest active enemy.",
		"User must occupy a front-row slot.",
		"1 turn after use."
	)
	_expect(is_instance_valid(skill), "complete structured preview should be valid")
	if not is_instance_valid(skill):
		return
	_expect(skill.effect_text == "Deal 7 damage.", "effect text should be exact")
	_expect(skill.targeting_text == "Closest active enemy.", "targeting text should be exact")
	_expect(
		skill.requirements_text == "User must occupy a front-row slot.",
		"requirements text should be exact"
	)
	_expect(skill.cooldown_text == "1 turn after use.", "cooldown text should be exact")


func _test_blank_preview_rejection() -> void:
	var valid := ["Effect", "Target", "Requirement", "None"]
	for blank_index: int in 4:
		var fields := valid.duplicate()
		fields[blank_index] = " \t "
		var skill := CharacterSkill.create(
			&"invalid_preview",
			"Invalid Preview",
			CharacterSkill.Kind.ACTIVE,
			fields[0],
			fields[1],
			fields[2],
			fields[3]
		)
		_expect(skill == null, "blank preview field %d should be rejected" % blank_index)
	var explicit_none := CharacterSkill.create(
		&"explicit_none",
		"Explicit None",
		CharacterSkill.Kind.PASSIVE,
		"Prevent one hit.",
		"Self.",
		"None",
		"None"
	)
	_expect(is_instance_valid(explicit_none), "literal None should be valid authored content")


func _test_preview_duplication() -> void:
	var source := CharacterSkill.create(
		&"brace",
		"Brace",
		CharacterSkill.Kind.PASSIVE,
		"Reduce the first damage received each round by 2.",
		"Self.",
		"None",
		"None"
	)
	var copy := source.duplicate_skill()
	_expect(copy != source, "duplicate should be a distinct object")
	_expect(copy.effect_text == source.effect_text, "duplicate should preserve effect")
	_expect(copy.targeting_text == source.targeting_text, "duplicate should preserve targeting")
	_expect(copy.requirements_text == source.requirements_text, "duplicate should preserve requirements")
	_expect(copy.cooldown_text == source.cooldown_text, "duplicate should preserve cooldown")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
```

- [ ] **Step 3: Run the focused test and confirm the intended failure**

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: parser or call-arity failure because the four preview properties and constructor parameters do not exist.

- [ ] **Step 4: Replace CharacterSkill with the expanded validated contract**

Use `script_ops` patch mode after `file_context`. Preserve the existing enum and add this exact public/backing-field and construction behavior:

```gdscript
var effect_text: String:
	get:
		return _effect_text
var targeting_text: String:
	get:
		return _targeting_text
var requirements_text: String:
	get:
		return _requirements_text
var cooldown_text: String:
	get:
		return _cooldown_text

var _effect_text: String = ""
var _targeting_text: String = ""
var _requirements_text: String = ""
var _cooldown_text: String = ""
```

Use this exact expanded method contract:

```gdscript
func _init(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> void:
	if not is_valid_definition(id, name, skill_kind, effect, targeting, requirements, cooldown):
		push_error("CharacterSkill requires non-blank identity, preview fields, and a valid kind.")
		return
	_skill_id = id
	_display_name = name
	_kind = skill_kind as Kind
	_effect_text = effect
	_targeting_text = targeting
	_requirements_text = requirements
	_cooldown_text = cooldown
	_is_valid = true


static func create(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> CharacterSkill:
	var skill := CharacterSkill.new(
		id, name, skill_kind, effect, targeting, requirements, cooldown
	)
	return skill if skill.is_valid() else null


static func is_valid_definition(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> bool:
	return (
		not String(id).strip_edges().is_empty()
		and not name.strip_edges().is_empty()
		and skill_kind in [Kind.ACTIVE, Kind.PASSIVE]
		and not effect.strip_edges().is_empty()
		and not targeting.strip_edges().is_empty()
		and not requirements.strip_edges().is_empty()
		and not cooldown.strip_edges().is_empty()
	)


func duplicate_skill() -> CharacterSkill:
	if not _is_valid:
		return null
	return CharacterSkill.new(
		_skill_id,
		_display_name,
		_kind,
		_effect_text,
		_targeting_text,
		_requirements_text,
		_cooldown_text
	)
```

- [ ] **Step 5: Update AC2.6-only test construction without changing its assertions**

Every valid skill constructed inside `Tests/Battle/test_ac2_6_character_skills.gd` must receive four nonblank preview arguments. Use deterministic neutral values when that runner does not assert copy:

```gdscript
"Test effect.",
"Test target.",
"None",
"None"
```

For invalid ID/name/kind tests, keep the field under test invalid and supply valid neutral preview values. For the direct-copy assertion, add exact preview assertions so the expanded required contract cannot silently regress.

- [ ] **Step 6: Validate and run model tests**

Run:

```text
validate(target=res://Scripts/Battle/character_skill.gd, detail=brief)
check_errors(scope=res://Scripts/Battle/character_skill.gd)
validate(target=res://Tests/Battle/test_ac2_7_skill_preview.gd, detail=brief)
check_errors(scope=res://Tests/Battle/test_ac2_7_skill_preview.gd)
```

Then:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
```

Expected: both exit `0`; focused output contains `AC2.7 tests passed`.

- [ ] **Step 7: Commit the model contract**

```powershell
git add -- Scripts/Battle/character_skill.gd Tests/Battle/test_ac2_6_character_skills.gd Tests/Battle/test_ac2_7_skill_preview.gd Tests/Battle/test_ac2_7_skill_preview.gd.uid
git commit -m "feat: add structured AC2.7 skill previews"
```

### Task 2: Author and verify all eleven fixture previews

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac2_7_skill_preview.gd`

- [ ] **Step 1: Add a failing exact-fixture test**

Extend the focused runner with a table keyed by `skill_id`. Each value must contain name, kind, effect, targeting, requirements, and cooldown:

```gdscript
const EXPECTED_PREVIEWS := {
	&"shield_bash": ["Shield Bash", CharacterSkill.Kind.ACTIVE, "Deal 7 damage.", "Closest active enemy.", "User must occupy a front-row slot.", "1 turn after use."],
	&"frontline_guard": ["Frontline Guard", CharacterSkill.Kind.PASSIVE, "Reduce the next damage taken by an adjacent ally by 3.", "Adjacent active allies.", "User must occupy a front-row slot.", "None"],
	&"quick_step": ["Quick Step", CharacterSkill.Kind.ACTIVE, "Gain 2 Speed until the end of the next turn.", "Self.", "None", "2 turns after use."],
	&"quick_strike": ["Quick Strike", CharacterSkill.Kind.ACTIVE, "Deal 5 damage.", "Closest active enemy.", "None", "None"],
	&"rally": ["Rally", CharacterSkill.Kind.ACTIVE, "Grant all active allies 2 Speed until the end of the round.", "All active allies, including the user.", "None", "2 turns after use."],
	&"evasion": ["Evasion", CharacterSkill.Kind.PASSIVE, "Prevent the first damage instance received each round.", "Self.", "None", "None"],
	&"momentum": ["Momentum", CharacterSkill.Kind.PASSIVE, "Gain 1 Speed after taking an action, lasting until battle ends.", "Self.", "User must remain active.", "None"],
	&"savage_blow": ["Savage Blow", CharacterSkill.Kind.ACTIVE, "Deal 12 damage.", "Closest active enemy.", "User must be above 50% HP.", "2 turns after use."],
	&"blood_scent": ["Blood Scent", CharacterSkill.Kind.PASSIVE, "Deal 3 additional damage to injured enemies.", "Enemies below 50% HP.", "Target must be below 50% HP.", "None"],
	&"brace": ["Brace", CharacterSkill.Kind.PASSIVE, "Reduce the first damage received each round by 2.", "Self.", "None", "None"],
	&"shadow_lunge": ["Shadow Lunge", CharacterSkill.Kind.ACTIVE, "Deal 10 damage.", "Farthest active enemy.", "User must occupy a back-row slot.", "Unavailable for the first turn of battle; none after use."],
}
```

Instantiate the arena, await `process_frame`, traverse all twelve runtime units through their stable IDs, and assert:

```gdscript
_expect(seen_ids.size() == 11, "fixtures should expose exactly eleven unique skills")
for expected_id: StringName in EXPECTED_PREVIEWS:
	_expect(seen_ids.has(expected_id), "fixture should contain %s" % expected_id)
```

For each skill, compare all six values exactly and assert both player and enemy sides contribute at least one active and one passive skill.

- [ ] **Step 2: Run the fixture test and confirm failure**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: failure because runtime fixtures still call the three-argument constructor.

- [ ] **Step 3: Add an exact fixture factory and replace all eleven calls**

After `file_context` and `impact_check` for `_create_debug_units`, use this helper:

```gdscript
func _create_skill(
	id: StringName,
	name: String,
	kind: CharacterSkill.Kind,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> CharacterSkill:
	return CharacterSkill.new(id, name, kind, effect, targeting, requirements, cooldown)
```

Replace each fixture construction with the exact values in `EXPECTED_PREVIEWS`. Do not change unit IDs, names, sides, slots, speed, HP, skill order, or zero-skill fixtures.

- [ ] **Step 4: Validate and run fixture plus AC2.6 regressions**

```text
validate(target=res://Scripts/Battle/battle_arena.gd, detail=brief)
check_errors(scope=res://Scripts/Battle/battle_arena.gd)
```

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
```

Expected: both exit `0`, with exactly eleven unique approved fixture skills.

- [ ] **Step 5: Commit exact fixture metadata**

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_7_skill_preview.gd
git commit -m "feat: author AC2.7 fixture descriptions"
```

### Task 3: Build the right-docked scene-owned preview

**Files:**

- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac2_7_skill_preview.gd`

- [ ] **Step 1: Add failing scene ownership and presentation-state tests**

Add assertions for these unique scene-owned nodes:

```text
%SkillSelectionRegion
%SkillPreviewPanel
%SkillPreviewPromptLabel
%SkillPreviewNameLabel
%SkillPreviewKindLabel
%SkillPreviewEffectLabel
%SkillPreviewTargetingLabel
%SkillPreviewRequirementsLabel
%SkillPreviewCooldownLabel
```

Verify initial inspected-character state shows the exact prompt:

```text
Select a skill to inspect its description.
```

After selecting `shield_bash`, verify the prompt is hidden and exact visible text is:

```text
Shield Bash
Active
Effect: Deal 7 damage.
Targeting: Closest active enemy.
Requirements: User must occupy a front-row slot.
Cooldown: 1 turn after use.
```

Repeat with passive `frontline_guard`, including `Cooldown: None`.

- [ ] **Step 2: Run the focused test and confirm missing-node failure**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: failure naming `%SkillSelectionRegion` or `%SkillPreviewPanel`.

- [ ] **Step 3: Reshape the inspector through GodotIQ scene operations**

Open `res://Scenes/battle_arena.tscn`, call `scene_tree` around `Margin/VBox/SkillInspectorPanel`, then use one verified `node_ops` batch to:

```json
[
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody","type":"HBoxContainer","name":"SkillSelectionRegion","properties":{"unique_name_in_owner":true,"size_flags_horizontal":3,"size_flags_stretch_ratio":7.0}},
  {"op":"reparent","node":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillInspectorCharacterBlock","new_parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillSelectionRegion"},
  {"op":"reparent","node":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillInspectorSkills","new_parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillSelectionRegion"},
  {"op":"reparent","node":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillInspectorEmptyLabel","new_parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillSelectionRegion"},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody","type":"PanelContainer","name":"SkillPreviewPanel","properties":{"unique_name_in_owner":true,"custom_minimum_size":[288.0,0.0],"size_flags_horizontal":3,"size_flags_stretch_ratio":3.0}},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel","type":"VBoxContainer","name":"SkillPreviewContent","properties":{"theme_override_constants/separation":4}},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel/SkillPreviewContent","type":"Label","name":"SkillPreviewPromptLabel","properties":{"unique_name_in_owner":true,"text":"Select a skill to inspect its description.","autowrap_mode":2}},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel/SkillPreviewContent","type":"Label","name":"SkillPreviewNameLabel","properties":{"unique_name_in_owner":true,"text":"","autowrap_mode":2}},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel/SkillPreviewContent","type":"Label","name":"SkillPreviewKindLabel","properties":{"unique_name_in_owner":true,"text":""}},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel/SkillPreviewContent","type":"Label","name":"SkillPreviewEffectLabel","properties":{"unique_name_in_owner":true,"text":"","autowrap_mode":2}},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel/SkillPreviewContent","type":"Label","name":"SkillPreviewTargetingLabel","properties":{"unique_name_in_owner":true,"text":"","autowrap_mode":2}},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel/SkillPreviewContent","type":"Label","name":"SkillPreviewRequirementsLabel","properties":{"unique_name_in_owner":true,"text":"","autowrap_mode":2}},
  {"op":"add_child","parent":"Margin/VBox/SkillInspectorPanel/SkillInspectorContent/SkillInspectorBody/SkillPreviewPanel/SkillPreviewContent","type":"Label","name":"SkillPreviewCooldownLabel","properties":{"unique_name_in_owner":true,"text":"","autowrap_mode":2}}
]
```

If the live scene reports a different parent path, use `scene_tree` to resolve it and preserve the exact node names, ownership, order, 7:3 stretch ratio, and shared outer panel. Save once with `save_scene()`, then verify with `scene_tree` and `undo_history`.

- [ ] **Step 4: Wire preview labels and rendering**

Add typed `@onready` references for all new unique labels. Add:

```gdscript
func _get_selected_skill() -> CharacterSkill:
	var unit := get_unit_by_id(_inspected_unit_id)
	if not is_instance_valid(unit):
		return null
	for skill: CharacterSkill in unit.skills:
		if skill.skill_id == _selected_skill_id:
			return skill
	return null


func _refresh_skill_preview() -> void:
	var skill := _get_selected_skill()
	var has_skill := is_instance_valid(skill)
	_skill_preview_prompt_label.visible = not has_skill
	_skill_preview_name_label.visible = has_skill
	_skill_preview_kind_label.visible = has_skill
	_skill_preview_effect_label.visible = has_skill
	_skill_preview_targeting_label.visible = has_skill
	_skill_preview_requirements_label.visible = has_skill
	_skill_preview_cooldown_label.visible = has_skill
	if not has_skill:
		_clear_skill_preview_text()
		return
	_skill_preview_name_label.text = skill.display_name
	_skill_preview_kind_label.text = (
		"Active" if skill.kind == CharacterSkill.Kind.ACTIVE else "Passive"
	)
	_skill_preview_effect_label.text = "Effect: %s" % skill.effect_text
	_skill_preview_targeting_label.text = "Targeting: %s" % skill.targeting_text
	_skill_preview_requirements_label.text = "Requirements: %s" % skill.requirements_text
	_skill_preview_cooldown_label.text = "Cooldown: %s" % skill.cooldown_text


func _clear_skill_preview_text() -> void:
	_skill_preview_name_label.text = ""
	_skill_preview_kind_label.text = ""
	_skill_preview_effect_label.text = ""
	_skill_preview_targeting_label.text = ""
	_skill_preview_requirements_label.text = ""
	_skill_preview_cooldown_label.text = ""
```

Call `_refresh_skill_preview()` after `_refresh_skill_selection()` in both `select_skill()` and `_refresh_skill_inspector()`. Call it from `_clear_skill_inspector()` after selection IDs are cleared. Do not connect preview nodes to battle-action functions.

- [ ] **Step 5: Validate one script and one scene**

```text
validate(target=res://Scripts/Battle/battle_arena.gd, detail=brief)
check_errors(scope=res://Scripts/Battle/battle_arena.gd)
```

Then save and inspect `res://Scenes/battle_arena.tscn`; confirm every new node is scene-owned and uniquely addressable.

- [ ] **Step 6: Run focused and AC2.6 tests**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
```

Expected: both exit `0`; active and passive previews render all four rows.

- [ ] **Step 7: Commit the preview UI**

```powershell
git add -- Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_7_skill_preview.gd
git commit -m "feat: show right-docked skill previews"
```

### Task 4: Lock lifecycle, non-actionability, and measurable readability

**Files:**

- Modify: `Tests/Battle/test_ac2_7_skill_preview.gd`
- Modify if required by failing tests: `Scripts/Battle/battle_arena.gd`
- Modify if required by failing layout tests: `Scenes/battle_arena.tscn`

- [ ] **Step 1: Add lifecycle and non-actionability assertions**

For both an active and passive selection, snapshot:

```gdscript
var turn_before := arena.get_current_unit().unit_id
var round_before := arena.round_number
var log_count_before := arena.get_battle_log_entries().size()
var hp_before := _snapshot_hp(arena)
```

Define the helper in the runner:

```gdscript
func _snapshot_hp(arena: BattleArena) -> Dictionary:
	var result := {}
	for unit_id: StringName in [
		&"player_0", &"player_1", &"player_2", &"player_3", &"player_4", &"player_5",
		&"enemy_0", &"enemy_1", &"enemy_2", &"enemy_3", &"enemy_4", &"enemy_5",
	]:
		var unit := arena.get_unit_by_id(unit_id)
		if is_instance_valid(unit):
			result[unit_id] = unit.current_hp
	return result
```

After pressing the skill button, assert unchanged turn, round, log count, and HP. Then verify:

- another skill moves the highlight and preview to exactly one selected skill;
- another character clears the selected skill and restores the preview prompt;
- an empty slot preserves the current preview;
- `advance_turn()` preserves the preview;
- non-terminal debug damage preserves it;
- retained defeat preserves it and shows `Defeated`;
- removal/invalidation clears it;
- `configure_units()` and a new arena instance restore neutral state.

- [ ] **Step 2: Add exact target-viewport layout assertions**

Set the root window to `1152x648`, inspect `player_4`, select `quick_strike`, and await two process frames. Assert:

```gdscript
var inspector := arena.get_node("%SkillInspectorPanel") as Control
var preview := arena.get_node("%SkillPreviewPanel") as Control
var inspector_rect := inspector.get_global_rect()
var preview_rect := preview.get_global_rect()
var preview_ratio := preview_rect.size.x / inspector_rect.size.x
_expect(preview_ratio >= 0.25 and preview_ratio <= 0.33, "preview width must be 25-33%")
_expect(inspector_rect.position.x >= 0.0, "inspector must not overflow left")
_expect(inspector_rect.end.x <= 1152.0, "inspector must not overflow right")
_expect(inspector_rect.position.y >= 0.0, "inspector must not overflow top")
_expect(inspector_rect.end.y <= 648.0, "inspector must not overflow bottom")
```

For every skill button, selected-skill heading, kind, and preview-row label:

```gdscript
_expect(control.visible, "%s must be visible" % control.name)
_expect(inspector_rect.encloses(control.get_global_rect()), "%s must stay inside inspector" % control.name)
_expect(control.size.x > 0.0 and control.size.y > 0.0, "%s must have rendered size" % control.name)
```

For every wrapped preview label:

```gdscript
_expect(
	label.get_minimum_size().y <= label.size.y + 0.5,
	"%s text must not be vertically clipped" % label.name
)
```

Assert there are exactly four visible buttons and no `ScrollContainer` ancestor between `%SkillInspectorBody` and `%SkillInspectorPanel`; horizontal scrolling is not an accepted workaround.

- [ ] **Step 3: Run the new tests and make only evidence-driven fixes**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
```

Expected: all lifecycle, non-actionability, and 1152×648 layout assertions pass. If a layout assertion fails, adjust only container size flags, stretch ratios, separation, minimum widths, or label wrapping; retain the shared outer panel and 25–33% preview width.

- [ ] **Step 4: Validate after each changed Godot file**

If `battle_arena.gd` changed:

```text
validate(target=res://Scripts/Battle/battle_arena.gd, detail=brief)
check_errors(scope=res://Scripts/Battle/battle_arena.gd)
```

After changing the focused runner:

```text
validate(target=res://Tests/Battle/test_ac2_7_skill_preview.gd, detail=brief)
check_errors(scope=res://Tests/Battle/test_ac2_7_skill_preview.gd)
```

After scene changes, save once and verify the live scene tree. Do not batch unvalidated edits across scripts.

- [ ] **Step 5: Commit lifecycle and layout hardening**

```powershell
git add -- Scripts/Battle/battle_arena.gd Scenes/battle_arena.tscn Tests/Battle/test_ac2_7_skill_preview.gd
git commit -m "test: harden AC2.7 preview lifecycle and layout"
```

### Task 5: Run regressions and perform runtime visual QA

**Files:**

- No production file changes unless a gate exposes a defect.

- [ ] **Step 1: Establish a clean project validation baseline**

```text
validate(target=project, detail=brief)
check_errors(scope=project)
signal_map(find=orphans)
```

Expected: no new convention, parser, or orphan-signal errors.

- [ ] **Step 2: Run every AC2.1–AC2.7 focused runner**

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

- [ ] **Step 3: Run the complete repository test corpus**

```powershell
$allTests = Get-ChildItem -LiteralPath Tests -Recurse -Filter '*.gd' | Sort-Object FullName
foreach ($testFile in $allTests) {
  $relative = [IO.Path]::GetRelativePath((Get-Location).Path, $testFile.FullName) -replace '\\','/'
  & godot --headless --path . --script ("res://" + $relative)
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
```

Expected: every runner exits `0`.

- [ ] **Step 4: Verify the running project and state**

Use GodotIQ:

```text
run(action=play)
verify_project_runs()
read_debug_console()
```

Use `ui_map` before input. Enter a Combat battle and inspect:

- player active `Shield Bash`;
- player passive `Frontline Guard`;
- enemy active `Savage Blow`;
- enemy passive `Blood Scent`;
- four-skill player fixture;
- zero-skill fixture;
- empty slot.

Use `state_inspect` to confirm selected IDs and unchanged round/HP/log values where possible. Confirm no debugger errors.

- [ ] **Step 5: Perform one target-viewport visual verification**

At `1152x648`, use `explore(mode="tour")`, then inspect the skill inspector close-up if needed. The pass criteria are all mandatory:

- shared inspector is fully inside the viewport;
- preview is right-docked inside that inspector;
- preview rendered width is 25–33% of inspector width;
- all four buttons are fully visible;
- selected skill name and kind are visible;
- Effect, Targeting, Requirements, and Cooldown rows are simultaneously visible;
- no text is clipped, truncated, overlapped, or obscured;
- no horizontal scrolling is required.

Describe the screenshot against each criterion. If any item fails, fix it and repeat the tour.

- [ ] **Step 6: Stop the game**

```text
read_debug_console()
run(action=stop)
```

Expected: no new runtime errors.

### Task 6: Package traceable evidence and formally close AC2.7

**Files:**

- Create: `Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/implementation-link.txt`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`

- [ ] **Step 1: Create the implementation commit before evidence capture**

Confirm only relevant files are staged:

```powershell
git status --short
git diff --check
```

Commit any final verified implementation/test adjustments. Record:

```powershell
git rev-parse HEAD
```

This SHA is the tested implementation commit. Do not include later documentation-only commits as the implementation link.

- [ ] **Step 2: Capture automated evidence against that exact SHA**

Run the seven AC2 focused runners again and redirect complete output, including the tested SHA and command list, into:

```text
Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/automated-test.log
```

Capture the tested SHA in the same PowerShell session:

```powershell
$implementationSha = git rev-parse HEAD
if ($implementationSha -notmatch '^[0-9a-f]{40}$') { throw 'Expected a full implementation SHA.' }
```

The log header must be generated from that variable and state:

```text
Acceptance criterion: AC2.7
Tested implementation commit: followed by the value of $implementationSha
Focused runner: Tests/Battle/test_ac2_7_skill_preview.gd
Regression scope: AC2.1 through AC2.6
Result: PASS
```

Verify the finished log contains `$implementationSha` before continuing.

- [ ] **Step 3: Write the measurable manual runtime record**

Create `manual-runtime-check.md` with the tested value of `$implementationSha` inserted on the commit line:

```markdown
# AC2.7 Manual Runtime Check

- Tested implementation commit: the tested 40-character implementation SHA
- Viewport: `1152x648`
- Result: PASS

## Inspection coverage

- Player active: Shield Bash — all four exact rows visible before action.
- Player passive: Frontline Guard — all four exact rows visible, including `Cooldown: None`.
- Enemy active: Savage Blow — all four exact rows visible before action.
- Enemy passive: Blood Scent — all four exact rows visible, including `Cooldown: None`.

## Lifecycle and non-actionability

- Skill selection changed no HP, turn, round, or battle-log state.
- Character change cleared the preview.
- Empty-slot selection preserved the preview.
- Turn advance, damage, and retained defeat preserved the preview.
- Reconfiguration and new battle cleared the preview.

## Readability

- Inspector remained inside viewport bounds.
- Preview width was within 25–33% of inspector width.
- Four-skill fixture showed all four complete buttons.
- Selected name, kind, and all four rows were simultaneously visible.
- No text was clipped, truncated, overlapped, or obscured.
- No horizontal scrolling was required.

## Runtime health

- Godot debugger showed no new errors.
```

- [ ] **Step 4: Write the implementation link**

`implementation-link.txt` must contain only the same tested 40-character SHA plus a trailing newline.

- [ ] **Step 5: Formally close the MVP criterion**

Only after Steps 1–4 pass, change:

```markdown
- [ ] AC2.7 — The player can inspect a readable description for each skill before committing an action, including passive skills from an inspectable UI surface
```

to:

```markdown
- [x] AC2.7 — The player can inspect a readable description for each skill before committing an action, including passive skills from an inspectable UI surface
```

Replace the AC2.7 verification row with exactly:

```markdown
| `AC2.7` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_7_skill_preview.gd` to verify required structured effect, targeting, requirements, and cooldown text; runtime-safe blank rejection; defensive copying; exact eleven-skill player/enemy fixtures; active and passive preview states; selection, defeat, removal, invalidation, reconfiguration, and new-battle lifecycle behavior; non-actionability; the 25–33% right-docked width contract; and target-viewport no-clipping coverage. Then inspect active and passive skills on both battle sides at 1152×648 and confirm the selected name, kind, and all four rows are simultaneously visible inside the shared inspector without clipping, truncation, overlap, obscuring, or horizontal scrolling before committing an action. |
```

Confirm:

```powershell
(rg -n '^- \[[x ]\] AC2\.7 ' Docs/Specs/GAME_DESIGN_SPEC_MVP.md | Measure-Object).Count
(rg -n '^\| `AC2\.7` \|' Docs/Specs/GAME_DESIGN_SPEC_MVP.md | Measure-Object).Count
rg -n '^- \[ \] AC2\.(8|9) ' Docs/Specs/GAME_DESIGN_SPEC_MVP.md
```

Expected: counts are `1` and `1`; AC2.8 and AC2.9 remain unchecked.

- [ ] **Step 6: Validate the complete evidence package**

```powershell
$sha = (Get-Content -Raw -LiteralPath 'Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/implementation-link.txt').Trim()
if ($sha -notmatch '^[0-9a-f]{40}$') { throw 'Implementation link is not a full commit SHA.' }
$auto = Get-Content -Raw -LiteralPath 'Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/automated-test.log'
$manual = Get-Content -Raw -LiteralPath 'Docs/Specs/AC2/Evidence/AC2.7/2026-07-30/manual-runtime-check.md'
if (-not $auto.Contains($sha)) { throw 'Automated evidence SHA mismatch.' }
if (-not $manual.Contains($sha)) { throw 'Manual evidence SHA mismatch.' }
if (-not $auto.Contains('Result: PASS')) { throw 'Automated evidence is not passing.' }
if (-not $manual.Contains('Result: PASS')) { throw 'Manual evidence is not passing.' }
```

Expected: no output and exit `0`.

- [ ] **Step 7: Commit the traceable closeout**

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.7/2026-07-30
git commit -m "docs: record AC2.7 completion evidence"
git status --short
```

Expected: documentation commit succeeds and the worktree is clean.

## Final acceptance gate

AC2.7 is complete only when all of the following are true:

- The focused AC2.7 runner passes.
- AC2.1–AC2.6 regressions pass.
- The complete repository test corpus passes.
- Project validation, parser checks, orphan-signal scan, runtime startup, and debugger checks pass.
- Active and passive skills on both sides show exact structured previews before action.
- Selection remains non-actionable across every tested path.
- The preview occupies 25–33% of the shared inspector at `1152x648`.
- Four buttons, selected name/kind, and all four rows are simultaneously visible without clipping, truncation, overlap, obscuring, overflow, or horizontal scrolling.
- Automated and manual evidence identify the same implementation commit.
- The MVP contains exactly one checked AC2.7 row and exactly one automated/manual AC2.7 verification row.
- AC2.8 and AC2.9 remain unchecked.
