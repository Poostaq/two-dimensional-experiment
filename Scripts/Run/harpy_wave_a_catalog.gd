extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"harpy_talon_duelist":
			return RunCharacter.new(class_id, "Talon Duelist", 10, 14, _duelist(), 8, 0, &"harpy")
		&"harpy_storm_siren":
			return RunCharacter.new(class_id, "Storm Siren", 8, 17, _siren(), 6, 1, &"harpy")
		&"harpy_gale_scout":
			return RunCharacter.new(class_id, "Gale Scout", 10, 12, _scout(), 6, 0, &"harpy")
		_:
			return null


static func _duelist() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"raking_pass", "Raking Pass", 1, [e.damage(e.TargetRole.PRIMARY, 100), e.optional_self_move()], true),
		_skill(&"exploit_opening", "Exploit Opening", 2, [e.damage(e.TargetRole.PRIMARY, 150, 180)]),
		_skill(&"wingbeat_retreat", "Wingbeat Retreat", 3, [e.optional_self_move(), e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 3)], true),
	]


static func _siren() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"gust_call", "Gust Call", 1, [e.forced_target_move(e.TargetRole.PRIMARY, 1)], true),
		_skill(&"crosswind_pull", "Crosswind Pull", 3, [e.forced_target_move(e.TargetRole.PRIMARY, 2), e.damage(e.TargetRole.PRIMARY, 100, 130)], true),
		_skill(&"eye_of_the_storm", "Eye of the Storm", 5, [e.forced_target_move(e.TargetRole.PRIMARY, 3)], true),
	]


static func _scout() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"spot_the_straggler", "Spot the Straggler", 1, [e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
		_skill(&"diving_signal", "Diving Signal", 2, [e.damage(e.TargetRole.PRIMARY, 120), e.optional_self_move()], true),
		_skill(&"updraft_reposition", "Updraft Reposition", 3, [e.optional_self_move(), e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 2)], true),
	]


static func _skill(skill_id: StringName, display_name: String, cooldown: int, effects: Array[RefCounted], allows_movement: bool = false, minimum: int = 1, maximum: int = 1) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(minimum, maximum, BattleUnitState.Side.ENEMY, false, allows_movement)
	return CharacterSkill.create(skill_id, display_name, CharacterSkill.Kind.ACTIVE, display_name, "Authored target and path.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], effects)
