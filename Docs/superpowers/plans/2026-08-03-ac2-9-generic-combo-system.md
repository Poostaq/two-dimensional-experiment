# AC2.9 Generic Combo System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a generic typed condition/effect combo system and prove it with Quick Strike and a differently identified Combo Probe, while keeping the arena's existing action log as the sole authoritative committed-action history.

**Architecture:** Immutable combo definitions and pure `BattleComboRules` consume defensive `BattleActionLogEntry` snapshots supplied explicitly by `BattleArena`. `BattleSkillRules` builds validated effect plans with separate base, combo-bonus, and total requested damage; `BattleArena` alone commits effects, appends authoritative entries, and owns history plus derived-presentation cleanup.

**Tech Stack:** Godot 4.7, typed GDScript, GodotIQ structured inspection/editing/validation, headless `SceneTree` test runners, scene-owned Control UI.

---

## Scope and file map

Create:

- `Scripts/Battle/combo_condition.gd` — immutable typed condition.
- `Scripts/Battle/combo_bonus_effect.gd` — immutable typed bonus effect.
- `Scripts/Battle/combo_definition.gd` — validated AND-only definition with defensive copies.
- `Scripts/Battle/combo_condition_result.gd` — immutable per-condition evidence.
- `Scripts/Battle/combo_evaluation.gd` — immutable aggregate result and diagnostics.
- `Scripts/Battle/battle_combo_rules.gd` — pure condition/effect evaluation.
- `Tests/Battle/test_ac2_9_combo_system.gd` — focused model, migration, rules, integration, presentation, and lifecycle runner.
- `Docs/Specs/AC2/Evidence/AC2.9/2026-08-03/automated-test.log` — exact test evidence.
- `Docs/Specs/AC2/Evidence/AC2.9/2026-08-03/manual-runtime-check.md` — runtime and visual evidence.
- `Docs/Specs/AC2/Evidence/AC2.9/2026-08-03/implementation-link.txt` — tested implementation SHA.

Modify:

- `Scripts/Battle/character_skill.gd` — optional validated `ComboDefinition`.
- `Scripts/Battle/battle_action_log_entry.gd` — coordinated authoritative-history contract migration.
- `Scripts/Battle/skill_effect_plan.gd` — exact damage-operation validation and defensive access.
- `Scripts/Battle/battle_skill_rules.gd` — snapshot-aware generic combo composition.
- `Scripts/Battle/battle_skill_transaction.gd` — derived combo presentation only; no history ownership.
- `Scripts/Battle/battle_arena.gd` — sole history owner, snapshot API, commit migration, cleanup, and UI rendering.
- `Scenes/battle_arena.tscn` — scene-owned Combo tooltip row and combo-ready styling support if a new label is required.
- `Tests/Battle/test_ac2_6_character_skills.gd` — constructor migration and roster contract.
- `Tests/Battle/test_ac2_7_skill_preview.gd` — Combo row preview regression.
- `Tests/Battle/test_ac2_8_skill_targeting.gd` — mechanical constructor and effect-plan migration.
- `Tests/Battle/test_ac2_8_skill_arena.gd` — authoritative action-entry migration.
- `Tests/Battle/test_ac2_8_skill_lifecycle.gd` — cleanup regression.
- `Tests/Battle/test_ac2_8_skill_scene.gd` — scene structure regression.
- `Tests/Battle/test_ac2_8_skill_transaction.gd` — presentation snapshot regression.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md` — AC2.9 verification row and checkbox after evidence passes.

Do not create `BattleSkillActionEvent`, a combo-history array, an evaluator cache, or transaction-owned history. Do not add OR/nested conditions, passive execution, multi-target combo semantics, AI combo planning, persistence, VFX, or audio.

### Task 1: Establish the task branch and baseline

**Files:**
- Inspect only: repository and all affected Godot files

- [ ] **Step 1: Preserve unrelated workspace changes**

Confirm the current tree contains only the known unrelated `.vscode` edits and `temp/`. Save them without staging:

```powershell
git status --short --branch
git stash push --include-untracked -m "user-work-before-ac2-9"
```

Expected: the working tree is clean and the named stash exists. Do not drop it; restore it only after AC2.9 handoff or when the user requests it.

- [ ] **Step 2: Refresh integration metadata and create the task branch**

```powershell
git fetch origin main
git merge-base --is-ancestor origin/main HEAD
git switch -c feat/ac2-9-generic-combos
```

Expected: the ancestry check exits `0`, and the new branch contains the approved AC2.9 design commits. Do not use a worktree in this repository.

- [ ] **Step 3: Run the mandatory structured baseline**

Use GodotIQ:

```text
project_summary(detail="brief")
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
```

Then run every current AC2 runner:

```powershell
godot --headless --path . --script res://Tests/Map/test_ac2_1_battle_arena.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_2_speed_order.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_3_damage_defeat_log.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_4_battle_results.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_5_reward_selection.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_6_character_skills.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_7_skill_preview.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_8_skill_targeting.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_8_skill_transaction.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_8_skill_scene.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_8_skill_arena.gd
godot --headless --path . --script res://Tests/Battle/test_ac2_8_skill_lifecycle.gd
```

Expected: every command exits `0`. Record any pre-existing GodotIQ warnings in the implementation notes; do not broaden AC2.9 to fix unrelated warnings.

- [ ] **Step 4: Inspect every affected contract before editing**

Use GodotIQ `file_context(detail="brief")` on every `.gd` and `.tscn` in the file map. Run `impact_check` at minimum for:

```text
battle_action_log_entry.gd / add_parameter / _init
character_skill.gd / add_parameter / create
character_skill.gd / add_parameter / _init
battle_skill_rules.gd / add_parameter / evaluate_targets
battle_skill_rules.gd / add_parameter / validate_confirmation
```

Expected: an evidence-backed affected-file list is available before any contract changes.

### Task 2: Define immutable combo values and skill metadata

**Files:**
- Create: `Scripts/Battle/combo_condition.gd`
- Create: `Scripts/Battle/combo_bonus_effect.gd`
- Create: `Scripts/Battle/combo_definition.gd`
- Modify: `Scripts/Battle/character_skill.gd`
- Create: `Tests/Battle/test_ac2_9_combo_system.gd`
- Modify: `Tests/Battle/test_ac2_6_character_skills.gd`
- Modify: `Tests/Battle/test_ac2_7_skill_preview.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Write failing construction and copy tests**

