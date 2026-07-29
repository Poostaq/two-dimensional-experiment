# AC2.5 Event-Specific Reward Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After a Combat or Boss victory, show three fixed event-specific reward options, require an explicit selection and confirmation, emit the typed choice exactly once, and remove all reward UI state before leaving the fight or entering another battle.

**Architecture:** Add a typed `BattleRewardOption` value object and a pure `BattleRewardCatalog`. `BattleArena` owns reward presentation, selection, confirmation, and cleanup inside its existing result lifecycle. The existing `exit_requested` → `MapController.exit_active_battle()` seam continues to remove the arena; AC2.5 emits a future-facing `reward_confirmed` signal but deliberately does not mutate roster, money, inventory, or map state.

**Tech Stack:** Godot 4.7, typed GDScript, GodotIQ structured script/scene operations, headless `SceneTree` contract tests.

---

## Scope and exact file map

- Create `Scripts/Battle/battle_reward_option.gd`: typed reward kind and immutable-style option fields.
- Create `Scripts/Battle/battle_reward_catalog.gd`: pure fixed Combat/Boss option lookup.
- Modify `Scripts/Battle/battle_arena.gd`: reward signal, state, public test/integration API, victory population, explicit selection, confirmation latch, and cleanup.
- Modify `Scenes/battle_arena.tscn`: reward panel under the existing result area with exact unique node names defined below.
- Create `Tests/Battle/test_ac2_5_reward_selection.gd`: 14 focused catalog, arena, signal, cleanup, and isolation checks.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: migrate AC2.5 from manual-only to combined automated/manual verification and check it only after all evidence passes.
- Create `Docs/Specs/AC2/Evidence/AC2.5/2026-07-29/automated-test.log`: focused, regression, validation, signal, runtime, and visual results.
- Create `Docs/Specs/AC2/Evidence/AC2.5/2026-07-29/manual-runtime-check.md`: Combat/Boss choice and next-battle cleanup observations.
- Create `Docs/Specs/AC2/Evidence/AC2.5/2026-07-29/implementation-link.txt`: the full tested implementation commit SHA.

`Scripts/Map/map_controller.gd` is inspected and tested but not modified. Its existing `_on_battle_requested()` connects `battle.exit_requested` one-shot to `exit_active_battle()`, and `exit_active_battle()` removes and queues the active arena for deletion. `reward_confirmed` remains intentionally unconsumed until a later run-state criterion owns reward application.

Out of scope:

- Applying recruitment to a roster or resolving full-roster dismissal (AC3.1/AC3.2).
- Storing or spending money.
- Inventory, equipment, item effects, or rarity systems.
- Seeded or random reward generation.
- Map encounter consumption, boss completion, meta-progression, or unlock persistence.
- Replacing the battle result panel or debug exit.

## Fixed reward contract

| Event | ID | Kind | Title | Description |
|---|---|---|---|---|
| Combat | `combat_recruit_scout` | `RECRUITMENT` | `Recruit Scout` | `Recruit a Scout after this battle.` |
| Combat | `combat_money_100` | `MONEY` | `100 Money` | `Take 100 money for this run.` |
| Combat | `combat_supply_cache` | `ITEM` | `Supply Cache` | `Take a cache of practical supplies.` |
| Boss | `boss_recruit_champion` | `RECRUITMENT` | `Recruit Champion` | `Recruit a Champion after this boss battle.` |
| Boss | `boss_money_250` | `MONEY` | `250 Money` | `Take 250 money for this run.` |
| Boss | `boss_rare_relic` | `ITEM` | `Rare Relic` | `Take a rare relic from the defeated boss.` |

## Acceptance and verification matrix

