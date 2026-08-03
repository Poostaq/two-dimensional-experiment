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


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