Create the AC2.9 runner with `_failures: Array[String]`, `_expect(...)`, and fresh fixtures per test. Add tests equivalent to:

```gdscript
func _test_combo_definition_contract() -> void:
	var condition := ComboCondition.create(
		ComboCondition.Type.TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND
	)
	var effect := ComboBonusEffect.create(ComboBonusEffect.Type.BONUS_DAMAGE, 3)
	var definition := ComboDefinition.create(
		[condition],
		[effect],
		"+3 damage if another ally damaged this target with a skill this round."
	)
	_expect(is_instance_valid(definition), "valid combo definition should construct")
	_expect(definition.conditions.size() == 1, "condition should be retained")
	_expect(definition.bonus_effects[0].magnitude == 3, "bonus should be retained")
	var leaked_conditions := definition.conditions
	leaked_conditions.clear()
	_expect(definition.conditions.size() == 1, "conditions must be defensive")
	_expect(ComboDefinition.create([], [effect], "Combo") == null, "empty conditions reject")
	_expect(ComboDefinition.create([condition], [], "Combo") == null, "empty effects reject")
	_expect(ComboDefinition.create([condition], [effect], "   ") == null, "blank text rejects")
	_expect(ComboBonusEffect.create(ComboBonusEffect.Type.BONUS_DAMAGE, 0) == null, "zero bonus rejects")
```

Add CharacterSkill cases proving `null` is allowed, passive combo ownership rejects, multi-target combo ownership rejects, `mechanical_definition()["combo_definition"]` is a deep copy, and `duplicate_skill()` returns an independent deep copy.

- [ ] **Step 2: Run AC2.9 to verify RED**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_9_combo_system.gd
```

Expected: assertion failures for missing combo classes and `CharacterSkill` metadata. Parser errors in the test harness do not count as RED.

- [ ] **Step 3: Implement the three immutable value classes**

Use GodotIQ `script_ops(op="create")`. Implement these public contracts exactly:

```gdscript
# combo_condition.gd
class_name ComboCondition
extends RefCounted

enum Type { TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND }
var condition_type: Type: get: return _condition_type
var _condition_type: Type

static func create(type_value: int) -> ComboCondition:
	if type_value != Type.TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND:
		push_error("ComboCondition requires a supported type.")
		return null
	return ComboCondition.new(type_value)

func _init(type_value: int) -> void:
	_condition_type = type_value as Type

func duplicate_condition() -> ComboCondition:
	return ComboCondition.new(_condition_type)
```

```gdscript
# combo_bonus_effect.gd
class_name ComboBonusEffect
extends RefCounted