| Criterion | Classification | Executable verification | Evidence artifact | Status before implementation | Gap / next action |
|---|---|---|---|---|---|
| Combat victory offers three fixed appropriate options | Logic + integration + runtime | Catalog assertions, arena victory assertion, manual Combat win | Focused runner + manual record | FAIL | No reward model, catalog, or UI |
| Boss victory offers three fixed options distinct from Combat | Logic + integration + runtime | Catalog assertions, arena victory assertion, manual Boss win | Focused runner + manual record | FAIL | No event-specific reward mapping |
| Player explicitly selects before confirming | Integration + UI | Confirm-disabled assertion, selection replacement assertion, manual selection check | Focused runner + manual record | FAIL | No selection state or Confirm control |
| Confirm emits exactly one typed choice before exit | Integration + signals | Signal-order and idempotence assertion | Focused runner + signal audit | FAIL | No typed reward signal or latch |
| Defeat never offers rewards | Integration + runtime | Defeat assertion and manual loss check | Focused runner + manual record | FAIL | Result UI has no reward branch |
| Unsupported victory has explicit non-actionable presentation | Integration + UI | Empty catalog and visible `No rewards available` assertion | Focused runner | FAIL | Policy exists only in design |
| Reward UI disappears after the fight | Lifecycle + runtime | Confirm/debug-exit cleanup assertions and manual observation | Focused runner + manual record | FAIL | No reward UI to clean |
| Next battle starts without stale reward UI or selection | Lifecycle + regression | Reconfiguration and new-instance assertions; manual second battle | Focused runner + manual record | FAIL | No reset/isolation contract |

Overall before implementation: **0/8 verification rows covered; FAIL**. AC2.5 remains unchecked until every focused, regression, GodotIQ, runtime, visual, and manual evidence gate is `PASS` against the recorded commit.

## Evidence-state policy

Use exactly these states in every evidence artifact:

- `PASS`: the named command or manual path ran against the recorded commit and produced the expected result.
- `FAIL`: the command ran or the manual path was attempted and produced an incorrect result.
- `BLOCKED`: the check could not run because the Godot executable, editor/runtime bridge, display/input path, or another required capability was unavailable.

An unavailable tool is never a pass. Record the exact command and error. Any `FAIL`, `BLOCKED`, stale result, missing artifact, mismatched commit, parser/runtime error, unreadable panel, duplicate emission, or stale next-battle UI keeps AC2.5 unchecked.

## Source-spec verification mismatch to resolve

`Docs/Specs/GAME_DESIGN_SPEC_MVP.md` currently classifies AC2.5 as `Manual runtime check`. This plan adds deterministic automated coverage for the fixed catalog, victory/defeat branching, selection/confirmation contract, signal ordering, idempotence, unsupported-type behavior, cleanup, reset, and new-instance isolation. Manual Combat and Boss checks remain required for interaction and layout.

Task 4 must replace the existing AC2.5 verification row with `Automated and manual runtime check`. This is a verification-contract migration, not proof of completion. The criterion remains unchecked until both automated and manual halves pass.

### Task 1: Add the typed reward model and fixed catalog

**Files:**

- Create: `Scripts/Battle/battle_reward_option.gd`
- Create: `Scripts/Battle/battle_reward_catalog.gd`
- Create: `Tests/Battle/test_ac2_5_reward_selection.gd`

- [ ] **Step 1: Inspect the current branch and Godot baseline**

Run:

```powershell
git status --short --branch
git log -3 --oneline
```

Expected: branch `feat/ac2-5-reward-selection` contains the approved design commit; unrelated `.vscode`, `.superpowers`, `.tmp-godotiq-debug`, spec, and UID changes remain unstaged.

Use GodotIQ:

```text
project_summary(detail="brief")
validate(target="project", detail="brief")
file_context(file="res://Scripts/Map/hex_map_model.gd", detail="brief")
file_context(file="res://Scripts/Battle/battle_arena.gd", detail="normal")
file_context(file="res://Scripts/Map/map_controller.gd", detail="normal")
```

Expected: `HexMapModel` exposes the current Combat/Boss constants, `BattleArena` owns terminal UI, and `MapController` owns arena removal.

- [ ] **Step 2: Write the first four failing catalog tests**

Create `Tests/Battle/test_ac2_5_reward_selection.gd` with this runner shell:

