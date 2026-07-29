# AC2.6 Character-Specific Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every player and enemy battle character zero to four validated character-specific skills and expose their names, counts, status, and Active/Passive classification through a minimal debug inspector.

**Architecture:** Add a typed `CharacterSkill` value object and store a copied, validated roster directly on `BattleUnitState`. Keep the inspector nodes persistent in `battle_arena.tscn`; `BattleArena` only selects existing units and renders their immutable skill metadata.

**Tech Stack:** Godot 4, typed GDScript, Godot `Control` scenes, standalone headless `SceneTree` tests, GodotIQ scene/script/runtime verification.

---

## File structure

- Create `Scripts/Battle/character_skill.gd`: typed skill identity and definition validation.
- Modify `Scripts/Battle/battle_unit_state.gd`: enforce and own zero-to-four skill rosters.
- Modify `Scenes/battle_arena.tscn`: persist the debug inspector subtree.
- Modify `Scripts/Battle/battle_arena.gd`: named fixtures, slot selection, rendering, and lifecycle.
- Create `Tests/Battle/test_ac2_6_character_skills.gd`: focused model, fixture, UI, and lifecycle coverage.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: combined verification contract and completion checkbox after all gates pass.
- Create `Docs/Specs/AC2/Evidence/AC2.6/2026-07-29/*`: automated, manual, and implementation-link evidence.

### Task 1: Add the typed skill and roster contracts

**Files:**

- Create: `Scripts/Battle/character_skill.gd`
- Modify: `Scripts/Battle/battle_unit_state.gd`
- Create: `Tests/Battle/test_ac2_6_character_skills.gd`

- [ ] **Step 1: Inspect signatures and change impact**

Use:

```text
file_context(file="res://Scripts/Battle/battle_unit_state.gd", detail="normal")
impact_check(file="res://Scripts/Battle/battle_unit_state.gd", action="add_parameter", target="_init", change_description="append optional Array[CharacterSkill] roster")
dependency_graph(file="res://Scripts/Battle/battle_unit_state.gd", depth=2, detail="normal")
```

Expected: appending a defaulted parameter preserves every existing constructor call.

- [ ] **Step 2: Write the failing model tests**

Create the runner with `EXPECTED_TEST_COUNT := 14`. Its first seven synchronous cases must use these exact assertions:

```gdscript
func _test_active_and_passive_identity() -> void:
	var active := CharacterSkill.new(&"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE)
	var passive := CharacterSkill.new(&"frontline_guard", "Frontline Guard", CharacterSkill.Kind.PASSIVE)
	_assert(
		active.skill_id == &"shield_bash" and active.display_name == "Shield Bash"
		and active.kind == CharacterSkill.Kind.ACTIVE
		and passive.kind == CharacterSkill.Kind.PASSIVE,
		"Typed skill identity",
		"valid definitions must preserve identity and kind"
	)


func _test_blank_definition_validation() -> void:
	_assert(
		not CharacterSkill.is_valid_definition(&"", "Name", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&" ", "Name", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&"\t", "Name", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&"valid", "", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&"valid", " ", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&"valid", "\t", CharacterSkill.Kind.ACTIVE),
		"Blank definitions are invalid",
		"empty and whitespace-only IDs and names must be rejected"
	)


func _test_invalid_kind_validation() -> void:
	_assert(
		not CharacterSkill.is_valid_definition(&"valid", "Valid", -1)
		and not CharacterSkill.is_valid_definition(&"valid", "Valid", 2),
		"Unknown kinds are invalid",
		"only Active and Passive are accepted"
	)


func _test_zero_through_four_skills_are_valid() -> void:
	for count: int in 5:
		_assert(
			BattleUnitState.is_valid_skill_roster(_skills(count)),
			"Roster size %d is valid" % count,
			"zero through four skills must be accepted"
		)


func _test_invalid_roster_elements_are_rejected() -> void:
	var valid := CharacterSkill.new(&"valid", "Valid", CharacterSkill.Kind.ACTIVE)
	_assert(
		not BattleUnitState.is_valid_skill_roster([valid, null])
		and not BattleUnitState.is_valid_skill_roster([valid, "wrong type"]),
		"Invalid roster elements are rejected",
		"null and wrong-type entries must reject the complete roster"
	)


func _test_duplicate_and_oversized_rosters_are_rejected() -> void:
	var first := CharacterSkill.new(&"duplicate", "First", CharacterSkill.Kind.ACTIVE)
	var second := CharacterSkill.new(&"duplicate", "Second", CharacterSkill.Kind.PASSIVE)
	_assert(
		not BattleUnitState.is_valid_skill_roster([first, second])
		and not BattleUnitState.is_valid_skill_roster(_skills(5)),
		"Duplicate and oversized rosters are rejected",
		"duplicate IDs and a fifth skill must never be accepted"
	)


func _test_roster_is_copied_for_both_sides() -> void:
	var source: Array[CharacterSkill] = _skills(2)
	var player := BattleUnitState.new(&"player", "Player", BattleUnitState.Side.PLAYER, 0, 9, 20, source)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 8, 20, source)
	source.clear()
	_assert(
		player.skills.size() == 2 and enemy.skills.size() == 2
		and player.skills[0] == enemy.skills[0],
		"Rosters are copied for both sides",
		"array ownership must not depend on side or caller mutation"
	)
```

