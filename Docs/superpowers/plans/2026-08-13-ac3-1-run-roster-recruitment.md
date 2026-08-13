# AC3.1 Run Roster Recruitment Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a three-character run roster that accepts eligible Scout or Champion rewards and supplies the updated player lineup to the next battle.

**Architecture:** `RunCharacter`, `RunCharacterCatalog`, and `RunRoster` form a scene-independent run domain. `MapController` owns one roster, supplies fresh player battle states, filters invalid recruitment options before presentation, and consumes confirmed recruitment before battle cleanup. `BattleArena` gains only an injected reward-options override and keeps all existing battle and reward UI ownership.

**Tech Stack:** Godot 4, typed GDScript, GodotIQ structured editing/validation, headless `SceneTree` test runners, Markdown evidence records.

**Authoritative spec:** `Docs/superpowers/specs/2026-08-13-ac3-1-run-roster-recruitment-design.md`

---

## File structure

- Create `Scripts/Run/run_character.gd`: immutable-by-contract run character data and defensive skill copying.
- Create `Scripts/Run/run_character_catalog.gd`: fixed starter definitions and reward-to-character lookup.
- Create `Scripts/Run/run_roster.gd`: ordered roster, capacity/duplicate rules, typed add result, and battle-state conversion.
- Create `Tests/Run/test_ac3_1_run_roster.gd`: focused domain and reward-filter tests.
- Create `Tests/Map/test_ac3_1_recruitment_integration.gd`: real `game_world.tscn` signal/lifecycle and next-fight proof.
- Modify `Scripts/Battle/battle_arena.gd`: accept an optional injected reward list and use it on victory.
- Modify `Scripts/Map/map_controller.gd`: own/reset the roster, configure battles, filter rewards, and apply confirmed recruits.
- Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: migrate AC3.1 to automated/manual verification and check it only after all gates pass.
- Create `Docs/Specs/AC3/Evidence/AC3.1/2026-08-13/*`: current automated, manual, and implementation evidence.

No `.tscn` edit is required. Preserve unrelated untracked `.uid` files.

## Traceability matrix

| AC3.1 contract | Classification | Verification path | Initial status | Required action |
|---|---|---|---|---|
| Run begins with three fixed characters | Logic | `test_ac3_1_run_roster.gd` starter case | Missing | Add focused test |
| Roster accepts a valid recruit below six | Logic | Focused Scout and Champion cases | Missing | Add focused test |
| Full roster exposes no recruitment option | Integration | Focused filtering case plus runtime fixture | Missing | Filter before arena presentation |
| Owned character exposes no duplicate recruit | Integration | Focused filtering case | Missing | Use `RunRoster.can_add()` |
| Stale/direct confirmation cannot bypass rules | Logic/integration | Focused add-result and map-handler cases | Missing | Revalidate on mutation |
| Recruit appears in the next fight | Runtime/integration | `test_ac3_1_recruitment_integration.gd` plus manual run | Missing | Populate arena from roster snapshots |
| Battle mutation does not leak between fights | Logic | Focused conversion-isolation case | Missing | Build fresh battle states |
| No on-map roster or AC3.2 dismissal behavior | Documentation/regression | Spec review and scene diff | Covered by design | Keep scene unchanged |

Overall before implementation: **FAIL (0/7 behavioral contracts have executable AC3.1 evidence).**

### Task 1: Add the run-character value object with TDD

**Files:**
- Create: `Tests/Run/test_ac3_1_run_roster.gd`
- Create: `Scripts/Run/run_character.gd`

- [ ] **Step 1: Inspect before creating**

Use GodotIQ:

```text
file_context(file="res://Scripts/Battle/character_skill.gd", detail="normal")
file_context(file="res://Scripts/Battle/battle_unit_state.gd", detail="normal")
```

Confirm `CharacterSkill` and `BattleUnitState` constructor signatures. Do not read either `.gd` through native filesystem tools.

- [ ] **Step 2: Write the first failing focused tests**

Create `Tests/Run/test_ac3_1_run_roster.gd` through `script_ops(op="create")`. Start with a `SceneTree` runner whose first two cases construct a character and verify defensive skill storage:

