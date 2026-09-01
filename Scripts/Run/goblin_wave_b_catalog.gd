class_name GoblinWaveBCatalog
extends RefCounted

const SCRAPBROKER_ID := &"scrapbroker"
const SHIVRUNNER_ID := &"shivrunner"
const MOBCALLER_ID := &"mobcaller"


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		SCRAPBROKER_ID:
			return RunCharacter.new(class_id, "Scrapbroker", 8, 18, _scrapbroker_skills(), 3, 1, &"goblin")
		SHIVRUNNER_ID:
			return RunCharacter.new(class_id, "Shivrunner", 10, 12, _shivrunner_skills(), 7, 0, &"goblin")
		MOBCALLER_ID:
			return RunCharacter.new(class_id, "Mobcaller", 9, 17, _mobcaller_skills(), 4, 1, &"goblin")
		_:
			return null


static func _scrapbroker_skills() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var condition_script := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_active_skill(&"spot_buyer", "Spot Buyer", "Apply Advantage to one enemy until round end.", "One active enemy.", "None", 1, _profile(1, 1, BattleUnitState.Side.ENEMY), [], [
			effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)
		]),
		_active_skill(&"hand_me_down", "Hand-Me-Down", "Grant an ally 4 Armor, or 5 if it consumed Advantage this round.", "One active ally.", "None", 2, _profile(1, 1, BattleUnitState.Side.PLAYER), [], [
			effect_script.conditional_armor(effect_script.TargetRole.PRIMARY, 4, 5)
		]),
		_active_skill(&"emergency_kit", "Emergency Kit", "Grant an ally below 50% HP 6 Armor.", "One active ally.", "Target must be below 50% maximum HP.", 4, _profile(1, 1, BattleUnitState.Side.PLAYER), [
			condition_script.create(condition_script.Kind.PRIMARY_BELOW_HALF_HP)
		], [
			effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 6)
		]),
	]


static func _shivrunner_skills() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var condition_script := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_active_skill(&"quick_nick", "Quick Nick", "Deal 80% Power and apply 1 Bleed.", "One active enemy.", "None", 1, _profile(1, 1, BattleUnitState.Side.ENEMY), [], [
			effect_script.damage(effect_script.TargetRole.PRIMARY, 80),
			effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_BLEED, 0, 2)
		]),
		_active_skill(&"dirty_window", "Dirty Window", "Deal 125% Power to a Bleeding enemy, or 145% if an ally acted before you this round.", "One active enemy.", "Target must be Bleeding.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [
			condition_script.create(condition_script.Kind.PRIMARY_BLEEDING)
		], [
			effect_script.history_scaled_damage(effect_script.TargetRole.PRIMARY, 125, 20, 145)
		]),
		_active_skill(&"collect_debt", "Collect Debt", "Deal 175% Power to a Bleeding enemy below 50% HP.", "One active enemy.", "Target must be Bleeding and below 50% maximum HP.", 4, _profile(1, 1, BattleUnitState.Side.ENEMY), [
			condition_script.create(condition_script.Kind.PRIMARY_BLEEDING),
			condition_script.create(condition_script.Kind.PRIMARY_BELOW_HALF_HP)
		], [
			effect_script.damage(effect_script.TargetRole.PRIMARY, 175)
		]),
	]


static func _mobcaller_skills() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var condition_script := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_active_skill(&"point_and_yell", "Point and Yell", "Apply Advantage to one enemy until round end.", "One active enemy.", "None", 1, _profile(1, 1, BattleUnitState.Side.ENEMY), [], [
			effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)
		]),
		_active_skill(&"dogpile_math", "Dogpile Math", "Deal 90% Power, +20% per distinct allied attacker on this target this round (max 150%).", "One active enemy.", "An ally must have hit the target earlier this round.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [
			condition_script.create(condition_script.Kind.PRIMARY_HIT_BY_ALLY_THIS_ROUND)
		], [
			effect_script.history_scaled_damage(effect_script.TargetRole.PRIMARY, 90, 20, 150)
		]),
		_active_skill(&"louder_together", "Louder Together", "Choose a different-race ally and an enemy: apply Advantage to the enemy and grant the ally +1 Speed this round.", "One different-race ally, then one enemy.", "The ally must be a different race.", 3, _mixed_profile(), [
			condition_script.create(condition_script.Kind.PRIMARY_DIFFERENT_RACE_FROM_ACTOR)
		], [
			effect_script.keyword(effect_script.TargetRole.SECONDARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1),
			effect_script.speed(effect_script.TargetRole.PRIMARY, 1, 1)
		]),
	]


static func _active_skill(
	skill_id: StringName,
	display_name: String,
	effect_text: String,
	targeting_text: String,
	requirements_text: String,
	cooldown: int,
	profile: RefCounted,
	conditions: Array[RefCounted],
	effects: Array[RefCounted]
) -> CharacterSkill:
	return CharacterSkill.create(
		skill_id, display_name, CharacterSkill.Kind.ACTIVE, effect_text, targeting_text,
		requirements_text, "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0,
		CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		cooldown, 0, null, [], null, null, profile, conditions, effects
	)


static func _profile(minimum: int, maximum: int, side: int) -> RefCounted:
	var script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return script.create(minimum, maximum, side)


static func _mixed_profile() -> RefCounted:
	var script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var sides: Array[int] = [BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY]
	return script.create(2, 2, BattleUnitState.Side.PLAYER, false, false, sides)