Helper:

```gdscript
func _skills(count: int) -> Array[CharacterSkill]:
	var result: Array[CharacterSkill] = []
	for index: int in count:
		result.append(CharacterSkill.new(
			StringName("skill_%d" % index),
			"Skill %d" % index,
			CharacterSkill.Kind.ACTIVE if index % 2 == 0 else CharacterSkill.Kind.PASSIVE
		))
	return result
```

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
```

Expected: FAIL because `CharacterSkill` and the roster APIs do not exist.

- [ ] **Step 3: Create `CharacterSkill`**

Use `script_ops(op="create")` with:

```gdscript
class_name CharacterSkill
extends RefCounted

enum Kind {
	ACTIVE,
	PASSIVE,
}

var skill_id: StringName
var display_name: String
var kind: Kind


func _init(id: StringName, name: String, skill_kind: int) -> void:
	assert(
		is_valid_definition(id, name, skill_kind),
		"CharacterSkill requires non-blank identity and an Active or Passive kind."
	)
	skill_id = id
	display_name = name
	kind = skill_kind


static func is_valid_definition(id: StringName, name: String, skill_kind: int) -> bool:
	return (
		not String(id).strip_edges().is_empty()
		and not name.strip_edges().is_empty()
		and skill_kind in [Kind.ACTIVE, Kind.PASSIVE]
	)
```

Then run:

```text
validate(target="res://Scripts/Battle/character_skill.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/character_skill.gd")
```

Expected: no validation or parser errors.

- [ ] **Step 4: Extend `BattleUnitState`**

Add:

```gdscript
const MAX_CHARACTER_SKILLS := 4

var skills: Array[CharacterSkill] = []
```

Append this defaulted constructor parameter:

```gdscript
unit_skills: Array[CharacterSkill] = []
```

Before assignment, enforce the complete roster:

```gdscript
assert(
	is_valid_skill_roster(unit_skills),
	"BattleUnitState requires zero to four unique, valid CharacterSkill entries."
)
skills = unit_skills.duplicate()
```

Add:

```gdscript
static func is_valid_skill_roster(candidate: Array) -> bool:
	if candidate.size() > MAX_CHARACTER_SKILLS:
		return false
	var seen_ids: Dictionary = {}
	for entry: Variant in candidate:
		if not is_instance_valid(entry) or not entry is CharacterSkill:
			return false
		var skill := entry as CharacterSkill
		if seen_ids.has(skill.skill_id):
			return false
		seen_ids[skill.skill_id] = true
	return true