```gdscript
class_name Ac3_1RunRosterTests
extends SceneTree

const EXPECTED_TEST_COUNT := 2

var _failures: Array[String] = []


func _initialize() -> void:
	_test_valid_run_character()
	_test_skills_are_defensive()
	if _failures.is_empty():
		print("AC3.1 run roster tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_valid_run_character() -> void:
	var character := RunCharacter.new(&"starter_guard", "Starter Guard", 8, 20, [])
	_expect(character.character_id == &"starter_guard", "character keeps stable ID")
	_expect(character.display_name == "Starter Guard", "character keeps display name")
	_expect(character.base_speed == 8 and character.max_hp == 20, "character keeps base combat data")


func _test_skills_are_defensive() -> void:
	var source: Array[CharacterSkill] = []
	var character := RunCharacter.new(&"starter_guard", "Starter Guard", 8, 20, source)
	source.append(null)
	_expect(character.get_skills().is_empty(), "constructor defensively copies skills")
	var snapshot := character.get_skills()
	snapshot.append(null)
	_expect(character.get_skills().is_empty(), "getter defensively copies skills")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
```

- [ ] **Step 3: Run RED**

```powershell
godot --headless --path . --script res://Tests/Run/test_ac3_1_run_roster.gd
```

Expected: non-zero exit because `RunCharacter` is undefined. A parse error caused by the missing class is the correct RED condition for this first class-creation cycle.

- [ ] **Step 4: Implement the minimal value object**

Create `Scripts/Run/run_character.gd` through GodotIQ:

```gdscript
class_name RunCharacter
extends RefCounted

var character_id: StringName
var display_name: String
var base_speed: int
var max_hp: int

var _skills: Array[CharacterSkill] = []


func _init(
	id: StringName,
	name: String,
	speed: int,
	maximum_hp: int,
	character_skills: Array[CharacterSkill]
) -> void:
	character_id = id
	display_name = name
	base_speed = speed
	max_hp = maximum_hp
	_skills = character_skills.duplicate()


func get_skills() -> Array[CharacterSkill]:
	return _skills.duplicate()
```

- [ ] **Step 5: Validate and run GREEN**

```text
validate(target="res://Scripts/Run/run_character.gd", detail="brief")
check_errors(scope="res://Scripts/Run/run_character.gd")
```

```powershell
godot --headless --path . --script res://Tests/Run/test_ac3_1_run_roster.gd
```

Expected: `AC3.1 run roster tests: PASS (2/2)` and exit `0`.

- [ ] **Step 6: Commit the value object**

```powershell
git add -- Scripts/Run/run_character.gd Tests/Run/test_ac3_1_run_roster.gd
git commit -m "feat: add AC3.1 run character model"
```

### Task 2: Add the fixed character catalog with TDD

**Files:**
- Create: `Scripts/Run/run_character_catalog.gd`
- Modify: `Tests/Run/test_ac3_1_run_roster.gd`

- [ ] **Step 1: Extend the focused runner first**

Increase `EXPECTED_TEST_COUNT` to `6` and add four cases before production code:

```gdscript
func _test_fixed_starters() -> void:
	var starters := RunCharacterCatalog.create_starters()
	_expect(starters.size() == 3, "catalog returns exactly three starters")
	_expect(starters[0].character_id == &"player_0", "first existing player fixture is first")
	_expect(starters[1].character_id == &"player_1", "second existing player fixture is second")
	_expect(starters[2].character_id == &"player_2", "third existing player fixture is third")


func _test_combat_recruit_mapping() -> void:
	var recruit := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	_expect(is_instance_valid(recruit), "Combat recruit resolves")
	_expect(recruit.character_id == &"scout", "Combat recruit resolves to Scout")


func _test_boss_recruit_mapping() -> void:
	var recruit := RunCharacterCatalog.create_for_reward(&"boss_recruit_champion")
	_expect(is_instance_valid(recruit), "Boss recruit resolves")
	_expect(recruit.character_id == &"champion", "Boss recruit resolves to Champion")


func _test_catalog_returns_fresh_characters() -> void:
	var first := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	var second := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	_expect(first != second, "catalog calls return fresh characters")
	_expect(RunCharacterCatalog.create_for_reward(&"combat_money_100") == null, "non-recruit rewards do not map")
	_expect(RunCharacterCatalog.create_for_reward(&"unknown_recruit") == null, "unknown rewards do not map")
```

