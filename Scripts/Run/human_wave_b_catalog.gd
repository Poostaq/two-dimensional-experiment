extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"human_field_medic":
			return _character(class_id, "Field Medic", 6, 19, 4, 2, [&"combat_patch", &"guarded_recovery", &"hold_the_wound"])
		&"human_crosbowman":
			return RunCharacter.new(class_id, "Crosbowman", 6, 20, _crossbowman(), 6, 2, &"human")
		&"human_duelist":
			return _character(class_id, "Duelist", 7, 21, 8, 1, [&"cut_the_distance", &"counterstep", &"final_verdict"])
		_:
			return null


static func _crossbowman() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_authored_skill(&"sightline_mark", "Sightline Mark", 1, [], [e.damage(e.TargetRole.PRIMARY, 80), e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
		_authored_skill(&"repeating_shot", "Repeating Shot", 2, [c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [e.damage(e.TargetRole.PRIMARY, 140, 170)]),
		_authored_skill(&"commanding_volley", "Commanding Volley", 5, [], [e.damage(e.TargetRole.PRIMARY, 120, 180), e.damage(e.TargetRole.SECONDARY, 120)], 2),
	]


static func _authored_skill(id: StringName, title: String, cooldown: int, conditions: Array[RefCounted], effects: Array[RefCounted], maximum: int = 1) -> CharacterSkill:
	var p := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = p.create(1, maximum, BattleUnitState.Side.ENEMY)
	return CharacterSkill.create(id, title, CharacterSkill.Kind.ACTIVE, title, "Up to two enemies." if maximum == 2 else "One enemy.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, conditions, effects)


static func _character(id: StringName, name: String, speed: int, hp: int, power: int, defense: int, skill_ids: Array[StringName]) -> RunCharacter:
	return RunCharacter.new(id, name, speed, hp, _skills(skill_ids), power, defense, &"human")


static func _skills(ids: Array[StringName]) -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var p := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var result: Array[CharacterSkill] = []
	for index: int in ids.size():
		var percent: int = 80 + index * 40
		var profile: RefCounted = p.create(1, 1, BattleUnitState.Side.ENEMY)
		result.append(CharacterSkill.create(ids[index], String(ids[index]).replace("_", " ").capitalize(), CharacterSkill.Kind.ACTIVE, "Deal %d%% Power." % percent, "One enemy.", "See class record.", "CD%d" % (index + 1), CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, index + 1, 0, null, [], null, null, profile, [], [e.damage(e.TargetRole.PRIMARY, percent)]))
	return result