```

Run:

```text
validate(target="res://Scripts/Battle/battle_unit_state.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_unit_state.gd")
```

Expected: no validation or parser errors.

- [ ] **Step 5: Prove the model tests pass**

Run the focused runner. Expected: the seven model cases pass; the seven arena and layout cases still fail until Tasks 2 and 3.

- [ ] **Step 6: Commit the model**

```powershell
git add -- Scripts/Battle/character_skill.gd Scripts/Battle/battle_unit_state.gd Tests/Battle/test_ac2_6_character_skills.gd
git commit -m "feat: add typed character skill rosters"
```

### Task 2: Add exact fixtures and the persistent inspector scene

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Scenes/battle_arena.tscn`
- Test: `Tests/Battle/test_ac2_6_character_skills.gd`

- [ ] **Step 1: Add failing fixture and scene-contract tests**

Add two cases:

```gdscript
func _test_exact_debug_fixtures() -> void:
	var arena := await _instantiate_arena()
	var expected := {
		&"player_0": [[&"shield_bash", 0], [&"frontline_guard", 1]],
		&"player_1": [],
		&"player_2": [[&"quick_step", 0]],
		&"player_3": [],
		&"player_4": [[&"quick_strike", 0], [&"rally", 0], [&"evasion", 1], [&"momentum", 1]],
		&"player_5": [],
		&"enemy_0": [[&"savage_blow", 0], [&"blood_scent", 1]],
		&"enemy_1": [],
		&"enemy_2": [[&"brace", 1]],
		&"enemy_3": [],
		&"enemy_4": [[&"shadow_lunge", 0]],
		&"enemy_5": [],
	}
	var actual: Dictionary = {}
	for unit_id: StringName in expected:
		var unit := arena.call("get_unit_by_id", unit_id) as BattleUnitState
		actual[unit_id] = _skill_signature(unit.skills) if is_instance_valid(unit) else null
	_assert(actual == expected, "Exact debug fixtures", "all twelve named fixture rosters must match the spec")
	_free_arena(arena)


func _test_persistent_inspector_scene_contract() -> void:
	var arena := await _instantiate_arena()
	var panel := arena.get_node_or_null("%SkillInspectorPanel")
	var vbox := arena.get_node_or_null("Margin/VBox")
	_assert(
		panel is PanelContainer and panel.owner != null and vbox != null
		and vbox.get_child(panel.get_index() - 1).name == &"TurnStatus"
		and vbox.get_child(panel.get_index() + 1).name == &"BattleResultPanel"
		and arena.get_node_or_null("%SkillInspectorTitleLabel") is Label
		and arena.get_node_or_null("%SkillInspectorPromptLabel") is Label
		and arena.get_node_or_null("%SkillInspectorUnitNameLabel") is Label
		and arena.get_node_or_null("%SkillInspectorStatusLabel") is Label
		and arena.get_node_or_null("%SkillInspectorCountLabel") is Label
		and arena.get_node_or_null("%SkillInspectorSkills") is VBoxContainer
		and arena.get_node_or_null("%SkillInspectorEmptyLabel") is Label,
		"Persistent inspector scene contract",
		"the exact owned unique-name subtree must be wired between status and results"
	)
	_free_arena(arena)
```

Run the focused runner. Expected: both cases fail.

- [ ] **Step 2: Replace `_create_debug_units()` with the exact fixtures**

Add helpers:

```gdscript
func _skill(id: StringName, name: String, kind: CharacterSkill.Kind) -> CharacterSkill:
	return CharacterSkill.new(id, name, kind)


func _skills(values: Array[CharacterSkill]) -> Array[CharacterSkill]:
	return values
```

Construct the twelve existing units with the exact rosters from the approved design table. Pass each roster as the final constructor argument after `BattleUnitState.DEFAULT_MAX_HP`. Do not change IDs, display names, sides, slots, speeds, or HP.

- [ ] **Step 3: Build the inspector subtree with GodotIQ**

Before editing:

```text
file_context(file="res://Scenes/battle_arena.tscn", detail="full")
scene_tree(root="Margin/VBox", depth=3, detail="normal")
```