enum Type { BONUS_DAMAGE }
var effect_type: Type: get: return _effect_type
var magnitude: int: get: return _magnitude
var _effect_type: Type
var _magnitude: int

static func create(type_value: int, magnitude_value: int) -> ComboBonusEffect:
	if type_value != Type.BONUS_DAMAGE or magnitude_value <= 0:
		push_error("ComboBonusEffect requires a supported type and positive magnitude.")
		return null
	return ComboBonusEffect.new(type_value, magnitude_value)

func _init(type_value: int, magnitude_value: int) -> void:
	_effect_type = type_value as Type
	_magnitude = magnitude_value

func duplicate_effect() -> ComboBonusEffect:
	return ComboBonusEffect.new(_effect_type, _magnitude)
```

Implement `ComboDefinition` with this complete boundary; keep `_is_valid == false` when direct construction receives invalid input:

```gdscript
class_name ComboDefinition
extends RefCounted

var conditions: Array[ComboCondition]: get: return _duplicate_conditions()
var bonus_effects: Array[ComboBonusEffect]: get: return _duplicate_effects()
var description_text: String: get: return _description_text
var _conditions: Array[ComboCondition] = []
var _bonus_effects: Array[ComboBonusEffect] = []
var _description_text: String = ""
var _is_valid: bool = false

static func create(
	condition_values: Array[ComboCondition],
	effect_values: Array[ComboBonusEffect],
	description: String
) -> ComboDefinition:
	var definition := ComboDefinition.new(condition_values, effect_values, description)
	return definition if definition.is_valid() else null

func _init(
	condition_values: Array[ComboCondition],
	effect_values: Array[ComboBonusEffect],
	description: String
) -> void:
	if condition_values.is_empty() or effect_values.is_empty() or description.strip_edges().is_empty():
		push_error("ComboDefinition requires conditions, effects, and description text.")
		return
	for condition: ComboCondition in condition_values:
		if not is_instance_valid(condition):
			return
		_conditions.append(condition.duplicate_condition())
	for effect: ComboBonusEffect in effect_values:
		if not is_instance_valid(effect):
			return
		_bonus_effects.append(effect.duplicate_effect())
	_description_text = description
	_is_valid = true

func is_valid() -> bool:
	return _is_valid

func duplicate_definition() -> ComboDefinition:
	return ComboDefinition.new(_conditions, _bonus_effects, _description_text) if _is_valid else null

func _duplicate_conditions() -> Array[ComboCondition]:
	var result: Array[ComboCondition] = []
	for condition: ComboCondition in _conditions:
		result.append(condition.duplicate_condition())
	return result

func _duplicate_effects() -> Array[ComboBonusEffect]:
	var result: Array[ComboBonusEffect] = []
	for effect: ComboBonusEffect in _bonus_effects:
		result.append(effect.duplicate_effect())
	return result