```gdscript
class_name Ac2_5RewardSelectionTests
extends SceneTree

const OPTION_PATH := "res://Scripts/Battle/battle_reward_option.gd"
const CATALOG_PATH := "res://Scripts/Battle/battle_reward_catalog.gd"
const UNIT_PATH := "res://Scripts/Battle/battle_unit_state.gd"
const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 14

var _failures: Array[String] = []
var _option_script: GDScript
var _catalog_script: GDScript
var _unit_script: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_option_script = load(OPTION_PATH) as GDScript if ResourceLoader.exists(OPTION_PATH) else null
	_catalog_script = load(CATALOG_PATH) as GDScript if ResourceLoader.exists(CATALOG_PATH) else null
	_unit_script = load(UNIT_PATH) as GDScript
	_test_combat_catalog_is_fixed()
	_test_boss_catalog_is_fixed_and_distinct()
	_test_unsupported_catalog_is_empty()
	_test_catalog_returns_fresh_instances()
	await _test_reward_ui_starts_hidden()
	await _test_combat_victory_shows_options()
	await _test_boss_victory_shows_options()
	await _test_defeat_never_shows_rewards()
	await _test_selection_replaces_and_gates_confirm()
	await _test_confirm_emits_ordered_once_and_cleans()
	await _test_debug_exit_cleans_without_reward()
	await _test_reconfigure_clears_reward_state()
	await _test_unsupported_victory_shows_empty_state()
	await _test_new_battle_instance_is_clean()
	_report()
	quit(1 if not _failures.is_empty() else 0)
```

Implement the first four tests against these exact IDs, titles, descriptions, and kind ordinals:

```gdscript
func _options_for(event_type: String) -> Array:
	if _catalog_script == null:
		return []
	return _catalog_script.call("get_options_for", event_type) as Array


func _test_combat_catalog_is_fixed() -> void:
	var options := _options_for("combat")
	_assert(
		_signature(options) == [
			[&"combat_recruit_scout", 0, "Recruit Scout", "Recruit a Scout after this battle."],
			[&"combat_money_100", 1, "100 Money", "Take 100 money for this run."],
			[&"combat_supply_cache", 2, "Supply Cache", "Take a cache of practical supplies."],
		],
		"Combat catalog is fixed",
		"expected the exact three Combat rewards"
	)


func _test_boss_catalog_is_fixed_and_distinct() -> void:
	var options := _options_for("boss")
	_assert(
		_signature(options) == [
			[&"boss_recruit_champion", 0, "Recruit Champion", "Recruit a Champion after this boss battle."],
			[&"boss_money_250", 1, "250 Money", "Take 250 money for this run."],
			[&"boss_rare_relic", 2, "Rare Relic", "Take a rare relic from the defeated boss."],
		] and _signature(options) != _signature(_options_for("combat")),
		"Boss catalog is fixed and distinct",
		"expected the exact three Boss rewards"
	)


func _test_unsupported_catalog_is_empty() -> void:
	_assert(_options_for("safe").is_empty(), "Unsupported catalog is empty", "Safe must not invent rewards")


func _test_catalog_returns_fresh_instances() -> void:
	var first := _options_for("combat")
	var second := _options_for("combat")
	_assert(
		first.size() == 3 and second.size() == 3 and first[0] != second[0],
		"Catalog returns fresh instances",
		"reward objects must not leak between battles"
	)


func _signature(options: Array) -> Array:
	var result: Array = []
	for option: Variant in options:
		result.append([option.reward_id, int(option.kind), option.title, option.description])
	return result
```

Add `_assert()` and `_report()` using the existing runner convention. `_report()` must print:

```gdscript
print("AC2.5 reward selection tests: PASS (%d/%d)" % [
	EXPECTED_TEST_COUNT,
	EXPECTED_TEST_COUNT,
])
```

- [ ] **Step 3: Run the focused test and prove RED**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
```

Expected: non-zero exit because the model/catalog files do not exist. Record the failure; a parser crash in the test itself is not an acceptable RED state.

- [ ] **Step 4: Create the reward option**

After `file_context` reports the file absent, create `Scripts/Battle/battle_reward_option.gd` with GodotIQ `script_ops`:

```gdscript
class_name BattleRewardOption
extends RefCounted

enum Kind {
	RECRUITMENT,
	MONEY,
	ITEM,
}

var reward_id: StringName
var kind: Kind
var title: String
var description: String


func _init(
	id: StringName,
	reward_kind: Kind,
	reward_title: String,
	reward_description: String
) -> void:
	reward_id = id
	kind = reward_kind
	title = reward_title
	description = reward_description