Use one `node_ops` batch to add the persistent subtree from the design after `TurnStatus`, with `unique_name_in_owner=true` on every named access node. Use the exact default text:

```text
Character Skills (Debug)
Select a populated slot to inspect skills.
No character-specific skills
```

Set the header and empty label initially hidden. These are 2D `Control` changes, so do not request 3D spatial validation. Reorder `SkillInspectorPanel` between `TurnStatus` and `BattleResultPanel`, then call:

```text
save_scene()
undo_history(detail="brief")
file_context(file="res://Scenes/battle_arena.tscn", detail="full")
scene_tree(root="Margin/VBox", depth=4, detail="normal")
```

Expected: all nodes are scene-owned, uniquely addressable, and ordered correctly.

- [ ] **Step 4: Validate fixtures and scene**

```text
validate(target="res://Scripts/Battle/battle_arena.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_arena.gd")
```

Run the focused runner. Expected: model, fixture, and persistent-scene cases pass.

- [ ] **Step 5: Commit fixtures and scene**

```powershell
git add -- Scripts/Battle/battle_arena.gd Scenes/battle_arena.tscn Tests/Battle/test_ac2_6_character_skills.gd
git commit -m "feat: add AC2.6 skill fixtures and inspector scene"
```

### Task 3: Implement slot inspection and lifecycle

**Files:**

- Modify: `Scripts/Battle/battle_arena.gd`
- Test: `Tests/Battle/test_ac2_6_character_skills.gd`

- [ ] **Step 1: Add five failing interaction and layout cases**

Add cases for:

```gdscript
# Neutral state
Prompt visible with exact text; header hidden; no dynamic rows; inspected ID is empty.

# Populated player/enemy and zero-skill selection
inspect_unit(&"player_4") => Player Back 2, Active, Skills: 4/4, four exact rows.
inspect_unit(&"enemy_0") => Enemy Front 1, Active, Skills: 2/4, two exact rows.
inspect_unit(&"player_1") => Player Front 2, Active, Skills: 0/4,
empty label visible and dynamic row count zero.

# Empty-slot input and reconfiguration
Inspect player_4, send a pressed left InputEventMouseButton to an unoccupied slot
after configuring a sparse roster, and verify player_4 remains selected.
Reconfigure and verify the neutral state.

# Retained defeat and invalid/removal cleanup
Inspect an enemy with 6 HP, resolve debug damage, verify the same skill rows remain
and status becomes Defeated. Reconfigure without that ID and verify neutral state.

# Four-skill viewport fit
Set the test window to 1152x648, inspect player_4, await one frame, and verify
Margin/VBox and the bottom of BattleLogPanel remain at or above y=648.
```

Run the focused runner. Expected: all five fail because the API, wiring, and compact layout do not exist.

- [ ] **Step 2: Add exact inspector state and public test seam**

Add:

```gdscript
@onready var _skill_inspector_prompt_label: Label = %SkillInspectorPromptLabel
@onready var _skill_inspector_header: HBoxContainer = %SkillInspectorHeader
@onready var _skill_inspector_unit_name_label: Label = %SkillInspectorUnitNameLabel
@onready var _skill_inspector_status_label: Label = %SkillInspectorStatusLabel
@onready var _skill_inspector_count_label: Label = %SkillInspectorCountLabel
@onready var _skill_inspector_skills: VBoxContainer = %SkillInspectorSkills
@onready var _skill_inspector_empty_label: Label = %SkillInspectorEmptyLabel

var _inspected_unit_id: StringName = &""
```

Add:

```gdscript
func get_inspected_unit_id() -> StringName:
	return _inspected_unit_id


func inspect_unit(unit_id: StringName) -> void:
	var unit := get_unit_by_id(unit_id)
	if not is_instance_valid(unit):
		_clear_skill_inspector()
		return
	_inspected_unit_id = unit.unit_id
	_refresh_skill_inspector()
```

- [ ] **Step 3: Wire slot input and metadata**

