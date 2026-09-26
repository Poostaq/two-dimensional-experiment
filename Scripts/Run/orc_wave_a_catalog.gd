extends RefCounted

const IDS: Array[StringName] = [&"orc_iron_tusk_vanguard", &"orc_bonebreaker_reaver", &"orc_bloodbanner_captain"]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"orc_iron_tusk_vanguard":
			return RunCharacter.new(class_id, "Iron Tusk Vanguard", 2, 30, _skills(&"iron_tusk"), 5, 5, &"orc")
		&"orc_bonebreaker_reaver":
			return RunCharacter.new(class_id, "Bonebreaker Reaver", 4, 26, _skills(&"bonebreaker"), 8, 2, &"orc")
		&"orc_bloodbanner_captain":
			return RunCharacter.new(class_id, "Bloodbanner Captain", 3, 28, _skills(&"bloodbanner"), 5, 4, &"orc")
		_:
			return null


static func _skills(prefix: StringName) -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	if prefix == &"iron_tusk":
		return [_brace_line(effect_script), _active_skill(&"shield_ram", "Shield Ram", 100, 2, effect_script), _hold_the_gap(effect_script)]
	if prefix == &"bloodbanner":
		return [_plant_banner(effect_script), _active_skill(&"rally_strike", "Rally Strike", 90, 2, effect_script), _active_skill(&"last_standard", "Last Standard", 150, 5, effect_script)]
	var ids: Array = {
	&"iron_tusk": [&"brace_line", &"shield_ram", &"hold_the_gap"],
	&"bonebreaker": [&"crushing_entry", &"break_formation", &"execution_swing"],
}.get(prefix, [])
	if ids.size() != 3:
		return []
	return [
		_active_skill(ids[0], ids[0].capitalize(), 100, 1, effect_script),
		_active_skill(ids[1], ids[1].capitalize(), 120, 2, effect_script),
		_active_skill(ids[2], ids[2].capitalize(), 150, 4, effect_script),
	]


static func _brace_line(effect_script: Script) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(1, 1, BattleUnitState.Side.PLAYER, true, false)
	return CharacterSkill.create(&"brace_line", "Brace Line", CharacterSkill.Kind.ACTIVE, "You and a neighboring ally each gain 4 Armor.", "One active adjacent ally.", "Requires a legal adjacent ally.", "CD1", CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ALLY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, 1, 0, null, [], null, null, profile, [], [effect_script.keyword(effect_script.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 4), effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4)])


static func _plant_banner(effect_script: Script) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(1, 2, BattleUnitState.Side.PLAYER, true, false)
	return CharacterSkill.create(&"plant_banner", "Plant Banner", CharacterSkill.Kind.ACTIVE, "You and neighboring allies each gain 3 Armor.", "One or two active adjacent allies.", "Requires an ally able to gain Armor.", "CD2", CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ALLY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, 2, 0, null, [], null, null, profile, [], [effect_script.keyword(effect_script.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 3)])


static func _hold_the_gap(effect_script: Script) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(2, 2, BattleUnitState.Side.PLAYER, true, false)
	return CharacterSkill.create(&"hold_the_gap", "Hold the Gap", CharacterSkill.Kind.ACTIVE, "You and both neighboring allies each gain 5 Armor.", "Two active adjacent allies.", "Requires two legal adjacent allies able to gain Armor.", "CD4", CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ALLY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, 4, 0, null, [], null, null, profile, [], [effect_script.keyword(effect_script.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 5), effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 5), effect_script.keyword(effect_script.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 5)])


static func _active_skill(id: StringName, name: String, percent: int, cooldown: int, effect_script: Script) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(1, 1, BattleUnitState.Side.ENEMY, false, false)
	return CharacterSkill.create(id, name, CharacterSkill.Kind.ACTIVE, "Deal %d%% Power." % percent, "One active enemy.", "None", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], [effect_script.damage(effect_script.TargetRole.PRIMARY, percent)])
