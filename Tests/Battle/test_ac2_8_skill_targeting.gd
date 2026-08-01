class_name Ac2_8SkillTargetingTests
extends SceneTree

const CHARACTER_SKILL_PATH := "res://Scripts/Battle/character_skill.gd"
const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const REQUIRED_ENUMS: Array[String] = [
	"TargetingMode",
	"TargetSide",
	"TargetRule",
	"Requirement",
	"Effect",
	"EffectDuration",
	"CooldownMode",
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_typed_mechanical_contract_exists()
	_test_mechanical_definition_validation_and_copy()
	await _test_active_fixture_mechanics()
	if _failures.is_empty():
		print("AC2.8 skill targeting tests: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AC2.8 skill targeting tests: FAIL (%d)" % _failures.size())
	quit(1)


func _test_typed_mechanical_contract_exists() -> void:
	var character_skill_script := load(CHARACTER_SKILL_PATH) as Script
	_expect(character_skill_script != null, "CharacterSkill script must load.")
	if character_skill_script == null:
		return
	var constants: Dictionary = character_skill_script.get_script_constant_map()
	for enum_name: String in REQUIRED_ENUMS:
		_expect(constants.has(enum_name), "CharacterSkill must define %s." % enum_name)
	_expect(
		character_skill_script.has_method("is_valid_mechanical_definition"),
		"CharacterSkill must validate typed mechanical definitions."
	)
	var create_arg_count := -1
	var validator_arg_count := -1
	for method: Dictionary in character_skill_script.get_script_method_list():
		if method.get("name", "") == "create":
			create_arg_count = (method.get("args", []) as Array).size()
		if method.get("name", "") == "is_valid_mechanical_definition":
			validator_arg_count = (method.get("args", []) as Array).size()
	_expect(
		create_arg_count == 18,
		"CharacterSkill.create must accept preview plus eleven mechanical fields."
	)
	_expect(
		validator_arg_count == 12,
		"Mechanical validation must accept skill kind plus eleven mechanical fields."
	)
	var exposes_mechanical_definition := false
	for method: Dictionary in character_skill_script.get_script_method_list():
		if method.get("name", "") == "mechanical_definition":
			exposes_mechanical_definition = true
			break
	_expect(
		exposes_mechanical_definition,
		"CharacterSkill must expose its typed mechanical definition."
	)


func _test_mechanical_definition_validation_and_copy() -> void:
	var skill := CharacterSkill.create(
		&"shield_bash",
		"Shield Bash",
		CharacterSkill.Kind.ACTIVE,
		"Deal 7 damage.",
		"Select one active enemy.",
		"User must occupy a front-row slot.",
		"1 action after use.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.FRONT_ROW,
		CharacterSkill.Effect.DAMAGE,
		7,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		1,
		0
	)
	_expect(skill != null, "A valid Shield Bash mechanical definition must be accepted.")
	if skill == null:
		return
	var definition := skill.mechanical_definition()
	_expect(definition.get("targeting_mode") == CharacterSkill.TargetingMode.FREE, "Targeting mode must be preserved.")
	_expect(definition.get("target_side") == CharacterSkill.TargetSide.ENEMY, "Target side must be preserved.")
	_expect(definition.get("target_rule") == CharacterSkill.TargetRule.SELECT_ONE, "Target rule must be preserved.")
	_expect(definition.get("requirement") == CharacterSkill.Requirement.FRONT_ROW, "Requirement must be preserved.")
	_expect(definition.get("effect") == CharacterSkill.Effect.DAMAGE, "Effect must be preserved.")
	_expect(definition.get("effect_magnitude") == 7, "Effect magnitude must be preserved.")
	_expect(definition.get("effect_duration") == 0, "Effect duration must be preserved.")
	_expect(definition.get("effect_duration_mode") == CharacterSkill.EffectDuration.NONE, "Effect duration mode must be preserved.")
	_expect(definition.get("cooldown_mode") == CharacterSkill.CooldownMode.POST_USE_ACTIONS, "Cooldown mode must be preserved.")
	_expect(definition.get("cooldown_actions") == 1, "Cooldown actions must be preserved.")
	_expect(definition.get("unavailable_through_round") == 0, "Round gate must be preserved.")
	var copied := skill.duplicate_skill()
	_expect(copied != null and copied != skill, "duplicate_skill must return a distinct valid object.")
	_expect(copied != null and copied.mechanical_definition() == definition, "duplicate_skill must preserve every mechanical field.")
	var passive_damage := CharacterSkill.create(
		&"bad_passive", "Bad Passive", CharacterSkill.Kind.PASSIVE,
		"None", "Self.", "None", "None",
		CharacterSkill.TargetingMode.PREDEFINED, CharacterSkill.TargetSide.SELF,
		CharacterSkill.TargetRule.SELF, CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE, 1, 0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE, 0, 0
	)
	_expect(passive_damage == null, "A passive executable effect must be rejected.")
	var passive_cooldown := CharacterSkill.create(
		&"bad_passive_cooldown", "Bad Passive Cooldown", CharacterSkill.Kind.PASSIVE,
		"None", "Self.", "None", "1 action after use.",
		CharacterSkill.TargetingMode.PREDEFINED, CharacterSkill.TargetSide.SELF,
		CharacterSkill.TargetRule.SELF, CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.NONE, 0, 0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS, 1, 0
	)
	_expect(passive_cooldown == null, "A passive cooldown definition must be rejected.")
	var mismatched_targeting := CharacterSkill.create(
		&"bad_target", "Bad Target", CharacterSkill.Kind.ACTIVE,
		"Deal 1 damage.", "All allies.", "None", "None",
		CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ALLY,
		CharacterSkill.TargetRule.ALL_ACTIVE_ALLIES, CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE, 1, 0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE, 0, 0
	)
	_expect(mismatched_targeting == null, "Free targeting with a non-select-one rule must be rejected.")


func _test_active_fixture_mechanics() -> void:
	var arena := (load(ARENA_PATH) as PackedScene).instantiate() as BattleArena
	get_root().add_child(arena)
	await process_frame
	var expected := {
		&"shield_bash": [CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.FRONT_ROW, CharacterSkill.Effect.DAMAGE, 7, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, 1, 0],
		&"quick_step": [CharacterSkill.TargetingMode.PREDEFINED, CharacterSkill.TargetSide.SELF, CharacterSkill.TargetRule.SELF, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.SPEED_BOOST, 2, CharacterSkill.EffectDuration.NEXT_ACTION, CharacterSkill.CooldownMode.POST_USE_ACTIONS, 2, 0],
		&"quick_strike": [CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.DAMAGE, 5, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0],
		&"rally": [CharacterSkill.TargetingMode.PREDEFINED, CharacterSkill.TargetSide.ALLY, CharacterSkill.TargetRule.ALL_ACTIVE_ALLIES, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.SPEED_BOOST, 2, CharacterSkill.EffectDuration.CURRENT_ROUND, CharacterSkill.CooldownMode.POST_USE_ACTIONS, 2, 0],
		&"savage_blow": [CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.ABOVE_HALF_HP, CharacterSkill.Effect.DAMAGE, 12, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, 2, 0],
		&"shadow_lunge": [CharacterSkill.TargetingMode.PREDEFINED, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.FARTHEST_ACTIVE_ENEMY, CharacterSkill.Requirement.BACK_ROW, CharacterSkill.Effect.DAMAGE, 10, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.ROUND_GATE, 0, 1],
	}
	for unit_id: StringName in [&"player_0", &"player_2", &"player_4", &"enemy_0", &"enemy_4"]:
		var unit := arena.get_unit_by_id(unit_id)
		for skill: CharacterSkill in unit.skills:
			if skill.kind != CharacterSkill.Kind.ACTIVE:
				continue
			var values: Array = expected.get(skill.skill_id, [])
			_expect(not values.is_empty(), "Unexpected active fixture %s." % skill.skill_id)
			if values.is_empty():
				continue
			_expect(skill.targeting_mode == values[0], "%s targeting mode mismatch." % skill.skill_id)
			_expect(skill.target_side == values[1], "%s target side mismatch." % skill.skill_id)
			_expect(skill.target_rule == values[2], "%s target rule mismatch." % skill.skill_id)
			_expect(skill.requirement == values[3], "%s requirement mismatch." % skill.skill_id)
			_expect(skill.effect == values[4] and skill.effect_magnitude == values[5], "%s effect mismatch." % skill.skill_id)
			_expect(skill.effect_duration_mode == values[6], "%s duration mode mismatch." % skill.skill_id)
			_expect(skill.cooldown_mode == values[7] and skill.cooldown_actions == values[8] and skill.unavailable_through_round == values[9], "%s cooldown mismatch." % skill.skill_id)
	arena.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
