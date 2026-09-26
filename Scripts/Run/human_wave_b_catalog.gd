extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"human_field_medic":
			return _character(class_id, "Field Medic", 6, 19, 4, 2, [&"combat_patch", &"guarded_recovery", &"hold_the_wound"])
		&"human_crosbowman":
			return _character(class_id, "Crosbowman", 6, 20, 6, 2, [&"sightline_mark", &"repeating_shot", &"commanding_volley"])
		&"human_duelist":
			return _character(class_id, "Duelist", 7, 21, 8, 1, [&"cut_the_distance", &"counterstep", &"final_verdict"])
		_:
			return null


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