Call all four cases from `_initialize()`.

- [ ] **Step 2: Run RED**

Run the focused runner. Expected: non-zero exit because `RunCharacterCatalog` is undefined.

- [ ] **Step 3: Implement the catalog**

Create `Scripts/Run/run_character_catalog.gd` through `script_ops`. Use these stable identities and base values:

```gdscript
class_name RunCharacterCatalog
extends RefCounted

const COMBAT_SCOUT_REWARD_ID := &"combat_recruit_scout"
const BOSS_CHAMPION_REWARD_ID := &"boss_recruit_champion"


static func create_starters() -> Array[RunCharacter]:
	return [
		RunCharacter.new(&"player_0", "Player Front 1", 8, 20, []),
		RunCharacter.new(&"player_1", "Player Front 2", 6, 20, []),
		RunCharacter.new(&"player_2", "Player Front 3", 6, 20, []),
	]


static func create_for_reward(reward_id: StringName) -> RunCharacter:
	match reward_id:
		COMBAT_SCOUT_REWARD_ID:
			return RunCharacter.new(&"scout", "Scout", 7, 20, [])
		BOSS_CHAMPION_REWARD_ID:
			return RunCharacter.new(&"champion", "Champion", 9, 24, [])
		_:
			return null
```

Character-specific skills remain empty in this AC because AC3.1 is roster acquisition; future character-content tuning may replace these fixed definitions without changing roster ownership.

- [ ] **Step 4: Validate and run GREEN**

Run GodotIQ `validate` and `check_errors` for the new catalog, then the focused test. Expected: `PASS (6/6)`.

- [ ] **Step 5: Commit the catalog**

```powershell
git add -- Scripts/Run/run_character_catalog.gd Tests/Run/test_ac3_1_run_roster.gd
git commit -m "feat: add AC3.1 run character catalog"
```

### Task 3: Add roster rules and battle conversion with TDD

**Files:**
- Create: `Scripts/Run/run_roster.gd`
- Modify: `Tests/Run/test_ac3_1_run_roster.gd`

- [ ] **Step 1: Add roster behavior tests first**

Raise the count to `13`. Add cases for initialization/order, successful add, duplicate rejection, full rejection, invalid rejection, defensive snapshots, and fresh battle conversion. Assert this exact public contract:

```gdscript
var roster := RunRoster.new()
roster.size() == 3
roster.get_characters()[0].character_id == &"starter_guard"
roster.can_add(&"scout") == true
roster.try_add(RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")) == RunRoster.AddResult.ADDED
roster.size() == 4
roster.try_add(RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")) == RunRoster.AddResult.DUPLICATE
roster.try_add(null) == RunRoster.AddResult.INVALID
```

Fill to six with distinct test characters, assert `is_full()`, and assert a seventh returns `FULL`. Mutate a returned roster array and a returned `BattleUnitState`, then assert the roster and a second conversion remain unchanged. Conversion must assert:

```gdscript
units.size() == roster.size()
units[0].side == BattleUnitState.Side.PLAYER
units[0].slot_index == 0
units[0].unit_id == roster.get_characters()[0].character_id
units[0].current_hp == units[0].max_hp
```

- [ ] **Step 2: Run RED**

Expected: non-zero exit because `RunRoster` is undefined.

- [ ] **Step 3: Implement the roster**

Create `Scripts/Run/run_roster.gd` through GodotIQ:

