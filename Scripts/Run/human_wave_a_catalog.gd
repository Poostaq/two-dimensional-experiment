extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"human_vanguard":
			return _character(class_id, "Vanguard", 5, 22, 5, 3, [&"commanding_step", &"shielded_advance", &"lineholders_verdict"])
		&"human_ranger":
			return RunCharacter.new(class_id, "Ranger", 7, 18, _ranger(), 7, 1, &"human")
		&"human_iron_sentinel":
			return _character(class_id, "Iron Sentinel", 4, 25, 4, 4, [&"brace_the_line", &"field_fortification", &"wall_of_steel"])
		_:
			return null


static func _ranger() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_authored_skill(&"quick_draw", "Quick Draw", 1, [], [e.damage(e.TargetRole.PRIMARY, 90), e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1)]),
		_authored_skill(&"pinning_volley", "Pinning Volley", 2, [c.create(c.Kind.PRIMARY_SNARED)], [e.damage(e.TargetRole.PRIMARY, 130), e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
		_authored_skill(&"break_the_angle", "Break the Angle", 4, [c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [e.conditional_damage(e.TargetRole.PRIMARY, 170, 210, e.BonusCondition.SNARED_AND_ADVANTAGE, true)]),
	]


static func _authored_skill(id: StringName, title: String, cooldown: int, conditions: Array[RefCounted], effects: Array[RefCounted]) -> CharacterSkill:
	var p := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = p.create(1, 1, BattleUnitState.Side.ENEMY)
	return CharacterSkill.create(id, title, CharacterSkill.Kind.ACTIVE, title, "One enemy.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, conditions, effects)


static func _character(id: StringName, name: String, speed: int, hp: int, power: int, defense: int, skill_ids: Array[StringName]) -> RunCharacter:
	return RunCharacter.new(id, name, speed, hp, _skills(skill_ids), power, defense, &"human")


static func _skills(ids: Array[StringName]) -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var result: Array[CharacterSkill] = []
	for index: int in ids.size():
		var percent: int = 80 + index * 40
		result.append(_skill(ids[index], percent, index + 1, e))
	return result


static func _skill(id: StringName, percent: int, cooldown: int, e: Script) -> CharacterSkill:
	var p := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = p.create(1, 1, BattleUnitState.Side.ENEMY)
	return CharacterSkill.create(id, String(id).replace("_", " ").capitalize(), CharacterSkill.Kind.ACTIVE, "Deal %d%% Power." % percent, "One enemy.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], [e.damage(e.TargetRole.PRIMARY, percent)])
