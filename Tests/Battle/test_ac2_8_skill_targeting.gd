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
	_test_unit_runtime_state_contract_exists()
	await _test_cooldown_and_speed_state()
	_test_structured_rules_contract_exists()
	await _test_target_evaluation_and_confirmation()
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
		create_arg_count == 19,
		"CharacterSkill.create must accept preview, mechanical fields, and combo metadata."
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


func _test_unit_runtime_state_contract_exists() -> void:
	var state_script := load("res://Scripts/Battle/battle_unit_state.gd") as Script
	var constants := state_script.get_script_constant_map()
	_expect(constants.has("ModifierExpiry"), "BattleUnitState must define ModifierExpiry.")
	var method_names: Array[String] = []
	for method: Dictionary in state_script.get_script_method_list():
		method_names.append(String(method.get("name", "")))
	for required_method: String in [
		"get_base_speed",
		"get_effective_speed",
		"get_skill_cooldown",
		"set_skill_cooldown",
		"tick_skill_cooldowns",
		"add_speed_modifier",
		"expire_speed_modifiers_after_action",
		"expire_speed_modifiers_for_round",
		"get_speed_modifier_snapshot",
	]:
		_expect(method_names.has(required_method), "BattleUnitState must define %s." % required_method)


func _test_cooldown_and_speed_state() -> void:
	var arena := (load(ARENA_PATH) as PackedScene).instantiate() as BattleArena
	get_root().add_child(arena)
	await process_frame
	var shield := arena.get_unit_by_id(&"player_0").skills[0]
	var quick_step := arena.get_unit_by_id(&"player_2").skills[0]
	var roster: Array[CharacterSkill] = [shield, quick_step]
	var unit := BattleUnitState.new(
		&"runtime_unit", "Runtime Unit", BattleUnitState.Side.PLAYER, 0, 5, 20, roster
	)
	_expect(unit.get_base_speed() == 5, "Base Speed must remain stable.")
	_expect(unit.get_effective_speed() == 5, "Effective Speed must begin at base Speed.")
	_expect(unit.get_skill_cooldown(&"shield_bash") == 0, "Cooldown must begin ready.")
	_expect(unit.set_skill_cooldown(&"shield_bash", 2), "Owned skill cooldown must be accepted.")
	unit.tick_skill_cooldowns([&"shield_bash"])
	_expect(unit.get_skill_cooldown(&"shield_bash") == 2, "New cooldown must skip its application tick.")
	unit.tick_skill_cooldowns([])
	_expect(unit.get_skill_cooldown(&"shield_bash") == 1, "Cooldown must tick once per later action.")
	var cooldown_snapshot := unit.get_skill_cooldown_snapshot()
	cooldown_snapshot[&"shield_bash"] = 99
	_expect(unit.get_skill_cooldown(&"shield_bash") == 1, "Cooldown snapshots must be defensive.")
	_expect(not unit.set_skill_cooldown(&"foreign_skill", 1), "Foreign skill cooldown must be rejected.")
	_expect(unit.add_speed_modifier(&"quick_step", 2, BattleUnitState.ModifierExpiry.NEXT_ACTION, 1, 1), "Next-action modifier must be accepted.")
	_expect(unit.add_speed_modifier(&"rally", 2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1, 1), "Round modifier must be accepted.")
	_expect(unit.get_effective_speed() == 9, "Independent Speed modifiers must stack additively.")
	var modifier_snapshot := unit.get_speed_modifier_snapshot()
	var changed: Dictionary = modifier_snapshot[&"quick_step"]
	changed["amount"] = 99
	modifier_snapshot[&"quick_step"] = changed
	_expect(unit.get_effective_speed() == 9, "Modifier snapshots must be deeply defensive.")
	unit.expire_speed_modifiers_after_action()
	_expect(unit.get_effective_speed() == 7, "Next-action modifier must expire after the unit acts.")
	unit.expire_speed_modifiers_for_round(1)
	_expect(unit.get_effective_speed() == 5, "Round modifier must expire at round end.")
	_expect(not unit.add_speed_modifier(&"", 2, BattleUnitState.ModifierExpiry.NEXT_ACTION, 1, 1), "Blank modifier sources must be rejected.")
	var boosted := BattleUnitState.new(&"boosted", "Boosted", BattleUnitState.Side.PLAYER, 1, 5)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 7)
	_expect(boosted.add_speed_modifier(&"boost", 3, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1, 1), "Queue fixture modifier must be accepted.")
	var queue_units: Array[BattleUnitState] = [enemy, boosted]
	var queue := BattleTurnQueue.build(queue_units)
	_expect(not queue.is_empty() and queue[0].unit_id == &"boosted", "Turn queue must order by effective Speed.")
	arena.queue_free()
	await process_frame