```gdscript
class_name RunRoster
extends RefCounted

enum AddResult {
	ADDED,
	INVALID,
	DUPLICATE,
	FULL,
}

const MAX_ROSTER_SIZE := 6

var _characters: Array[RunCharacter] = []


func _init(starters: Array[RunCharacter] = []) -> void:
	_characters = RunCharacterCatalog.create_starters() if starters.is_empty() else starters.duplicate()


func size() -> int:
	return _characters.size()


func is_full() -> bool:
	return size() >= MAX_ROSTER_SIZE


func has_character(character_id: StringName) -> bool:
	for character: RunCharacter in _characters:
		if is_instance_valid(character) and character.character_id == character_id:
			return true
	return false


func can_add(character_id: StringName) -> bool:
	return not character_id.is_empty() and not is_full() and not has_character(character_id)


func try_add(character: RunCharacter) -> AddResult:
	if not is_instance_valid(character) or character.character_id.is_empty():
		return AddResult.INVALID
	if has_character(character.character_id):
		return AddResult.DUPLICATE
	if is_full():
		return AddResult.FULL
	_characters.append(character)
	return AddResult.ADDED


func get_characters() -> Array[RunCharacter]:
	return _characters.duplicate()


func create_battle_units() -> Array[BattleUnitState]:
	var units: Array[BattleUnitState] = []
	for slot_index: int in _characters.size():
		var character := _characters[slot_index]
		units.append(BattleUnitState.new(
			character.character_id,
			character.display_name,
			BattleUnitState.Side.PLAYER,
			slot_index,
			character.base_speed,
			character.max_hp,
			character.get_skills()
		))
	return units
```

- [ ] **Step 4: Validate and run GREEN**

Run per-script GodotIQ validation/error checks, then the focused runner. Expected: `AC3.1 run roster tests: PASS (13/13)`.

- [ ] **Step 5: Commit the roster domain**

```powershell
git add -- Scripts/Run/run_roster.gd Tests/Run/test_ac3_1_run_roster.gd
git commit -m "feat: enforce AC3.1 run roster rules"
```

### Task 4: Inject eligible reward options into BattleArena with TDD

**Files:**
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac2_5_reward_selection.gd`

- [ ] **Step 1: Run change-impact gates**

```text
file_context(file="res://Scripts/Battle/battle_arena.gd", detail="normal")
impact_check(file="res://Scripts/Battle/battle_arena.gd", action="modify_function", target="_show_victory_rewards", change_description="Use an injected eligible reward option list when configured", detail="normal")
validate(target="project", detail="brief")
```

Record the baseline. This is a multi-file behavioral change.

- [ ] **Step 2: Add failing AC2.5 compatibility tests**

Extend `test_ac2_5_reward_selection.gd` with a case that calls:

```gdscript
var eligible: Array[BattleRewardOption] = [
	BattleRewardOption.new(&"combat_money_100", BattleRewardOption.Kind.MONEY, "100 Money", "Take 100 money for this run."),
	BattleRewardOption.new(&"combat_supply_cache", BattleRewardOption.Kind.ITEM, "Supply Cache", "Take supplies."),
]
arena.configure_reward_options(eligible)
```

After forcing victory through the runner's existing helper, assert exactly those two IDs are shown. Mutate `eligible` after configuration and assert the arena's options are unchanged. Keep the existing default Combat/Boss catalog cases unchanged to prove backward compatibility.

- [ ] **Step 3: Run RED**

Expected: failure because `configure_reward_options` does not exist.

- [ ] **Step 4: Implement the minimal injected-option seam**

Patch `battle_arena.gd` through `script_ops`:

```gdscript
var _configured_reward_options: Array[BattleRewardOption] = []
var _has_configured_reward_options: bool = false


func configure_reward_options(options: Array[BattleRewardOption]) -> void:
	_configured_reward_options = options.duplicate()
	_has_configured_reward_options = true
```

Change `_show_victory_rewards()` assignment only:

```gdscript
_reward_options = (
	_configured_reward_options.duplicate()
	if _has_configured_reward_options
	else BattleRewardCatalog.get_options_for(encounter_type)
)
```

At the start of `configure()`, reset the override before applying encounter data:

```gdscript
_configured_reward_options.clear()
_has_configured_reward_options = false
```

`MapController` will call `configure()` first and `configure_reward_options()` second. Reconfiguration therefore cannot leak a previous battle's filtered list.

- [ ] **Step 5: Validate and run GREEN**

Run `validate` and `check_errors` for `battle_arena.gd`, then the AC2.5 runner. Expected: its updated documented count passes, including all original fixed-catalog cases.

- [ ] **Step 6: Commit the arena seam**

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_5_reward_selection.gd
git commit -m "feat: support eligible battle reward options"
```