```

- [ ] **Step 4: Extend CharacterSkill without compatibility shortcuts**

Add the final parameter to `_init` and `create`:

```gdscript
combo_definition_value: ComboDefinition = null
```

Store a defensive duplicate, expose `combo_definition` through a defensive getter, reject non-null combo definitions unless the skill is active and `target_rule == SELECT_ONE`, include it in `mechanical_definition()`, and pass it through `duplicate_skill()`. Keep every existing AC2.6–AC2.8 default unchanged.

- [ ] **Step 5: Configure Quick Strike and migrate fixtures**

In the production fixture helper, attach:

```gdscript
ComboDefinition.create(
	[ComboCondition.create(ComboCondition.Type.TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND)],
	[ComboBonusEffect.create(ComboBonusEffect.Type.BONUS_DAMAGE, 3)],
	"+3 damage if another ally damaged this target with a skill this round."
)
```

Update AC2.6–AC2.8 fixture constructors explicitly. Skills without combos pass `null`; do not silently rely on an old constructor shape in test helpers.

- [ ] **Step 6: Verify and commit**

Run AC2.6, AC2.7, AC2.8 targeting, and AC2.9. After each changed script, run GodotIQ `validate(target=<file>, detail="brief")` then `check_errors(scope=<file>)`.

```powershell
git add -- Scripts/Battle/combo_condition.gd Scripts/Battle/combo_bonus_effect.gd Scripts/Battle/combo_definition.gd Scripts/Battle/character_skill.gd Tests/Battle/test_ac2_9_combo_system.gd Tests/Battle/test_ac2_6_character_skills.gd Tests/Battle/test_ac2_7_skill_preview.gd Tests/Battle/test_ac2_8_skill_targeting.gd
git commit -m "feat: define generic combo metadata"
```

### Task 3: Migrate BattleActionLogEntry and SkillEffectPlan contracts

**Files:**
- Modify: `Scripts/Battle/battle_action_log_entry.gd`
- Modify: `Scripts/Battle/skill_effect_plan.gd`
- Modify: `Tests/Battle/test_ac2_9_combo_system.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_arena.gd`

- [ ] **Step 1: Write failing contract-migration tests**

Test damaging, non-combo, combo, and Speed-only entries. Require the new constructor shape and `duplicate_entry()`:

```gdscript
var entry := BattleActionLogEntry.new(
	1,
	2,
	&"actor",
	BattleUnitState.Side.PLAYER,
	&"combo_probe",
	[&"target"],
	[BattleDamageResult.new(&"actor", &"target", 8, 8, 12, false)],
	{&"target": 5},
	{&"target": 3},
	[],
	true
)
_expect(entry.base_damage_by_target[&"target"] == 5, "base breakdown retained")
_expect(entry.combo_bonus_damage_by_target[&"target"] == 3, "bonus breakdown retained")
_expect(entry.combo_activated, "combo state retained")
var copy := entry.duplicate_entry()
_expect(copy != entry and copy.damage_results[0] != entry.damage_results[0], "entry copy is deep")
```

Add invalid cases for blank IDs, invalid side, duplicate targets, dictionary keys outside targets, negative values, and `base + bonus != requested_damage`. Add an AC2.8 assertion that all existing action producers now construct the new shape.

- [ ] **Step 2: Write failing exact damage-operation tests**

Construct `SkillEffectPlan` with:

```gdscript
{
	&"target_id": &"target",
	&"base_damage": 5,
	&"combo_bonus_damage": 3,
	&"total_requested_damage": 8,
}
```

Require rejection/null construction for missing keys, extra keys, blank target, negative base/bonus, non-positive total, and invalid arithmetic. Mutate a returned operation and prove the plan remains unchanged.

- [ ] **Step 3: Run AC2.9 and affected AC2.8 runners to verify RED**

Expected: failures for the old entry constructor, missing fields/duplication, and old `{"target_id", "amount"}` plan operations.

- [ ] **Step 4: Implement the full action-entry migration**

Add `actor_side`, defensive `base_damage_by_target`, defensive `combo_bonus_damage_by_target`, `combo_activated`, `is_valid()`, and `duplicate_entry()`. Deep-copy each `BattleDamageResult` by constructing a new result from all six existing fields. Do not add optional defaults to the migrated constructor.

The final constructor order is:

```gdscript
_init(
	sequence: int,
	action_round: int,
	action_actor_id: StringName,
	action_actor_side: BattleUnitState.Side,
	action_skill_id: StringName,
	action_target_ids: Array[StringName],
	action_damage_results: Array[BattleDamageResult],
	action_base_damage_by_target: Dictionary[StringName, int],
	action_combo_bonus_damage_by_target: Dictionary[StringName, int],
	action_speed_target_ids: Array[StringName],
	action_combo_activated: bool
) -> void
```

Speed-only entries use empty damage arrays/dictionaries and `combo_activated == false`. Ordinary damage uses base values, zero bonus values, and `false`.

- [ ] **Step 5: Make SkillEffectPlan validate and own its operation data**

Replace public mutable arrays with defensive getters and backing arrays. Add `static create(...) -> SkillEffectPlan`, `is_valid()`, and exact damage-operation validation. Keep the constructor non-optional and ensure `BattleSkillRules` will use `create()` after Task 5.

- [ ] **Step 6: Migrate all current producers and consumers together**

Update `battle_arena.gd` and AC2.8 fixtures temporarily with explicit zero-bonus values so the project compiles before combo rules exist. Update arena commit validation from `operation["amount"]` to `operation["total_requested_damage"]`. Preserve one logical entry, Speed targets, damage feedback, turn advancement, and outcome behavior.

- [ ] **Step 7: Verify GREEN and commit the migration alone**

Run AC2.3, all five AC2.8 runners, and AC2.9. Validate/check every changed script separately.

```powershell
git add -- Scripts/Battle/battle_action_log_entry.gd Scripts/Battle/skill_effect_plan.gd Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_8_skill_targeting.gd Tests/Battle/test_ac2_8_skill_arena.gd Tests/Battle/test_ac2_9_combo_system.gd
git commit -m "refactor: migrate battle action entry contract"
```

### Task 4: Implement generic pure combo evaluation

**Files:**
- Create: `Scripts/Battle/combo_condition_result.gd`
- Create: `Scripts/Battle/combo_evaluation.gd`
- Create: `Scripts/Battle/battle_combo_rules.gd`
- Modify: `Tests/Battle/test_ac2_9_combo_system.gd`

- [ ] **Step 1: Write failing pure-rule tests**

Build history only from `BattleActionLogEntry` values. Cover positive activation plus same actor, enemy actor, other target, zero applied damage, earlier round, missing definition, and setup actor later removed. Add two independently constructed skills:

```gdscript
var quick_strike := _combo_skill(&"quick_strike", "Quick Strike")
var combo_probe := _combo_skill(&"combo_probe", "Combo Probe")
```

For both skills, assert identical `has_combo`, `activated`, condition results, target IDs, and `+3` bonus operation. This test must call the evaluator with both IDs; no shared skill object or renamed duplicate is sufficient.

Add a two-condition definition with two independently created instances of the supported condition. Require AND semantics and two ordered condition results.

- [ ] **Step 2: Run AC2.9 to verify RED**

Expected: failures for missing result types and evaluator.

- [ ] **Step 3: Implement immutable result types**

`ComboConditionResult` stores condition type, `passed`, and defensive relevant target IDs. `ComboEvaluation` defines:

```gdscript
enum DiagnosticCode { NONE, NO_COMBO, INVALID_INPUT, UNSUPPORTED_CONDITION, UNSUPPORTED_EFFECT }
var has_combo: bool
var activated: bool
var condition_results: Array[ComboConditionResult]
var bonus_operations: Array[Dictionary]
var diagnostic_code: DiagnosticCode
```

Deep-copy all nested data. A failed condition produces no bonus operations.

- [ ] **Step 4: Implement BattleComboRules without skill IDs or arena references**

Use this exact boundary:

```gdscript
static func evaluate(
	definition: ComboDefinition,
	actor: BattleUnitState,
	target_ids: Array[StringName],
	current_round: int,
	history_snapshot: Array[BattleActionLogEntry]
) -> ComboEvaluation
```

For each condition, scan entries in sequence order and pass only when round, side, different actor, target, and positive `BattleDamageResult.applied_damage` all match. On full success, emit ordered dictionaries containing `effect_type`, `magnitude`, and copied `target_ids`. Never inspect `skill_id`; never retain `history_snapshot`.

- [ ] **Step 5: Verify GREEN, validate, and commit**

```powershell
godot --headless --path . --script res://Tests/Battle/test_ac2_9_combo_system.gd
git add -- Scripts/Battle/combo_condition_result.gd Scripts/Battle/combo_evaluation.gd Scripts/Battle/battle_combo_rules.gd Tests/Battle/test_ac2_9_combo_system.gd
git commit -m "feat: evaluate generic combo conditions"
```

### Task 5: Compose combos into BattleSkillRules and effect plans

**Files:**
- Modify: `Scripts/Battle/battle_skill_rules.gd`
- Modify: `Scripts/Battle/skill_confirmation_validation.gd`
- Modify: `Tests/Battle/test_ac2_9_combo_system.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_targeting.gd`

- [ ] **Step 1: Write failing preview and confirmation tests**

Extend calls to both public rule methods with `history_snapshot: Array[BattleActionLogEntry]`. Require target-specific combo readiness from evaluation and current-history reevaluation at confirmation. For Quick Strike and Combo Probe, assert the confirmed plan operation is exactly 5/0/5 without setup and 5/3/8 with setup.

Snapshot all inputs, mutate returned evaluations/plans, and prove inputs are unchanged. Change history or revision between preview and confirmation and require stale rejection or current-state recomputation, never a cached preview bonus.

- [ ] **Step 2: Run AC2.8 targeting and AC2.9 to verify RED**

Expected: signature and missing combo-result failures.

- [ ] **Step 3: Extend the pure rule signatures explicitly**

Add the final required parameter to both methods:

```gdscript
history_snapshot: Array[BattleActionLogEntry]
```

Do not give it a default. Update every caller. `evaluate_targets()` computes target combo readiness for presentation but does not store committed evidence. Extend `SkillTargetEvaluation` only with defensive `combo_ready_target_ids` and per-target bonus totals if needed by rendering.

- [ ] **Step 4: Build validated base/bonus/total operations**

Inside `validate_confirmation()`, call `BattleComboRules.evaluate(...)` after target validation. Sum only `BONUS_DAMAGE` operations matching each accepted target and build:

```gdscript
damage_operations.append({
	&"target_id": target_id,
	&"base_damage": skill.effect_magnitude,
	&"combo_bonus_damage": combo_bonus,
	&"total_requested_damage": skill.effect_magnitude + combo_bonus,
})
```

Construct through `SkillEffectPlan.create(...)`; reject if it returns `null`. Expose the immutable `ComboEvaluation` through `SkillConfirmationValidation` only if presentation/logging needs it; do not persist it as history.

- [ ] **Step 5: Verify GREEN and regress AC2.8**

Run AC2.8 targeting/transaction and AC2.9, then validate/check each changed file.

- [ ] **Step 6: Commit**

```powershell
git add -- Scripts/Battle/battle_skill_rules.gd Scripts/Battle/skill_confirmation_validation.gd Scripts/Battle/skill_target_evaluation.gd Tests/Battle/test_ac2_8_skill_targeting.gd Tests/Battle/test_ac2_9_combo_system.gd
git commit -m "feat: compose combo bonuses into skill plans"
```

### Task 6: Make BattleArena the sole history and cleanup owner

**Files:**
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Tests/Battle/test_ac2_9_combo_system.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_arena.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_lifecycle.gd`

