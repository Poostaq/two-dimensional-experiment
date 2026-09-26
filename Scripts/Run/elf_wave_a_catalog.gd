extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"elf_star_archer":
			return _character(class_id, "Star Archer", 8, 16, 7, 1, [&"threaded_aim", &"needle_shot", &"horizon_pierce"])
		&"elf_moon_sage":
			return _character(class_id, "Moon Sage", 7, 15, 7, 0, [&"silver_sigil", &"lunar_thread", &"crescent_collapse"])
		&"elf_wind_dancer":
			return _character(class_id, "Wind Dancer", 9, 14, 6, 0, [&"step_through_wind", &"arc_of_escape", &"spiral_opening"])
		_:
			return null


static func _character(id: StringName, name: String, speed: int, hp: int, power: int, defense: int, ids: Array[StringName]) -> RunCharacter:
	return RunCharacter.new(id, name, speed, hp, _skills(ids), power, defense, &"elf")


static func _skills(ids: Array[StringName]) -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var p := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var result: Array[CharacterSkill] = []
	for index: int in ids.size():
		var effects: Array[RefCounted] = [e.damage(e.TargetRole.PRIMARY, 80 + index * 40)]
		var move: bool = ids[index] in [&"step_through_wind", &"arc_of_escape", &"spiral_opening"]
		if move:
			effects.append(e.optional_self_move())
		var profile: RefCounted = p.create(1, 1, BattleUnitState.Side.ENEMY, false, move)
		result.append(CharacterSkill.create(ids[index], String(ids[index]).replace("_", " ").capitalize(), CharacterSkill.Kind.ACTIVE, String(ids[index]), "One enemy.", "See class record.", "CD%d" % (index + 1), CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, index + 1, 0, null, [], null, null, profile, [], effects))
	return result