In `_assign_slot_metadata()`, initialize `unit_id` to `&""` and connect `gui_input` once:

```gdscript
slot.set_meta("unit_id", &"")
var input_callable := Callable(self, "_on_slot_gui_input").bind(slot)
if not slot.gui_input.is_connected(input_callable):
	slot.gui_input.connect(input_callable)
```

Add:

```gdscript
func _on_slot_gui_input(event: InputEvent, slot: Control) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var unit_id := slot.get_meta("unit_id", &"") as StringName
	if unit_id.is_empty():
		return
	inspect_unit(unit_id)
```

At the start of `_render_units()`, clear each slot's `unit_id`; when rendering a valid unit, set the slot metadata to that unit's ID.

- [ ] **Step 4: Render and clear the inspector**

Add:

```gdscript
func _refresh_skill_inspector() -> void:
	var unit := get_unit_by_id(_inspected_unit_id)
	if not is_instance_valid(unit):
		_clear_skill_inspector()
		return
	_clear_skill_rows()
	_skill_inspector_prompt_label.visible = false
	_skill_inspector_header.visible = true
	_skill_inspector_unit_name_label.text = unit.display_name
	_skill_inspector_status_label.text = "Active" if unit.is_active() else "Defeated"
	_skill_inspector_count_label.text = "Skills: %d/%d" % [
		unit.skills.size(),
		BattleUnitState.MAX_CHARACTER_SKILLS,
	]
	_skill_inspector_empty_label.visible = unit.skills.is_empty()
	for skill: CharacterSkill in unit.skills:
		var row := Label.new()
		row.add_theme_font_size_override("font_size", 12)
		row.text = "%s — %s" % [
			skill.display_name,
			"Active" if skill.kind == CharacterSkill.Kind.ACTIVE else "Passive",
		]
		_skill_inspector_skills.add_child(row)


func _clear_skill_inspector() -> void:
	_inspected_unit_id = &""
	if not is_node_ready():
		return
	_clear_skill_rows()
	_skill_inspector_prompt_label.visible = true
	_skill_inspector_header.visible = false
	_skill_inspector_unit_name_label.text = ""
	_skill_inspector_status_label.text = ""
	_skill_inspector_count_label.text = ""
	_skill_inspector_empty_label.visible = false


func _clear_skill_rows() -> void:
	for child: Node in _skill_inspector_skills.get_children():
		_skill_inspector_skills.remove_child(child)
		child.queue_free()
```

Call `_clear_skill_inspector()` at the start of `configure_units()`. Call `_refresh_skill_inspector()` after `_render_units()` so retained inactive units change to `Defeated`, and absent or invalid units clear.

Compact the persistent inspector labels to 12px with zero content separation. Set `BattleLogPanel` and `BattleLogVBox` minimum heights to `60`, and `BattleLogScroll` to `40`, so the four-skill inspector and battle log fit the project viewport without hiding either surface.

- [ ] **Step 5: Validate and prove the focused suite**

```text
validate(target="res://Scripts/Battle/battle_arena.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_arena.gd")
```

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
```

Expected: `AC2.6 character skill tests: PASS (14/14)` and exit `0`.

- [ ] **Step 6: Commit interaction behavior**

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_6_character_skills.gd
git commit -m "feat: add AC2.6 skill debug inspection"
```

### Task 4: Run regressions, runtime QA, and record evidence

**Files:**

- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.6/2026-07-29/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.6/2026-07-29/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.6/2026-07-29/implementation-link.txt`

- [ ] **Step 1: Run focused and complete automated coverage**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
$testScripts = rg --files Tests -g 'test_*.gd' | Sort-Object
foreach ($testScript in $testScripts) {
    & godot --headless --path . --script ("res://" + ($testScript -replace '\\','/'))
    if ($LASTEXITCODE -ne 0) { throw "FAILED: $testScript" }
}
```

Expected: focused PASS `(14/14)` and every existing runner exits `0`.

