class_name HarpyWaveACatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"harpy_talon_duelist",
	&"harpy_storm_siren",
	&"harpy_gale_scout",
]


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
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"raking_pass", "Raking Pass",
			"Move up to 2, then deal 90% Power.",
			"Self Move 0-2, then one enemy.", "Requires a legal path when moving.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[], [
				e.damage(e.TargetRole.PRIMARY, 90),
				e.optional_self_move(2),
			]
		),
		_skill(
			&"exploit_opening", "Exploit Opening",
			"Deal 150% Power to an enemy moved this round; with Advantage, deal 180%.",
			"One enemy moved this round.", "Requires prior movement.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)], [
				e.damage(e.TargetRole.PRIMARY, 150, 180),
			]
		),
		_skill(
			&"wingbeat_retreat", "Wingbeat Retreat",
			"Move up to 2 and gain 4 Armor.",
			"Self Move 0-2.", "Requires a legal path when moving.", 3,
			_profile(0, 0, BattleUnitState.Side.PLAYER, false, true),
			[], [
				e.optional_self_move(2),
				e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
			]
		),
	]


static func _siren() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"gust_call", "Gust Call",
			"Force an enemy to move 1, then grant the selected ally Advantage.",
			"One enemy, then one ally.", "Requires a legal enemy Move 1 path.", 1,
			_profile(
				2, 2, BattleUnitState.Side.ENEMY, false, true,
				[BattleUnitState.Side.ENEMY, BattleUnitState.Side.PLAYER]
			),
			[], [
				e.forced_target_move(e.TargetRole.PRIMARY, 1),
				e.keyword(
					e.TargetRole.SECONDARY,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
		_skill(
			&"crosswind_pull", "Crosswind Pull",
			"Force an enemy moved this round to move 2, then deal 100% Power; with Advantage, deal 130%.",
			"One enemy moved this round.", "Requires a legal enemy Move 2 path.", 3,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)], [
				e.forced_target_move(e.TargetRole.PRIMARY, 2),
				e.damage(e.TargetRole.PRIMARY, 100, 130),
			]
		),
		_skill(
			&"eye_of_the_storm", "Eye of the Storm",
			"Force an enemy to move 3.",
			"One active enemy.", "Requires a legal enemy Move 3 path.", 5,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[], [e.forced_target_move(e.TargetRole.PRIMARY, 3)]
		),
	]


static func _scout() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"spot_the_straggler", "Spot the Straggler",
			"Force an enemy to move 1, then grant the selected ally Advantage.",
			"One enemy, then one ally.", "Requires a legal enemy Move 1 path.", 1,
			_profile(
				2, 2, BattleUnitState.Side.ENEMY, false, true,
				[BattleUnitState.Side.ENEMY, BattleUnitState.Side.PLAYER]
			),
			[], [
				e.forced_target_move(e.TargetRole.PRIMARY, 1),
				e.keyword(
					e.TargetRole.SECONDARY,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
		_skill(
			&"diving_signal", "Diving Signal",
			"Deal 110% Power to an enemy moved this round; with Advantage, deal 150%.",
			"One enemy moved this round.", "Requires prior movement.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)], [
				e.damage(e.TargetRole.PRIMARY, 110, 150),
			]
		),
		_skill(
			&"updraft_reposition", "Updraft Reposition",
			"Move an ally 2 and grant that ally 2 Armor.",
			"One active ally.", "Requires a legal ally Move 2 path.", 3,
			_profile(1, 1, BattleUnitState.Side.PLAYER, false, true),
			[], [
				e.forced_target_move(e.TargetRole.PRIMARY, 2),
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 2),
			]
		),
	]


static func _profile(
	minimum: int,
	maximum: int,
	side: int,
	adjacent: bool = false,
	allows_movement: bool = false,
	ordered_sides: Array[int] = []
) -> RefCounted:
	var p: Script = load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return p.create(minimum, maximum, side, adjacent, allows_movement, ordered_sides)


static func _skill(
	skill_id: StringName,
	title: String,
	effect_text: String,
	targeting_text: String,
	requirements_text: String,
	cooldown: int,
	profile: RefCounted,
	conditions: Array[RefCounted],
	effects: Array[RefCounted]
) -> CharacterSkill:
	return CharacterSkill.create(
		skill_id, title, CharacterSkill.Kind.ACTIVE, effect_text, targeting_text,
		requirements_text, "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0,
		CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		cooldown, 0, null, [], null, null, profile, conditions, effects
	)