```

Run immediately:

```text
validate(target="res://Scripts/Battle/battle_reward_option.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_reward_option.gd")
```

Expected: no convention or parser errors.

- [ ] **Step 5: Create the fixed catalog**

Create `Scripts/Battle/battle_reward_catalog.gd` with GodotIQ `script_ops`:

```gdscript
class_name BattleRewardCatalog
extends RefCounted


static func get_options_for(event_type: String) -> Array[BattleRewardOption]:
	match event_type:
		HexMapModel.ENCOUNTER_COMBAT:
			return [
				BattleRewardOption.new(
					&"combat_recruit_scout",
					BattleRewardOption.Kind.RECRUITMENT,
					"Recruit Scout",
					"Recruit a Scout after this battle."
				),
				BattleRewardOption.new(
					&"combat_money_100",
					BattleRewardOption.Kind.MONEY,
					"100 Money",
					"Take 100 money for this run."
				),
				BattleRewardOption.new(
					&"combat_supply_cache",
					BattleRewardOption.Kind.ITEM,
					"Supply Cache",
					"Take a cache of practical supplies."
				),
			]
		HexMapModel.ENCOUNTER_BOSS:
			return [
				BattleRewardOption.new(
					&"boss_recruit_champion",
					BattleRewardOption.Kind.RECRUITMENT,
					"Recruit Champion",
					"Recruit a Champion after this boss battle."
				),
				BattleRewardOption.new(
					&"boss_money_250",
					BattleRewardOption.Kind.MONEY,
					"250 Money",
					"Take 250 money for this run."
				),
				BattleRewardOption.new(
					&"boss_rare_relic",
					BattleRewardOption.Kind.ITEM,
					"Rare Relic",
					"Take a rare relic from the defeated boss."
				),
			]
		_:
			return []
```

Run immediately:

```text
validate(target="res://Scripts/Battle/battle_reward_catalog.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_reward_catalog.gd")
```

- [ ] **Step 6: Run the catalog subset and prove GREEN**

Temporarily call only the first four tests in `_run()`, run the focused runner, and expect those assertions to pass. Restore all 14 calls before committing.

- [ ] **Step 7: Commit the pure reward contract**

```powershell
git add -- Scripts/Battle/battle_reward_option.gd Scripts/Battle/battle_reward_catalog.gd Tests/Battle/test_ac2_5_reward_selection.gd
git commit -m "feat: add fixed battle reward catalog"
```

### Task 2: Add the reward panel and explicit selection contract

**Files:**

- Modify: `Scenes/battle_arena.tscn`
- Modify: `Scripts/Battle/battle_arena.gd`
- Test: `Tests/Battle/test_ac2_5_reward_selection.gd`

- [ ] **Step 1: Inspect scene and signature impact**

Use:

```text
file_context(file="res://Scenes/battle_arena.tscn", detail="full")
file_context(file="res://Scripts/Battle/battle_arena.gd", detail="normal")
impact_check(file="res://Scripts/Battle/battle_arena.gd", action="modify_function", target="_complete_battle", change_description="populate fixed reward choices on victory")
impact_check(file="res://Scripts/Battle/battle_arena.gd", action="modify_function", target="configure_units", change_description="clear reward state when arena is reused")
```

Expected: the existing `battle_completed` and `exit_requested` contracts stay compatible.

- [ ] **Step 2: Finish the ten failing arena tests**

Use helpers that instantiate `ARENA_PATH`, add it to `root`, await one frame, configure `"combat"`/`"boss"`, create one player and one enemy, set the losing unit to `6` HP, and call `perform_debug_damage()` to reach a real AC2.4 terminal state.

The ten arena cases must assert these exact contracts:

```gdscript
# 5 initial UI
RewardPanel.visible == false
RewardOptions.get_child_count() == 0
RewardDescriptionLabel.text == ""
ConfirmRewardButton.disabled == true
arena.call("get_selected_reward") == null

# 6 Combat victory
RewardPanel.visible == true
arena.call("get_reward_options").size() == 3
first option reward_id == &"combat_recruit_scout"

# 7 Boss victory
RewardPanel.visible == true
first option reward_id == &"boss_recruit_champion"

# 8 defeat
RewardPanel.visible == false
arena.call("get_reward_options").is_empty()