- [ ] **Step 2: Run project-wide GodotIQ gates**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(scope="all", find="missing", detail="brief")
run(action="play")
verify_project_runs()
read_debug_console()
```

Expected: no parser, convention, missing-signal, or runtime errors.

- [ ] **Step 3: Run input and visual QA**

Use GodotIQ input to click populated player and enemy slots, the zero-skill fixture, the four-skill fixture, and an empty slot in a sparse test setup. Use one `explore(mode="tour")` pass to verify that the inspector is readable at 1280×720 and does not crowd the formations, result panel, reward overlay, debug controls, or battle log.

Defeat the inspected enemy and verify the same skill rows remain while status changes to `Defeated`. Enter a new battle and verify the neutral prompt returns. Fix any issue, validate the changed script or scene, save, and repeat the focused verification once. Stop the game.

- [ ] **Step 4: Record evidence**

Write exact commands, exit codes, PASS/FAIL/BLOCKED outcomes, and the focused signature to `automated-test.log`. Create `manual-runtime-check.md` covering player, enemy, zero-skill, four-skill, Active/Passive labels, empty-slot preservation, defeated status, reconfiguration cleanup, and layout/readability.

Write the full tested implementation commit SHA plus a newline to `implementation-link.txt`.

- [ ] **Step 5: Upgrade the AC2.6 verification contract and checkbox**

Change the AC2.6 row to:

```markdown
| `AC2.6` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_6_character_skills.gd` to verify typed Active/Passive identity, blank and invalid definition rejection, zero-to-four roster limits, null/wrong-type/duplicate rejection, copy semantics, exact player/enemy fixtures, persistent inspector wiring, slot selection, zero-skill state, empty-slot behavior, defeated-unit status, and cleanup. Then inspect multiple player and enemy characters in battle and verify every character exposes 0 to 4 character-specific skills with each listed skill labeled Active or Passive. |
```

Only after every gate passes, change AC2.6 from `[ ]` to `[x]`. Do not check AC2.7–AC2.9 or claim descriptions or functional skill mechanics.

- [ ] **Step 6: Self-review and commit evidence**

```powershell
rg -n "T(BD)|T(ODO)|implement la[t]er|fill in det[a]ils|appropriate error handl[i]ng|similar to Ta[s]k" Docs/superpowers/plans/2026-07-29-ac2-6-character-skills.md
rg -n "AC2\\.6|CharacterSkill|MAX_CHARACTER_SKILLS|SkillInspector|14/14|PASS|FAIL|BLOCKED" Docs/superpowers/plans/2026-07-29-ac2-6-character-skills.md Docs/Specs/GAME_DESIGN_SPEC_MVP.md
git diff --check
git status --short
```

Stage only AC2.6 documentation and evidence:

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.6/2026-07-29
git commit -m "docs: record AC2.6 completion evidence"
```

- [ ] **Step 7: Final verification**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
git status --short --branch
git log -7 --oneline
```

Expected: focused PASS `(14/14)`, all AC2.6 commits are present, evidence points to the tested implementation commit, and unrelated `.vscode` plus temporary user files remain uncommitted.

## Original completion boundary

AC2.6 is complete only when the exact named fixtures, typed roster validation, persistent scene-wired inspector, both-side slot inspection, inactive retained-unit status, stale-state cleanup, four-skill viewport fit, focused `(14/14)` suite, complete regressions, GodotIQ gates, runtime input checks, visual QA, and matching evidence all pass. Any failed or blocked gate keeps AC2.6 unchecked.

### Task 5: Replace skill rows with selectable square buttons

**Files:**

- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac2_6_character_skills.gd`
- Refresh: `Docs/Specs/AC2/Evidence/AC2.6/2026-07-30/*`

- [ ] **Step 1: Add three failing tile-contract tests**

Raise `EXPECTED_TEST_COUNT` to `17`. Add focused cases that verify:

```gdscript
# Exact four-skill tile contract
inspect player_4
SkillInspectorSkills is HBoxContainer
four children are Button controls
each button.custom_minimum_size == Vector2(88.0, 88.0)
metadata skill_index values are 1, 2, 3, 4
metadata skill_id values follow the fixture roster
each button has NumberLabel, NameLabel, and KindLabel children
labels show "1", "Quick Strike", "Active" through "4", "Momentum", "Passive"

# Non-actionable selection
record round, current unit ID, and every HP value
press player_4's second skill button
selected skill ID becomes rally
only button 2 has selected metadata and selected color
round, current unit, HP, battle log, and outcome remain unchanged

# Selection lifecycle and viewport
select a player_4 skill, inspect enemy_0, and verify selected skill ID is empty
select enemy skill 1, defeat retained enemy, and verify selection and buttons remain
reconfigure arena and verify character and skill selection are empty
at 1152x648, four buttons and BattleLogPanel remain within the viewport
```

Run the focused runner. Expected: the three new cases fail against the current vertical `Label` list.

- [ ] **Step 2: Restructure the persistent inspector scene**

Use GodotIQ scene operations, never raw `.tscn` writes:

```text
SkillInspectorBody (HBoxContainer, unique name)
├── SkillInspectorCharacterBlock (VBoxContainer, unique name, minimum width 150)
│   ├── SkillInspectorUnitNameLabel
│   ├── SkillInspectorStatusLabel
│   └── SkillInspectorCountLabel
├── SkillInspectorSkills (HBoxContainer, unique name, separation 8)
└── SkillInspectorEmptyLabel
```

Reparent the existing character labels into `SkillInspectorCharacterBlock`, replace the current `VBoxContainer` skill container with `HBoxContainer`, and preserve the existing prompt, title, empty label, unique names, and scene ownership. Save and verify the scene tree.

- [ ] **Step 3: Implement exact skill-button construction**

Add:

```gdscript
const SKILL_BUTTON_SIZE := Vector2(88.0, 88.0)
const SELECTED_SKILL_COLOR := Color(1.0, 0.82, 0.32, 1.0)

var _selected_skill_id: StringName = &""
```

Expose:

```gdscript
func get_selected_skill_id() -> StringName:
	return _selected_skill_id


func select_skill(skill_id: StringName) -> void:
	var unit := get_unit_by_id(_inspected_unit_id)
	if not is_instance_valid(unit):
		return
	for skill: CharacterSkill in unit.skills:
		if skill.skill_id == skill_id:
			_selected_skill_id = skill_id
			_refresh_skill_selection()
			return
```

For each owned skill, create one square `Button` with `skill_id`, one-based `skill_index`, and `selected=false` metadata. Add three mouse-pass-through child labels: `NumberLabel` anchored top-left, `NameLabel` centered with wrapping, and `KindLabel` anchored along the bottom. Connect `pressed` to `select_skill.bind(skill.skill_id)`.

`_refresh_skill_selection()` sets exactly the matching button's `selected` metadata and `self_modulate` to `SELECTED_SKILL_COLOR`; every other button is white.

- [ ] **Step 4: Apply lifecycle rules**

Character selection clears `_selected_skill_id` before rebuilding. Retained-unit refresh preserves a still-owned selected skill. Invalid/removal cleanup and `configure_units()` clear both IDs. Zero-skill characters show the existing empty state and create no buttons.

- [ ] **Step 5: Verify GREEN and refresh evidence**

Run:

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
```

Expected: `AC2.6 character skill tests: PASS (17/17)`.

Run the full test corpus, project validation, parser checks, runtime mouse input, debugger checks, and one visual verification at 1152x648. Record refreshed automated and manual evidence under `Docs/Specs/AC2/Evidence/AC2.6/2026-07-30/` and update the implementation link to the newly tested commit.

## Revised completion boundary

AC2.6 remains complete only when the original typed roster and lifecycle contracts plus the selected-character horizontal tile row, exact square-button contents, non-actionable selection, selection cleanup, viewport fit, focused `(17/17)` suite, regressions, runtime QA, and refreshed evidence all pass.