### Task 5: Integrate run roster ownership and recruitment with TDD

**Files:**
- Create: `Tests/Map/test_ac3_1_recruitment_integration.gd`
- Modify: `Scripts/Map/map_controller.gd`

- [ ] **Step 1: Inspect and assess impact before editing**

```text
file_context(file="res://Scripts/Map/map_controller.gd", detail="normal")
impact_check(file="res://Scripts/Map/map_controller.gd", action="modify_function", target="set_run_id", change_description="Reset the run roster with the run lifecycle", detail="normal")
impact_check(file="res://Scripts/Map/map_controller.gd", action="modify_function", target="_on_battle_requested", change_description="Configure player units and eligible rewards, then connect reward confirmation", detail="normal")
trace_flow(trigger="reward_confirmed", depth=6, detail="normal")
```

- [ ] **Step 2: Write the failing integration runner**

Create a real-scene `SceneTree` runner that instantiates `res://Scenes/game_world.tscn` and verifies:

1. `get_run_roster_snapshot()` starts with three IDs.
2. `_get_eligible_reward_options("combat")` contains Scout, money, and item.
3. `_on_reward_confirmed(combat_recruit_scout)` grows the roster to four exactly once.
4. Calling it again leaves size four.
5. Eligible Combat options now omit Scout but keep money/item.
6. After filling to six through the exposed roster test setup, Boss options omit Champion but keep money/item.
7. `set_run_id("another-run")` restores exactly the three starters.
8. A battle created through the existing encounter path contains the roster's player IDs in order.

Use the existing `test_map_controller_runtime.gd` setup helpers as the pattern, but keep AC3.1 assertions in the new runner. Do not add test-only production methods; call public snapshot APIs and real signal handlers via `call()` only where the existing map encounter path is private.

- [ ] **Step 3: Run RED**

```powershell
godot --headless --path . --script res://Tests/Map/test_ac3_1_recruitment_integration.gd
```

Expected: failure because the roster APIs and reward listener are absent.

- [ ] **Step 4: Add roster ownership and public observation**

Patch `map_controller.gd`:

```gdscript
var _run_roster: RunRoster = RunRoster.new()


func get_run_roster_snapshot() -> Array[RunCharacter]:
	return _run_roster.get_characters()
```

In `set_run_id()`, after assigning `run_id`, reset the roster:

```gdscript
_run_roster = RunRoster.new()
```

- [ ] **Step 5: Add pure eligibility filtering**

Add:

```gdscript
func _get_eligible_reward_options(event_type: String) -> Array[BattleRewardOption]:
	var eligible: Array[BattleRewardOption] = []
	for option: BattleRewardOption in BattleRewardCatalog.get_options_for(event_type):
		if option.kind != BattleRewardOption.Kind.RECRUITMENT:
			eligible.append(option)
			continue
		var recruit := RunCharacterCatalog.create_for_reward(option.reward_id)
		if is_instance_valid(recruit) and _run_roster.can_add(recruit.character_id):
			eligible.append(option)
	return eligible
```

- [ ] **Step 6: Configure player roster and eligible rewards**

In `_on_battle_requested()`, after `battle.configure(...)` and before adding the arena:

```gdscript
var units := _run_roster.create_battle_units()
for unit: BattleUnitState in battle.get_turn_queue():
	if unit.side == BattleUnitState.Side.ENEMY:
		units.append(unit)
battle.configure_units(units)
battle.configure_reward_options(_get_eligible_reward_options(encounter_type))
battle.reward_confirmed.connect(Callable(self, "_on_reward_confirmed"))
battle.exit_requested.connect(Callable(self, "exit_active_battle"), CONNECT_ONE_SHOT)
```