# 9 selection and replacement
arena.call("select_reward", &"combat_recruit_scout")
ConfirmRewardButton.disabled == false
RewardDescriptionLabel.text == "Recruit a Scout after this battle."
arena.call("select_reward", &"combat_money_100")
arena.call("get_selected_reward").reward_id == &"combat_money_100"
RewardDescriptionLabel.text == "Take 100 money for this run."

# 10 confirmation
reward_confirmed arrives before exit_requested
confirmed reward_id == the selected ID
each signal count == 1 after two confirm calls
RewardPanel.visible == false
RewardOptions.get_child_count() == 0
arena.call("get_selected_reward") == null

# 11 debug exit
exit count == 1
reward count == 0
panel hidden and controls cleared

# 12 reconfiguration
configure_units(fresh_units) after victory restores hidden/empty/null/disabled state

# 13 unsupported terminal presentation
configure(Vector2i.ZERO, "combat"), then set encounter_type = "safe" for the
test-only unsupported branch before victory; panel is visible, option count is 0,
RewardEmptyStateLabel.visible is true, text is "No rewards available",
ConfirmRewardButton.disabled is true

# 14 new instance
after cleaning/freeing the first confirmed arena, a newly instantiated arena is
hidden/empty/null/disabled and contains no prior title or description
```

Run the focused runner. Expected: catalog cases pass and arena cases fail because the nodes/API do not yet exist.

- [ ] **Step 3: Build the exact scene subtree with GodotIQ**

In `Scenes/battle_arena.tscn`, replace the current single child of:

```text
Margin/VBox/BattleResultPanel
```

with this subtree:

```text
BattleResultContent (VBoxContainer)
├── BattleResultLabel (Label, unique name, horizontal_alignment=CENTER)
└── RewardPanel (PanelContainer, unique name, visible=false)
    └── RewardContent (VBoxContainer)
        ├── RewardHeadingLabel (Label, unique name, text="Choose a reward", horizontal_alignment=CENTER)
        ├── RewardOptions (VBoxContainer, unique name)
        ├── RewardEmptyStateLabel (Label, unique name, visible=false, text="No rewards available")
        ├── RewardDescriptionLabel (Label, unique name, text="", autowrap_mode=WORD_SMART)
        └── ConfirmRewardButton (Button, unique name, text="Confirm Reward", disabled=true)
```

Use `node_ops(validate=true)` for the scene changes, then `save_scene()`, `undo_history(detail="brief")`, and `file_context(..., detail="full")`. Do not write raw `.tscn` text. Preserve the existing `%BattleResultLabel` unique name so AC2.4 remains compatible.

- [ ] **Step 4: Add the exact BattleArena interface and state**

Use GodotIQ `script_ops` patches. Add:

```gdscript
signal reward_confirmed(option: BattleRewardOption)

const SELECTED_REWARD_COLOR := Color(1.0, 0.82, 0.32, 1.0)

@onready var _reward_panel: PanelContainer = %RewardPanel
@onready var _reward_heading_label: Label = %RewardHeadingLabel
@onready var _reward_options_container: VBoxContainer = %RewardOptions
@onready var _reward_empty_state_label: Label = %RewardEmptyStateLabel
@onready var _reward_description_label: Label = %RewardDescriptionLabel
@onready var _confirm_reward_button: Button = %ConfirmRewardButton

var _reward_options: Array[BattleRewardOption] = []
var _selected_reward: BattleRewardOption
var _reward_confirmation_latched: bool = false
```

Add these public methods:

```gdscript
func get_reward_options() -> Array[BattleRewardOption]:
	return _reward_options.duplicate()


func get_selected_reward() -> BattleRewardOption:
	return _selected_reward


func select_reward(reward_id: StringName) -> void:
	if _reward_confirmation_latched or _battle_outcome != BattleOutcome.Type.VICTORY:
		return
	for option: BattleRewardOption in _reward_options:
		if option.reward_id == reward_id:
			_selected_reward = option
			_refresh_reward_selection_ui()
			return


func confirm_reward_selection() -> void:
	if (
		_reward_confirmation_latched
		or _battle_outcome != BattleOutcome.Type.VICTORY
		or not is_instance_valid(_selected_reward)
	):
		return
	_reward_confirmation_latched = true
	var confirmed_reward := _selected_reward
	_clear_reward_ui()
	reward_confirmed.emit(confirmed_reward)
	exit_requested.emit()