- [ ] **Step 1: Write failing ownership and lifecycle tests**

Require:

```gdscript
var snapshot := arena.get_committed_action_history_snapshot()
snapshot.clear()
_expect(arena.get_committed_action_history_snapshot().size() == 1, "array is defensive")
var second := arena.get_committed_action_history_snapshot()
second[0].base_damage_by_target[&"target"] = 999
_expect(
	arena.get_committed_action_history_snapshot()[0].base_damage_by_target[&"target"] == 5,
	"nested entry state is defensive"
)
```

Prove there is exactly one entry after a combo action and no parallel combo-event property/collection. Exercise configuration, round advance, completion, repeated completion, exit, teardown, and replacement configuration against the lifecycle matrix. Completion retains entries but clears combo interaction; exit/teardown/configuration clear entries idempotently.

- [ ] **Step 2: Run AC2.8 arena/lifecycle and AC2.9 to verify RED**

Expected: failures for missing deep snapshot and cleanup APIs.

- [ ] **Step 3: Implement the sole snapshot boundary**

Add:

```gdscript
func get_committed_action_history_snapshot() -> Array[BattleActionLogEntry]:
	var snapshot: Array[BattleActionLogEntry] = []
	for entry: BattleActionLogEntry in _battle_action_log_entries:
		snapshot.append(entry.duplicate_entry())
	return snapshot
```