The arena's current debug fixtures remain the enemy source for this slice. The player fixtures are replaced with roster-derived states.

- [ ] **Step 7: Apply confirmed recruitment defensively**

Add:

```gdscript
func _on_reward_confirmed(option: BattleRewardOption) -> void:
	if not is_instance_valid(option) or option.kind != BattleRewardOption.Kind.RECRUITMENT:
		return
	var recruit := RunCharacterCatalog.create_for_reward(option.reward_id)
	if not is_instance_valid(recruit):
		return
	_run_roster.try_add(recruit)
```

The add result needs no UI in AC3.1. Its typed result is asserted in domain tests, and every failure leaves the roster unchanged.

- [ ] **Step 8: Validate and run GREEN**

Run per-file `validate`/`check_errors` for `map_controller.gd`, then:

```powershell
godot --headless --path . --script res://Tests/Map/test_ac3_1_recruitment_integration.gd
godot --headless --path . --script res://Tests/Run/test_ac3_1_run_roster.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
```

Expected: all three runners print their documented PASS signatures and exit `0`.

- [ ] **Step 9: Commit integration**

```powershell
git add -- Scripts/Map/map_controller.gd Tests/Map/test_ac3_1_recruitment_integration.gd
git commit -m "feat: recruit AC3.1 units into the run roster"
```

### Task 6: Prove regressions and runtime behavior

**Files:**
- Verify: all `Scripts/**/*.gd`, `Scenes/*.tscn`, and `Tests/**/*.gd`

- [ ] **Step 1: Run the complete headless corpus**

```powershell
$testScripts = rg --files Tests -g 'test_*.gd' | Sort-Object
foreach ($testScript in $testScripts) {
    & godot --headless --path . --script ("res://" + ($testScript -replace '\\','/'))
    if ($LASTEXITCODE -ne 0) { throw "FAILED: $testScript" }
}
```

Expected: every discovered runner exits `0`. Fix any regression using a new failing test first.

- [ ] **Step 2: Run project-wide GodotIQ gates**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(scope="all", find="missing", detail="brief")
signal_map(scope="all", find="orphans", detail="brief")
```

Expected: no parser, convention, or missing-signal errors. `reward_confirmed` must no longer be orphaned because `MapController` consumes it. Any unrelated pre-existing orphan is recorded, not hidden.

- [ ] **Step 3: Run the mandatory play gate**

```text
run(action="play")
verify_project_runs(scene="main", check_scope="project", stop_after=false)
read_debug_console()
```

Expected: Play starts with no failing errors.

- [ ] **Step 4: Verify the initial and next-battle roster states**

Enter a Combat battle. Use `state_inspect` on `/root/GameWorld` for `get_run_roster_snapshot()` and on the active arena for `get_turn_queue()`. Verify three player units. Win, confirm Scout, exit, and enter the next fight. Inspect again and verify four player units in this order:

```text
player_0, player_1, player_2, scout
```

Verify Scout is rendered in player slot 3. No on-map roster widget should exist.

- [ ] **Step 5: Verify filtered rewards visually**

Use a duplicate/full roster test fixture, win a supported battle, and run one `explore(mode="tour")`. Confirm the reward panel contains only the money and item options, has no recruitment control, remains readable, and Confirm works. Stop Play afterward.

- [ ] **Step 6: Commit any test-led correction**

If verification exposed a defect, add a failing regression test, implement the minimal correction through GodotIQ, repeat all relevant gates, and commit only those files. Do not create an empty commit.

### Task 7: Record AC3.1 completion evidence

**Files:**
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Create: `Docs/Specs/AC3/Evidence/AC3.1/2026-08-13/automated-test.log`
- Create: `Docs/Specs/AC3/Evidence/AC3.1/2026-08-13/manual-runtime-check.md`
- Create: `Docs/Specs/AC3/Evidence/AC3.1/2026-08-13/implementation-link.txt`

- [ ] **Step 1: Capture automated evidence**

Record exact commands, exit codes, PASS signatures, GodotIQ results, signal-map results, and runtime gate results in `automated-test.log`. Evidence must identify the tested implementation commit.

- [ ] **Step 2: Record the binary manual check**

Create:

```markdown
# AC3.1 Manual Runtime Check

