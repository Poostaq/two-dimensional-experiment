extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"harpy_skyhook_raider":
			return RunCharacter.new(class_id, "Skyhook Raider", 8, 18, _skills([&"hook_and_lift", &"drop_out_of_line", &"snatch_away"], [110, 140, 180], [1, 2, 4], true), 7, 1, &"harpy")
		&"harpy_nestguard":
			return RunCharacter.new(class_id, "Nestguard", 7, 20, _nestguard(), 5, 1, &"harpy")
		&"harpy_carrion_cantor":
			return RunCharacter.new(class_id, "Carrion Cantor", 9, 16, _skills([&"cutting_note", &"rending_chorus", &"funeral_spiral"], [85, 130, 190], [1, 2, 5], true), 7, 0, &"harpy")
		_:
			return null


static func _nestguard() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"covering_wings", "Covering Wings", 1, [e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4)], BattleUnitState.Side.PLAYER),
		_skill(&"warning_screech", "Warning Screech", 2, [e.damage(e.TargetRole.PRIMARY, 100)], BattleUnitState.Side.ENEMY),
		_skill(&"rescue_flight", "Rescue Flight", 4, [e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 5), e.optional_self_move()], BattleUnitState.Side.PLAYER, true),
	]


static func _skills(ids: Array[StringName], percents: Array[int], cooldowns: Array[int], movement: bool) -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var result: Array[CharacterSkill] = []
	for index: int in ids.size():
		var effects: Array[RefCounted] = [e.damage(e.TargetRole.PRIMARY, percents[index])]
		if movement and index != 1:
			effects.append(e.optional_self_move())
		result.append(_skill(ids[index], String(ids[index]).replace("_", " ").capitalize(), cooldowns[index], effects, BattleUnitState.Side.ENEMY, movement and index != 1))
	return result


static func _skill(skill_id: StringName, display_name: String, cooldown: int, effects: Array[RefCounted], side: int, allows_movement: bool = false) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(1, 1, side, false, allows_movement)
	var target_side: int = CharacterSkill.TargetSide.ALLY if side == BattleUnitState.Side.PLAYER else CharacterSkill.TargetSide.ENEMY
	return CharacterSkill.create(skill_id, display_name, CharacterSkill.Kind.ACTIVE, display_name, "Authored target and path.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, target_side, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], effects)
