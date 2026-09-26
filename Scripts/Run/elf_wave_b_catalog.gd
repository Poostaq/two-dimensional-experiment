extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"elf_warden_of_the_grove":
			return _character(class_id, "Warden of the Grove", 6, 18, 4, 2, [&"rooting_ward", &"calm_the_ring", &"dawnglass_barrier"])
		&"elf_crescent_duelist":
			return _character(class_id, "Crescent Duelist", 8, 17, 7, 1, [&"cut_the_angle", &"short_arc", &"final_flourish"])
		&"elf_highborn_mystic":
			return _character(class_id, "Highborn Mystic", 7, 16, 8, 0, [&"glyph_of_silence", &"echoed_star", &"final_constellation"])
		_:
			return null


static func _character(id: StringName, name: String, speed: int, hp: int, power: int, defense: int, ids: Array[StringName]) -> RunCharacter:
	return RunCharacter.new(id, name, speed, hp, _skills(ids), power, defense, &"elf")


static func _skills(ids: Array[StringName]) -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var p := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var result: Array[CharacterSkill] = []
	for index: int in ids.size():
		var effects: Array[RefCounted] = [e.damage(e.TargetRole.PRIMARY, 80 + index * 50)]
		if ids[index] == &"glyph_of_silence":
			effects.append(e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1))
		var move: bool = ids[index] in [&"calm_the_ring", &"cut_the_angle"]
		if move:
			effects.append(e.optional_self_move())
		var maximum: int = 2 if ids[index] == &"final_constellation" else 1
		var profile: RefCounted = p.create(1, maximum, BattleUnitState.Side.ENEMY, false, move)
		result.append(CharacterSkill.create(ids[index], String(ids[index]).replace("_", " ").capitalize(), CharacterSkill.Kind.ACTIVE, String(ids[index]), "Authored enemy selection.", "See class record.", "CD%d" % (index + 1), CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, index + 1, 0, null, [], null, null, profile, [], effects))
	return result
