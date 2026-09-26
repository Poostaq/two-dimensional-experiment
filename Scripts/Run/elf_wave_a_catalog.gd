extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"elf_star_archer":
			return RunCharacter.new(class_id, "Star Archer", 8, 16, _star_archer(), 7, 1, &"elf")
		&"elf_moon_sage":
			return RunCharacter.new(class_id, "Moon Sage", 7, 15, _moon_sage(), 7, 0, &"elf")
		&"elf_wind_dancer":
			return _character(class_id, "Wind Dancer", 9, 14, 6, 0, [&"step_through_wind", &"arc_of_escape", &"spiral_opening"])
		_:
			return null


static func _star_archer() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_authored_skill(&"threaded_aim", "Threaded Aim", 1, [], [e.damage(e.TargetRole.PRIMARY, 90), e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
		_authored_skill(&"needle_shot", "Needle Shot", 2, [c.create(c.Kind.PRIMARY_ADVANTAGE)], [e.conditional_damage(e.TargetRole.PRIMARY, 140, 170, e.BonusCondition.MOVED_THIS_ROUND)]),
		_authored_skill(&"horizon_pierce", "Horizon Pierce", 5, [c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [e.damage(e.TargetRole.PRIMARY, 200, 230)]),
	]


static func _moon_sage() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_authored_skill(&"silver_sigil", "Silver Sigil", 1, [], [e.damage(e.TargetRole.PRIMARY, 70), e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1)]),
		_authored_skill(&"lunar_thread", "Lunar Thread", 2, [c.create(c.Kind.PRIMARY_SNARED)], [e.conditional_damage(e.TargetRole.PRIMARY, 120, 150, e.BonusCondition.MOVED_THIS_ROUND)]),
		_authored_skill(&"crescent_collapse", "Crescent Collapse", 5, [c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [e.conditional_damage(e.TargetRole.PRIMARY, 210, 240, e.BonusCondition.SNARED_AND_ADVANTAGE, true)]),
	]


static func _authored_skill(id: StringName, title: String, cooldown: int, conditions: Array[RefCounted], effects: Array[RefCounted]) -> CharacterSkill:
	var p := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = p.create(1, 1, BattleUnitState.Side.ENEMY)
	return CharacterSkill.create(id, title, CharacterSkill.Kind.ACTIVE, title, "One enemy.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, conditions, effects)


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