Rename `get_battle_action_log_entries()` to `get_committed_action_history_snapshot()` and migrate every caller; do not retain an alias or shallow-copy alternative. Pass a fresh snapshot into every `BattleSkillRules.evaluate_targets()` and `validate_confirmation()` call.

- [ ] **Step 4: Implement the two explicit cleanup owners**

Add idempotent methods:

```gdscript
func _clear_skill_interaction_state() -> void:
	_skill_transaction.reset()
	_hovered_skill_button = null
	_selected_skill_id = &""
	_hide_skill_tooltip()
	_render_skill_transaction()

func _clear_committed_action_history() -> void:
	_battle_action_log_entries.clear()
```

Expand interaction cleanup to clear every combo-ready role, message, summary, lock, hover, Confirm/Cancel state, and Combo tooltip row. Call it from configuration, completion, exit, and teardown. Call history cleanup from configuration, exit, and teardown, but not completion.

- [ ] **Step 5: Commit exact breakdowns through the existing mutation boundary**

In `_commit_skill_effect_plan`, validate and apply `total_requested_damage`. Build base/bonus dictionaries from the plan before mutation. After successful effects, append one migrated `BattleActionLogEntry` with `actor.side`, actual damage results, breakdowns, Speed targets, and `combo_activated == any bonus > 0`. Do not append another history type.

- [ ] **Step 6: Verify GREEN, validate, and commit**

Run AC2.3, all AC2.8 arena/lifecycle tests, and AC2.9. Validate/check `battle_arena.gd` immediately.

```powershell
git add -- Scripts/Battle/battle_arena.gd Tests/Battle/test_ac2_8_skill_arena.gd Tests/Battle/test_ac2_8_skill_lifecycle.gd Tests/Battle/test_ac2_9_combo_system.gd
git commit -m "feat: own combo history in battle arena"
```

### Task 7: Add derived combo presentation