```

In `_ready()`, connect `_confirm_reward_button.pressed` once to `confirm_reward_selection` and call `_clear_reward_ui()` before the first refresh.

At the start of `configure_units()`, call `_clear_reward_ui()`. In `_complete_battle()`, after latching and emitting `battle_completed`, call `_show_victory_rewards()` only for `VICTORY`; call `_clear_reward_ui()` for every other outcome.

Add:

```gdscript
func _show_victory_rewards() -> void:
	_clear_reward_ui()
	_reward_options = BattleRewardCatalog.get_options_for(encounter_type)
	_reward_panel.visible = true
	_reward_heading_label.text = "%s Rewards" % encounter_type.capitalize()
	_reward_empty_state_label.visible = _reward_options.is_empty()
	for option: BattleRewardOption in _reward_options:
		var button := Button.new()
		button.text = option.title
		button.set_meta("reward_id", option.reward_id)
		button.pressed.connect(select_reward.bind(option.reward_id))
		_reward_options_container.add_child(button)


func _refresh_reward_selection_ui() -> void:
	for child: Node in _reward_options_container.get_children():
		var button := child as Button
		if button == null:
			continue
		var is_selected := button.get_meta("reward_id", &"") == _selected_reward.reward_id
		button.self_modulate = SELECTED_REWARD_COLOR if is_selected else Color.WHITE
	_reward_description_label.text = _selected_reward.description
	_confirm_reward_button.disabled = false


func _clear_reward_ui() -> void:
	_reward_confirmation_latched = false
	_selected_reward = null
	_reward_options.clear()
	if not is_node_ready():
		return
	for child: Node in _reward_options_container.get_children():
		_reward_options_container.remove_child(child)
		child.queue_free()
	_reward_panel.visible = false
	_reward_heading_label.text = "Choose a reward"
	_reward_empty_state_label.visible = false
	_reward_description_label.text = ""
	_confirm_reward_button.disabled = true
```

Because Confirm calls `_clear_reward_ui()`, preserve the latch through emission by changing its reset responsibility: `_clear_reward_ui(reset_latch: bool = true)` and call `_clear_reward_ui(false)` from Confirm. This exact distinction is required so a second Confirm call cannot emit again before arena deletion.

Change `_on_exit_debug_pressed()` to clear the reward UI before deferring exit:

```gdscript
func _on_exit_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	_clear_reward_ui()
	call_deferred("_emit_exit_requested")
```

- [ ] **Step 5: Validate the script before running tests**

```text
validate(target="res://Scripts/Battle/battle_arena.gd", detail="brief")
check_errors(scope="res://Scripts/Battle/battle_arena.gd")
```

Expected: no convention, typing, parser, missing-node, or missing-signal errors. Fix one script before proceeding.

- [ ] **Step 6: Run focused tests and prove GREEN**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
```

Expected: `AC2.5 reward selection tests: PASS (14/14)` and exit `0`.

- [ ] **Step 7: Run visual QA**

Use:

```text
run(action="play")
verify_project_runs()
explore(mode="tour")
```

Win a Combat battle, select each option, and inspect the panel. Confirm the panel is readable, the selected option is unmistakable, Confirm gating is visible, formations/log remain usable, and the panel disappears on confirmation. Fix scene/script issues, save, and tour once more. Stop the game.

- [ ] **Step 8: Commit arena integration**

```powershell
git add -- Scenes/battle_arena.tscn Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_5_reward_selection.gd
git commit -m "feat: add AC2.5 reward selection panel"
```

### Task 3: Prove cleanup, map exit, and regressions

**Files:**

- Verify: `Scripts/Map/map_controller.gd`
- Test: `Tests/Battle/test_ac2_5_reward_selection.gd`
- Test: all existing `Tests/**/*.gd`

- [ ] **Step 1: Verify the map lifecycle seam without changing it**

Use:

```text
file_context(file="res://Scripts/Map/map_controller.gd", detail="normal")
trace_flow(trigger="exit_requested", depth=6, detail="normal")
signal_map(scope="file:res://Scripts/Map/map_controller.gd", find="missing", detail="brief")
```

