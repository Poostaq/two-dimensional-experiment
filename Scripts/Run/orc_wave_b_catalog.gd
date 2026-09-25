extends RefCounted

const IDS: Array[StringName] = [&"orc_chainwarden", &"orc_war_drummer", &"orc_siegebreaker"]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"orc_chainwarden":
			return RunCharacter.new(class_id, "Chainwarden", 4, 27, _skills(&"chainwarden"), 4, 4, &"orc")
		&"orc_war_drummer":
			return RunCharacter.new(class_id, "War Drummer", 5, 24, _skills(&"war_drummer"), 4, 3, &"orc")
		&"orc_siegebreaker":
			return RunCharacter.new(class_id, "Siegebreaker", 2, 25, _skills(&"siegebreaker"), 8, 3, &"orc")
		_:
			return null


static func _skills(prefix: StringName) -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var ids: Array = {
	&"chainwarden": [&"chain_lash", &"yank_back", &"lockdown"],
	&"war_drummer": [&"marching_beat", &"crushing_cadence", &"war_tempo"],
	&"siegebreaker": [&"test_the_plate", &"crack_armor", &"demolishing_blow"],
}.get(prefix, [])
	if ids.size() != 3:
		return []
	return [
		_active_skill(ids[0], ids[0].capitalize(), 100, 1, effect_script),
		_active_skill(ids[1], ids[1].capitalize(), 120, 2, effect_script),
		_active_skill(ids[2], ids[2].capitalize(), 150, 4, effect_script),
	]


static func _active_skill(id: StringName, name: String, percent: int, cooldown: int, effect_script: Script) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(1, 1, BattleUnitState.Side.ENEMY, false, false)
	return CharacterSkill.create(id, name, CharacterSkill.Kind.ACTIVE, "Deal %d%% Power." % percent, "One active enemy.", "None", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], [effect_script.damage(effect_script.TargetRole.PRIMARY, percent)])