**Files:**
- Modify: `Scripts/Battle/battle_skill_transaction.gd`
- Modify: `Scripts/Battle/battle_arena.gd`
- Modify: `Scenes/battle_arena.tscn`
- Modify: `Tests/Battle/test_ac2_9_combo_system.gd`
- Modify: `Tests/Battle/test_ac2_7_skill_preview.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_scene.gd`
- Modify: `Tests/Battle/test_ac2_8_skill_transaction.gd`

- [ ] **Step 1: Write failing presentation tests**

Assert:

- Only combo-bearing skills show `Combo: +3 damage if another ally damaged this target with a skill this round.`
- A qualifying target receives `combo_ready`; another legal target remains ordinary valid.
- Hover/lock shows `Combo ready: +3 damage` and total 8.
- Without setup, the same target shows total 5 and no readiness claim.
- Locked, invalid, and ordinary valid semantics remain readable.
- Changing revision/history before confirmation cannot reuse preview readiness.
- Completion/configuration/exit clears every derived combo state without changing retained history at completion.

- [ ] **Step 2: Run AC2.7, AC2.8 scene/transaction, and AC2.9 to verify RED**

Expected: missing Combo row/role/summary assertions.

- [ ] **Step 3: Add scene-owned tooltip content through GodotIQ**

Use `file_context` on `Scenes/battle_arena.tscn`, then validated `node_ops` to add a unique `%SkillTooltipComboLabel` below Cooldown if a dedicated label is required. Keep it hidden for skills without combo data. Save with `save_scene()`, then verify unique ownership with structured scene inspection. Do not edit `.tscn` directly.

- [ ] **Step 4: Extend transaction presentation as derived state only**

Add combo-ready target IDs and bonus summaries to the presentation input/snapshot, copying them defensively. The transaction may retain display values for its current generation but must never expose them as committed history or confirmation authority. Confirmation continues to call current rules with a current snapshot.

- [ ] **Step 5: Render Combo row and combo-ready overlay**

Render the description from `skill.combo_definition.description_text`. Add `combo_ready` to `_indicator_style()` and radial tint handling while preserving lock/hover readability. Render exact message and 5/8 summaries from current evaluation. Clear all derived state through `_clear_skill_interaction_state()`.

- [ ] **Step 6: Verify scene, scripts, and visual behavior**

Run AC2.7, AC2.8 scene/transaction/arena, and AC2.9. Use GodotIQ `validate`/`check_errors` per file. Start Play and run `explore(mode="tour")`; describe every screenshot, fix clipping/overlap, and tour again at 1152×648.

- [ ] **Step 7: Commit**

```powershell
git add -- Scripts/Battle/battle_skill_transaction.gd Scripts/Battle/battle_arena.gd Scenes/battle_arena.tscn Tests/Battle/test_ac2_7_skill_preview.gd Tests/Battle/test_ac2_8_skill_scene.gd Tests/Battle/test_ac2_8_skill_transaction.gd Tests/Battle/test_ac2_9_combo_system.gd
git commit -m "feat: present combo readiness in battle"
```

### Task 8: Harden genericity, atomicity, and lifecycle regressions

**Files:**
- Modify: `Tests/Battle/test_ac2_9_combo_system.gd`
- Modify as failures require: AC2.9 production files only

- [ ] **Step 1: Add named end-to-end safety tests**

Add and run:

```gdscript
_test_quick_strike_and_combo_probe_have_identical_generic_results()
_test_same_actor_enemy_other_target_zero_and_prior_round_do_not_activate()
_test_setup_actor_removal_preserves_current_round_evidence()
_test_preview_combo_state_is_not_confirmation_evidence()
_test_combo_confirmation_reentry_commits_once()
_test_rejected_combo_has_zero_partial_mutation()
_test_snapshot_and_nested_entry_mutation_cannot_reach_arena()
_test_completion_retains_history_but_clears_presentation()
_test_configure_exit_and_teardown_clear_history_idempotently()
_test_rules_and_transaction_retain_no_authoritative_history()
```

For every rejected path, snapshot HP, cooldowns, modifiers, queue, round, revision, action entries, damage log, outcome, and transaction state before the attempt; require exact equality afterward.

- [ ] **Step 2: Prove each new test is meaningful**

Temporarily disable only the intended guard/evaluator branch, run the named case to see the expected assertion failure, then restore and implement the minimal guard. Never accept parser errors as RED and never commit the intentional break.

- [ ] **Step 3: Run the full focused suite**

Run all AC2.1–AC2.9 commands from Task 1 plus AC2.9. Expected: all exit `0` with their pass messages.

- [ ] **Step 4: Run project-level GodotIQ gates**