Expected: `BattleArena.exit_requested` reaches `MapController.exit_active_battle()`, which nulls `_active_battle`, removes it from the UI parent, and queues it for deletion. Do not add a `reward_confirmed` listener or run-state placeholder.

- [ ] **Step 2: Run the focused AC2.5 runner**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
```

Expected: `AC2.5 reward selection tests: PASS (14/14)` and exit `0`.

- [ ] **Step 3: Run battle regressions**

```powershell
godot --headless --path . --script res://Tests/Map/test_ac2_1_battle_arena.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_2_speed_order.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_3_damage_defeat_log.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_4_battle_results.gd
```

Expected: every runner prints its documented PASS signature and exits `0`. AC2.4 still freezes terminal combat and shows exact `Victory`/`Defeat`.

- [ ] **Step 4: Run the complete test corpus**

```powershell
$testScripts = rg --files Tests -g 'test_*.gd' | Sort-Object
foreach ($testScript in $testScripts) {
    & godot --headless --path . --script ("res://" + ($testScript -replace '\\','/'))
    if ($LASTEXITCODE -ne 0) { throw "FAILED: $testScript" }
}
```

Expected: every discovered runner exits `0`.

- [ ] **Step 5: Run project-wide GodotIQ gates**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(scope="all", find="missing", detail="brief")
signal_map(scope="all", find="orphans", detail="brief")
```

Expected: no convention, parser, or missing-signal errors. `reward_confirmed` is an intentional orphan until a later run-state criterion consumes it; record it as such rather than adding a fake listener.

- [ ] **Step 6: Run the runtime cleanup gate**

Use the mandatory sequence:

```text
run(action="play")
verify_project_runs()
read_debug_console()
state_inspect(query="active battle, reward panel visible, selected reward, confirm disabled")
run(action="stop")
```

Manually win, select, confirm, and open the next battle between inspections. Expected: the first arena disappears, `MapController.has_active_battle()` becomes false, and the next arena begins with hidden panel, null selection, empty options, empty description, and disabled Confirm.

- [ ] **Step 7: Commit any test-only corrections**

If verification required corrections, validate and commit only the relevant AC2.5 files:

```powershell
git add -- Scripts/Battle/battle_reward_option.gd Scripts/Battle/battle_reward_catalog.gd Scripts/Battle/battle_arena.gd Scenes/battle_arena.tscn Tests/Battle/test_ac2_5_reward_selection.gd
git commit -m "test: harden AC2.5 reward lifecycle"
```

If no corrections were required, do not create an empty commit.

### Task 4: Migrate the verification contract and record evidence

**Files:**

- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.5/2026-07-29/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.5/2026-07-29/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.5/2026-07-29/implementation-link.txt`

- [ ] **Step 1: Capture automated evidence**

Write the exact focused, regression, full-corpus, GodotIQ validation/signal/runtime, and visual-tour commands with exit codes and `PASS`/`FAIL`/`BLOCKED` labels to `automated-test.log`. The focused signature must be:

```text
AC2.5 reward selection tests: PASS (14/14)
```

- [ ] **Step 2: Execute and record the manual runtime check**

Create:

```markdown
# AC2.5 Manual Runtime Check

- Implementation commit: `<full commit SHA>`
- Combat victory options: PASS/FAIL/BLOCKED — Scout, 100 Money, and Supply Cache are shown.
- Combat explicit selection: PASS/FAIL/BLOCKED — selection highlight and description move when another option is chosen.
- Combat Confirm gating: PASS/FAIL/BLOCKED — Confirm is disabled before selection and enabled afterward.
- Combat cleanup: PASS/FAIL/BLOCKED — confirming removes the reward screen and fight.
- Next-battle isolation: PASS/FAIL/BLOCKED — the next battle starts with no visible reward UI, prior selection, or prior description.
- Boss victory options: PASS/FAIL/BLOCKED — Champion, 250 Money, and Rare Relic are shown.
- Boss distinction: PASS/FAIL/BLOCKED — Boss options visibly differ from Combat options.
- Boss cleanup: PASS/FAIL/BLOCKED — confirming removes the reward screen and fight.
- Defeat behavior: PASS/FAIL/BLOCKED — defeat never shows reward options.
- Layout/readability: PASS/FAIL/BLOCKED — panel, descriptions, selection, and Confirm remain readable and usable.

