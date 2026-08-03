class_name Ac2_9ComboSystemTests
extends SceneTree

const CONDITION_PATH := "res://Scripts/Battle/combo_condition.gd"
const EFFECT_PATH := "res://Scripts/Battle/combo_bonus_effect.gd"
const DEFINITION_PATH := "res://Scripts/Battle/combo_definition.gd"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_combo_value_contracts()
	_test_character_skill_combo_contract()
	_test_action_entry_migration_contract()
	_test_effect_plan_damage_contract()
	if _failures.is_empty():
		print("AC2.9 combo system tests: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_combo_value_contracts() -> void:
	_expect(FileAccess.file_exists(CONDITION_PATH), "combo condition script should exist")
	_expect(FileAccess.file_exists(EFFECT_PATH), "combo bonus effect script should exist")
	_expect(FileAccess.file_exists(DEFINITION_PATH), "combo definition script should exist")
	if not (
		FileAccess.file_exists(CONDITION_PATH)
		and FileAccess.file_exists(EFFECT_PATH)
		and FileAccess.file_exists(DEFINITION_PATH)
	):
		return
	var condition_script: Script = load(CONDITION_PATH)
	var effect_script: Script = load(EFFECT_PATH)
	var definition_script: Script = load(DEFINITION_PATH)
	var condition: Variant = condition_script.create(0)
	var effect: Variant = effect_script.create(0, 3)
	var conditions: Array = [condition]
	var effects: Array = [effect]
	var definition: Variant = definition_script.create(
		conditions,
		effects,
		"+3 damage if another ally damaged this target with a skill this round."
	)
	_expect(is_instance_valid(condition), "supported combo condition should construct")
	_expect(is_instance_valid(effect), "positive combo bonus should construct")
	_expect(is_instance_valid(definition), "valid combo definition should construct")
	if not is_instance_valid(definition):
		return
	_expect(definition.conditions.size() == 1, "definition should retain one condition")
	_expect(definition.bonus_effects.size() == 1, "definition should retain one bonus effect")
	_expect(definition.bonus_effects[0].magnitude == 3, "definition should retain bonus magnitude")
	var leaked_conditions: Array = definition.conditions
	leaked_conditions.clear()
	_expect(definition.conditions.size() == 1, "condition getter should be defensive")
	var leaked_effects: Array = definition.bonus_effects
	leaked_effects[0] = null
	_expect(is_instance_valid(definition.bonus_effects[0]), "effect getter should be deeply defensive")
	_expect(condition_script.create(99) == null, "unsupported condition should reject")
	_expect(effect_script.create(0, 0) == null, "non-positive bonus should reject")
	var empty_conditions: Array = []
	var empty_effects: Array = []
	_expect(
		definition_script.create(empty_conditions, effects, "Combo") == null,
		"empty conditions should reject"
	)
	_expect(
		definition_script.create(conditions, empty_effects, "Combo") == null,
		"empty effects should reject"
	)
	_expect(
		definition_script.create(conditions, effects, "   ") == null,
		"blank description should reject"
	)
	var duplicate: Variant = definition.duplicate_definition()
	_expect(duplicate != definition, "duplicate definition should be distinct")
	_expect(duplicate.description_text == definition.description_text, "duplicate should preserve text")


func _test_character_skill_combo_contract() -> void:
	var character_script: Script = load("res://Scripts/Battle/character_skill.gd")
	var create_argument_count := 0
	for method: Dictionary in character_script.get_script_method_list():
		if method.get("name", "") == "create":
			create_argument_count = method.get("args", []).size()
			break
	_expect(create_argument_count == 19, "CharacterSkill.create should accept combo definition")
	if create_argument_count != 19:
		return
	var condition_script: Script = load(CONDITION_PATH)
	var effect_script: Script = load(EFFECT_PATH)
	var definition_script: Script = load(DEFINITION_PATH)
	var definition: Variant = definition_script.create(
		[condition_script.create(0)],
		[effect_script.create(0, 3)],
		"+3 damage if another ally damaged this target with a skill this round."
	)
	var skill: Variant = character_script.call(
		"create",
		&"combo_probe",
		"Combo Probe",
		CharacterSkill.Kind.ACTIVE,
		"Deal 5 damage.",
		"One active enemy.",
		"None",
		"None",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		5,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		definition
	)
	_expect(is_instance_valid(skill), "active single-target skill should accept combo definition")
	if not is_instance_valid(skill):
		return
	_expect(is_instance_valid(skill.combo_definition), "combo getter should return definition")
	_expect(skill.combo_definition != definition, "combo definition should be copied on input")
	var mechanical: Dictionary = skill.mechanical_definition()
	_expect(mechanical.has("combo_definition"), "mechanical definition should expose combo")
	var leaked: Variant = mechanical["combo_definition"]
	var leaked_conditions: Array = leaked.conditions
	leaked_conditions.clear()
	_expect(skill.combo_definition.conditions.size() == 1, "mechanical combo should be defensive")
	var duplicate: Variant = skill.duplicate_skill()
	_expect(duplicate != skill, "duplicate skill should be distinct")
	_expect(duplicate.combo_definition != skill.combo_definition, "duplicate combo should be distinct")
	var passive: Variant = character_script.call(
		"create",
		&"bad_passive",
		"Bad Passive",
		CharacterSkill.Kind.PASSIVE,
		"None",
		"Self",
		"None",
		"None",
		CharacterSkill.TargetingMode.PREDEFINED,
		CharacterSkill.TargetSide.SELF,
		CharacterSkill.TargetRule.SELF,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.NONE,
		0,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		definition
	)
	_expect(passive == null, "passive skill should reject combo definition")


func _test_action_entry_migration_contract() -> void:
	var script: Script = load("res://Scripts/Battle/battle_action_log_entry.gd")
	var init_argument_count := 0
	var has_duplicate := false
	for method: Dictionary in script.get_script_method_list():
		if method.get("name", "") == "_init":
			init_argument_count = method.get("args", []).size()
		if method.get("name", "") == "duplicate_entry":
			has_duplicate = true
	_expect(init_argument_count == 11, "BattleActionLogEntry constructor should use migrated schema")
	_expect(has_duplicate, "BattleActionLogEntry should deep-duplicate")
	if init_argument_count != 11 or not has_duplicate:
		return
	var result := BattleDamageResult.new(&"actor", &"target", 8, 8, 12, false)
	var target_ids: Array[StringName] = [&"target"]
	var damage_results: Array[BattleDamageResult] = [result]
	var base_by_target: Dictionary[StringName, int] = {&"target": 5}
	var bonus_by_target: Dictionary[StringName, int] = {&"target": 3}
	var speed_targets: Array[StringName] = []
	var entry: Variant = script.new(
		1, 2, &"actor", BattleUnitState.Side.PLAYER, &"combo_probe",
		target_ids, damage_results, base_by_target, bonus_by_target, speed_targets, true
	)
	_expect(entry.actor_side == BattleUnitState.Side.PLAYER, "entry should retain actor side")
	_expect(entry.base_damage_by_target[&"target"] == 5, "entry should retain base damage")
	_expect(entry.combo_bonus_damage_by_target[&"target"] == 3, "entry should retain combo bonus")
	_expect(entry.combo_activated, "entry should retain combo state")
	var duplicate: Variant = entry.duplicate_entry()
	_expect(duplicate != entry, "entry duplicate should be distinct")
	_expect(duplicate.damage_results[0] != entry.damage_results[0], "damage results should deep-copy")


func _test_effect_plan_damage_contract() -> void:
	var script: Script = load("res://Scripts/Battle/skill_effect_plan.gd")
	_expect(script.has_method("create"), "SkillEffectPlan should expose validated create")
	if not script.has_method("create"):
		return
	var operations: Array[Dictionary] = [{
		&"target_id": &"target",
		&"base_damage": 5,
		&"combo_bonus_damage": 3,
		&"total_requested_damage": 8,
	}]
	var target_ids: Array[StringName] = [&"target"]
	var speed_operations: Array[Dictionary] = []
	var plan: Variant = script.create(
		&"actor", &"combo_probe", target_ids, operations, speed_operations, 0, true, 4
	)
	_expect(is_instance_valid(plan), "valid damage operation should construct")
	if not is_instance_valid(plan):
		return
	var leaked: Array[Dictionary] = plan.damage_operations
	leaked[0][&"total_requested_damage"] = 99
	_expect(plan.damage_operations[0][&"total_requested_damage"] == 8, "plan operations should be defensive")
	var invalid: Array[Dictionary] = [{
		&"target_id": &"target",
		&"base_damage": 5,
		&"combo_bonus_damage": 3,
		&"total_requested_damage": 7,
	}]
	_expect(
		script.create(
			&"actor", &"combo_probe", target_ids, invalid, speed_operations, 0, true, 4
		) == null,
		"invalid damage arithmetic should reject"
	)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