- Implementation commit: `<full tested commit SHA>`
- Initial roster in first fight: PASS/FAIL/BLOCKED — exactly three starters appear in roster order.
- Eligible Combat reward: PASS/FAIL/BLOCKED — Scout recruitment, money, and item are offered below capacity when Scout is not owned.
- Recruitment confirmation: PASS/FAIL/BLOCKED — confirming Scout exits normally and changes the run roster exactly once.
- Next-fight verification: PASS/FAIL/BLOCKED — the next fight contains four player units with Scout in slot 3.
- Fresh battle state: PASS/FAIL/BLOCKED — the next fight has no stale HP, cooldown, selection, or reward state.
- Duplicate filtering: PASS/FAIL/BLOCKED — an owned recruit is absent while money and item remain.
- Full-roster filtering: PASS/FAIL/BLOCKED — recruitment is absent at six while money and item remain.
- Scope boundary: PASS/FAIL/BLOCKED — no on-map roster UI or dismissal flow was added.

Overall: PASS/FAIL/BLOCKED
```

- [ ] **Step 3: Upgrade the canonical verification row**

Replace the AC3.1 manual-only row with exactly:

```markdown
| `AC3.1` | Automated and manual runtime check | Run `Tests/Run/test_ac3_1_run_roster.gd` and `Tests/Map/test_ac3_1_recruitment_integration.gd` to verify the three-character starter roster, six-unit capacity, duplicate/full/invalid rejection, eligible reward filtering, defensive fresh battle conversion, signal ordering, run reset, and next-battle roster population. Then recruit Scout from a Combat victory while below capacity, enter the next fight, and confirm the original three characters remain in order with Scout in the fourth player slot. Verify duplicate and full-roster victories omit recruitment while preserving money and item options. |
```

- [ ] **Step 4: Mark AC3.1 complete only when every gate is PASS**

Change only AC3.1 from `[ ]` to `[x]`. Leave AC3.2 and later criteria unchecked.

- [ ] **Step 5: Record the implementation link**

Write the full tested implementation commit SHA plus a newline to `implementation-link.txt`. Automated evidence, manual evidence, and link must name the same commit.

- [ ] **Step 6: Self-review the completion artifacts**

```powershell
rg -n "T(BD)|T(ODO)|implement la[t]er|fill in det[a]ils|appropriate error handl[i]ng|similar to Ta[s]k" Docs/superpowers/plans/2026-08-13-ac3-1-run-roster-recruitment.md Docs/Specs/AC3/Evidence/AC3.1/2026-08-13
rg -n "AC3\.1|RunCharacter|RunRoster|combat_recruit_scout|boss_recruit_champion|PASS|FAIL|BLOCKED" Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC3/Evidence/AC3.1/2026-08-13
git diff --check
git status --short
```

Expected: no placeholder or whitespace errors; all AC3.1 contracts map to executable or binary manual evidence; unrelated `.uid` files remain unstaged.

- [ ] **Step 7: Commit documentation and evidence**

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC3/Evidence/AC3.1/2026-08-13
git commit -m "docs: record AC3.1 completion evidence"
```

- [ ] **Step 8: Verify committed state**

Re-run both focused AC3.1 runners, then:

```powershell
git status --short --branch
git log -8 --oneline
```

Expected: both focused PASS signatures, all AC3.1 commits on the dedicated branch, matching evidence SHA, and only the unrelated pre-existing UID files untracked. Push only if remote handoff is requested.

## Completion boundary

AC3.1 is complete only when the same recorded implementation commit has focused domain and integration PASS, full-corpus regression PASS, GodotIQ validation/error/signal PASS, runtime proof of the fourth character in the next fight, binary proof that duplicate/full recruitment is absent while other rewards remain, and matching evidence artifacts. Any stale state, duplicate addition, capacity bypass, missing non-recruit reward, parser/runtime error, unavailable verification capability, or accidental AC3.2/on-map roster implementation keeps AC3.1 unchecked.