Overall: PASS/FAIL/BLOCKED
```

- [ ] **Step 3: Replace the manual-only AC2.5 verification row**

Replace the existing row, rather than adding a duplicate:

```markdown
| `AC2.5` | Manual runtime check | Win battles from at least two different event types and verify the reward screen presents multiple selectable options appropriate to each event. |
```

with:

```markdown
| `AC2.5` | Automated and manual runtime check | Run `Tests/Battle/test_ac2_5_reward_selection.gd` to verify the fixed Combat/Boss catalogs, explicit selection and Confirm gating, typed signal order and idempotence, defeat and unsupported-event behavior, cleanup, reset, and new-battle isolation. Then win Combat and Boss battles, verify each presents its three appropriate fixed options, select and confirm one, confirm the reward screen disappears with the fight, and verify the next battle starts without stale reward UI or selection. |
```

- [ ] **Step 4: Mark AC2.5 complete only after every gate passes**

Only when all automated, regression, GodotIQ, runtime, visual, and manual rows are `PASS`, change:

```markdown
- [ ] AC2.5 — Winning battle presents multiple reward options based on the event type, with the player choosing from options such as recruitment, money, or item rewards
```

to:

```markdown
- [x] AC2.5 — Winning battle presents multiple reward options based on the event type, with the player choosing from options such as recruitment, money, or item rewards
```

Do not claim AC3.1, AC3.2, inventory, currency persistence, encounter consumption, or AC4.1.

- [ ] **Step 5: Record the implementation link**

Write the full tested commit SHA and a newline to `implementation-link.txt`. The automated log, manual record, and link must identify the same commit.

- [ ] **Step 6: Self-review coverage, placeholders, and types**

```powershell
rg -n "T(BD)|T(ODO)|implement la[t]er|fill in det[a]ils|appropriate error handl[i]ng|similar to Ta[s]k" Docs/superpowers/plans/2026-07-29-ac2-5-reward-selection.md
rg -n "AC2\\.5|BattleRewardOption|BattleRewardCatalog|reward_confirmed|RewardPanel|14/14|PASS|FAIL|BLOCKED" Docs/superpowers/plans/2026-07-29-ac2-5-reward-selection.md Docs/Specs/GAME_DESIGN_SPEC_MVP.md
git diff --check
git status --short
```

Expected: no placeholder hits or whitespace errors; every matrix row maps to a named test/manual observation; all APIs consistently use `BattleRewardOption`, `reward_id`, `get_options_for`, `select_reward`, and `confirm_reward_selection`; unrelated user files remain unstaged.

- [ ] **Step 7: Commit documentation and evidence**

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.5/2026-07-29
git commit -m "docs: record AC2.5 completion evidence"
```

- [ ] **Step 8: Verify the committed state**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
git status --short --branch
git log -5 --oneline
```

Expected: focused PASS `(14/14)`, all AC2.5 commits are present on the task branch, the evidence points to the tested implementation commit, and unrelated pre-existing workspace changes were not committed. Push only when remote handoff or review is requested.

## Completion boundary

AC2.5 is complete only when the same recorded implementation commit has:

1. Focused AC2.5 PASS `(14/14)` with exit `0`.
2. AC2.1–AC2.4 and full-corpus regression PASS.
3. GodotIQ project, parser, signal, runtime, and visual gates recorded as PASS.
4. Manual Combat and Boss selection, confirmation, cleanup, defeat, and next-battle isolation observations recorded as PASS.
5. Matching automated, manual, and implementation-link evidence under `Docs/Specs/AC2/Evidence/AC2.5/2026-07-29/`.
6. The source verification row migrated to combined automated/manual coverage.
7. AC2.5 checked in the source spec.

Any missing, stale, failed, or blocked artifact; unavailable executable; incorrect fixed option; confirm-before-select behavior; duplicate or misordered signal; reward on defeat; hidden unsupported empty state; stale reward UI in the next battle; unreadable presentation; parser/runtime error; or accidental claim of later run-state behavior keeps AC2.5 unchecked.