```text
validate(target="project", detail="brief")
check_errors(scope="project")
signal_map(find="orphans", detail="brief")
```

Expected: no new convention, parser, or orphan-signal errors.

- [ ] **Step 5: Commit hardening**

```powershell
git add -- Tests/Battle/test_ac2_9_combo_system.gd Scripts/Battle
git commit -m "test: harden generic combo lifecycle"
```

Before committing, inspect `git diff --cached --name-only` and unstage any unrelated script; only files actually changed for a failing AC2.9 case belong in this commit.

### Task 9: Runtime verification, evidence, and AC2.9 closeout

**Files:**
- Create: `Docs/Specs/AC2/Evidence/AC2.9/2026-08-03/automated-test.log`
- Create: `Docs/Specs/AC2/Evidence/AC2.9/2026-08-03/manual-runtime-check.md`
- Create: `Docs/Specs/AC2/Evidence/AC2.9/2026-08-03/implementation-link.txt`
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`

- [ ] **Step 1: Run final automated verification against one implementation commit**

Run project validation and every AC2 runner again. Capture exact commands, exit codes, pass messages, warnings, and:

```powershell
git rev-parse HEAD
```

Write the results to `automated-test.log`; do not claim a pass for a command not run against that SHA.

- [ ] **Step 2: Run the runtime readiness gate**

Use GodotIQ:

```text
run(action="play")
verify_project_runs(scene="main", check_scope="project", stop_after=false)
read_debug_console()
```

Use `state_inspect` for round, revision, current actor, and action-history count. Expected: Play starts and no failing debugger errors appear.

- [ ] **Step 3: Perform the manual combo matrix**

At 1152×648:

1. Inspect Quick Strike and verify the Combo row.
2. Target an enemy without setup; verify ordinary valid styling and 5-damage summary.
3. Cancel; verify no entry or combo-ready residue.
4. Have a different ally damage enemy A with a committed skill.
5. Return to Quick Strike in the same round; verify enemy A is combo-ready and enemy B is not.
6. Hover/lock enemy A; verify `Combo ready: +3 damage` and total 8.
7. Confirm once; verify 8 requested damage, one action entry, one turn advance, one revision increment, and base/bonus/total log breakdown.
8. Repeat exclusion cases for same actor, enemy source, other target, zero applied damage, and next round.
9. Complete the battle; verify combo UI clears while completed entries remain inspectable.
10. Exit and configure a new battle; verify history snapshot and presentation are empty.

Run `explore(mode="tour")`, describe every screenshot, fix any visual issue, and tour again. Stop Play afterward.

- [ ] **Step 4: Record traceable evidence**

Write the tested SHA to `implementation-link.txt`. The manual record must identify the same SHA and report every step above, ownership/reset behavior, debugger state, and viewport result.

- [ ] **Step 5: Close the MVP criterion**

Only after all evidence passes, change AC2.9 from `[ ]` to `[x]` and replace its verification row with an automated/manual contract naming `Tests/Battle/test_ac2_9_combo_system.gd`, generic Combo Probe parity, positive and negative combo cases, authoritative-history ownership, lifecycle cleanup, and runtime visual confirmation. Preserve exactly one AC2.9 acceptance row and one verification row.

- [ ] **Step 6: Commit evidence and closeout**

```powershell
git add -- Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC2/Evidence/AC2.9/2026-08-03
git commit -m "docs: record AC2.9 verification"
```

- [ ] **Step 7: Run verification-before-completion on the final committed tree**

Repeat project GodotIQ validation, all AC2.1–AC2.9 runners, `verify_project_runs`, and `read_debug_console` against the final commit. Confirm evidence files reference the tested implementation SHA and that only AC2.9 files are committed on the task branch.

Do not claim AC2.9 complete if any current command fails, any evidence SHA differs, any duplicate history collection exists, or any derived combo-ready state survives its lifecycle boundary.

## Self-review checklist

- Every design requirement maps to a task and named verification.
- Quick Strike and differently identified Combo Probe exercise the same generic definition.
- The `BattleActionLogEntry` migration is an isolated contract task with no compatibility defaults.
- Damage plans use exactly `target_id`, `base_damage`, `combo_bonus_damage`, and `total_requested_damage`.
- The arena owns the only history collection and both cleanup methods.
- Rules receive snapshots only and retain no state.
- Combo-ready UI is derived and never confirmation evidence.
- Completion retains entries; configuration, exit, and teardown clear them.
- AC2.1–AC2.8 remain required regressions.
- No placeholder steps or unbounded post-MVP features are included.