func _test_structured_rules_contract_exists() -> void:
	for path: String in [
		"res://Scripts/Battle/skill_action_reason.gd",
		"res://Scripts/Battle/skill_target_evaluation.gd",
		"res://Scripts/Battle/skill_effect_plan.gd",
		"res://Scripts/Battle/skill_confirmation_validation.gd",
		"res://Scripts/Battle/battle_skill_rules.gd",
	]:
		_expect(FileAccess.file_exists(path), "%s must exist." % path.get_file())
	var rules_script := load("res://Scripts/Battle/battle_skill_rules.gd") as Script
	var rule_methods: Array[String] = []
	for method: Dictionary in rules_script.get_script_method_list():
		rule_methods.append(String(method.get("name", "")))
	_expect(rule_methods.has("evaluate_targets"), "BattleSkillRules must evaluate targets.")
	_expect(rule_methods.has("validate_confirmation"), "BattleSkillRules must validate confirmations.")


func _test_target_evaluation_and_confirmation() -> void:
	var arena := (load(ARENA_PATH) as PackedScene).instantiate() as BattleArena
	get_root().add_child(arena)
	await process_frame
	var shield := _find_fixture_skill(arena, &"shield_bash")
	var shield_roster: Array[CharacterSkill] = [shield]
	var actor := BattleUnitState.new(&"player_actor", "Player Actor", BattleUnitState.Side.PLAYER, 0, 10, 20, shield_roster)
	var ally := BattleUnitState.new(&"player_ally", "Player Ally", BattleUnitState.Side.PLAYER, 5, 4)
	var enemy_front := BattleUnitState.new(&"enemy_front", "Enemy Front", BattleUnitState.Side.ENEMY, 0, 3)
	var enemy_defeated := BattleUnitState.new(&"enemy_defeated", "Enemy Defeated", BattleUnitState.Side.ENEMY, 1, 2)
	enemy_defeated.current_hp = 0
	var units: Array[BattleUnitState] = [actor, ally, enemy_front, enemy_defeated]
	var evaluation := BattleSkillRules.evaluate_targets(actor, shield, units, actor.unit_id, false, 1, 7)
	_expect(evaluation.can_start, "Front-row Shield Bash must be startable by the current player actor.")
	_expect(evaluation.valid_target_ids == [&"enemy_front"], "Free targeting must report exact active-enemy candidates.")
	_expect(evaluation.invalid_targets.has(&"enemy_defeated"), "Free targeting must report defeated enemies as invalid.")
	_expect(evaluation.invalid_targets[&"enemy_defeated"].code == SkillActionReason.Code.TARGET_DEFEATED, "Defeated target reason must be typed.")
	_expect(evaluation.affected_target_ids.is_empty(), "Free targeting must not pre-lock affected targets.")
	_expect(evaluation.battle_revision == 7, "Target evaluation must capture battle revision.")
	var selected_ids: Array[StringName] = [&"enemy_front"]
	var accepted := BattleSkillRules.validate_confirmation(actor, shield, units, actor.unit_id, false, 1, selected_ids, 7, 7)
	_expect(accepted.accepted and accepted.effect_plan != null, "Valid free-target confirmation must return an effect plan.")
	_expect(
		accepted.effect_plan.damage_operations == [{
			&"target_id": &"enemy_front",
			&"base_damage": 7,
			&"combo_bonus_damage": 0,
			&"total_requested_damage": 7,
		}],
		"Shield Bash must plan exact base damage without combo bonus."
	)
	_expect(accepted.effect_plan.cooldown_actions == 1 and accepted.effect_plan.advance_turn, "Shield Bash plan must apply cooldown and advance once.")
	var defeated_ids: Array[StringName] = [&"enemy_defeated"]
	var rejected := BattleSkillRules.validate_confirmation(actor, shield, units, actor.unit_id, false, 1, defeated_ids, 7, 7)
	_expect(not rejected.accepted and rejected.effect_plan == null, "Invalid confirmation must not return an effect plan.")
	_expect(rejected.reason.code == SkillActionReason.Code.TARGET_DEFEATED, "Invalid confirmation must preserve exact target reason.")
	var stale := BattleSkillRules.validate_confirmation(actor, shield, units, actor.unit_id, false, 1, selected_ids, 7, 8)
	_expect(not stale.accepted and stale.reason.code == SkillActionReason.Code.REVISION_MISMATCH, "Revision mismatch must reject confirmation as stale.")
	_expect(stale.reason.message == "Battle state changed. Review this skill again.", "Stale rejection message must be exact.")
	var quick_step := _find_fixture_skill(arena, &"quick_step")
	var quick_roster: Array[CharacterSkill] = [quick_step]
	var quick_actor := BattleUnitState.new(&"quick_actor", "Quick Actor", BattleUnitState.Side.PLAYER, 4, 10, 20, quick_roster)
	var quick_units: Array[BattleUnitState] = [quick_actor, ally, enemy_front]
	var quick_eval := BattleSkillRules.evaluate_targets(quick_actor, quick_step, quick_units, quick_actor.unit_id, false, 1, 9)
	_expect(quick_eval.affected_target_ids == [&"quick_actor"], "Quick Step must predefine self.")
	var quick_validation := BattleSkillRules.validate_confirmation(quick_actor, quick_step, quick_units, quick_actor.unit_id, false, 1, quick_eval.affected_target_ids, 9, 9)
	_expect(quick_validation.accepted and quick_validation.effect_plan.speed_operations.size() == 1, "Quick Step must create one Speed operation.")
	_expect(quick_validation.effect_plan.speed_operations[0].get("expiry") == BattleUnitState.ModifierExpiry.NEXT_ACTION, "Quick Step must use next-action expiry.")
	var shadow := _find_fixture_skill(arena, &"shadow_lunge")
	var shadow_roster: Array[CharacterSkill] = [shadow]
	var shadow_actor := BattleUnitState.new(&"shadow_actor", "Shadow Actor", BattleUnitState.Side.PLAYER, 4, 10, 20, shadow_roster)
	var enemy_back := BattleUnitState.new(&"enemy_back", "Enemy Back", BattleUnitState.Side.ENEMY, 5, 1)
	var shadow_units: Array[BattleUnitState] = [shadow_actor, enemy_front, enemy_back]
	var round_one := BattleSkillRules.evaluate_targets(shadow_actor, shadow, shadow_units, shadow_actor.unit_id, false, 1, 10)
	_expect(not round_one.can_start and round_one.blocking_reason.code == SkillActionReason.Code.PRE_USE_COOLDOWN, "Shadow Lunge must be blocked during round 1.")
	var round_two := BattleSkillRules.evaluate_targets(shadow_actor, shadow, shadow_units, shadow_actor.unit_id, false, 2, 11)
	_expect(round_two.can_start and round_two.affected_target_ids == [&"enemy_back"], "Shadow Lunge must lock deterministic farthest enemy from round 2.")
	arena.queue_free()
	await process_frame


func _find_fixture_skill(arena: BattleArena, skill_id: StringName) -> CharacterSkill:
	for unit_id: StringName in [&"player_0", &"player_2", &"player_4", &"enemy_0", &"enemy_4"]:
		for skill: CharacterSkill in arena.get_unit_by_id(unit_id).skills:
			if skill.skill_id == skill_id:
				return skill
	return null


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
