class_name WerewolfWaveACatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"werewolf_moonfang_skirmisher",
	&"werewolf_pack_howler",
	&"werewolf_bloodtrail_stalker",
]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"werewolf_moonfang_skirmisher":
			return RunCharacter.new(class_id, "Moonfang Skirmisher", 9, 17, _moonfang(), 9, 0, &"werewolf")
		&"werewolf_pack_howler":
			return RunCharacter.new(class_id, "Pack Howler", 8, 20, _howler(), 6, 1, &"werewolf")
		&"werewolf_bloodtrail_stalker":
			return RunCharacter.new(class_id, "Bloodtrail Stalker", 8, 18, _stalker(), 8, 0, &"werewolf")
		_:
			return null


static func _moonfang() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"scent_blood", "Scent Blood",
			"Against an enemy below 70% HP, deal 70% Power and gain Advantage.",
			"One enemy below 70% HP.", "Requires wounded prey.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_BELOW_SEVENTY_PERCENT_HP)], [
				e.damage(e.TargetRole.PRIMARY, 70),
				e.keyword(
					e.TargetRole.ACTOR,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
		_skill(
			&"pounce", "Pounce",
			"Move up to 2 and deal 140% Power to a neighboring enemy below 70% HP.",
			"Self Move 1-2, then wounded enemy.", "Requires a legal path.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[c.create(c.Kind.PRIMARY_BELOW_SEVENTY_PERCENT_HP)], [
				e.damage(e.TargetRole.PRIMARY, 140, 170),
				e.self_move(2, 1),
			]
		),
		_skill(
			&"moonfang_finish", "Moonfang Finish",
			"Deal 190% Power to an enemy below half HP and Leech 35%.",
			"One enemy below half HP.", "Requires wounded prey.", 4,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_BELOW_HALF_HP)], [
				e.damage(e.TargetRole.PRIMARY, 190),
				e.conditional_leech(e.TargetRole.ACTOR, 35, 40),
			]
		),
	]


static func _howler() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"hunting_cry", "Hunting Cry",
			"While an enemy is below 70% HP, grant up to two allies Advantage.",
			"One or two active allies.", "Requires wounded prey.", 2,
			_profile(1, 2, BattleUnitState.Side.PLAYER),
			[c.create(c.Kind.ANY_ENEMY_BELOW_SEVENTY_PERCENT_HP)], [
				e.keyword(
					e.TargetRole.ALL_SELECTED,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
		_skill(
			&"drive_the_pack", "Drive the Pack",
			"Move an ally 1 along a declared path.",
			"One active ally.", "Requires a legal Move 1 path.", 3,
			_profile(1, 1, BattleUnitState.Side.PLAYER),
			[], [e.forced_target_move(e.TargetRole.PRIMARY, 1)]
		),
		_skill(
			&"full_moon_chorus", "Full-Moon Chorus",
			"This round, each ally's first direct hit Leeches 25%.",
			"All active allies.", "Requires an enemy below half HP.", 5,
			_profile(0, 0, BattleUnitState.Side.PLAYER, false, true),
			[c.create(c.Kind.ANY_ENEMY_BELOW_HALF_HP)], [
				e.next_hit_leech(e.TargetRole.ALL_ACTIVE_ALLIES, 25, 1),
			]
		),
	]


static func _stalker() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"rake", "Rake",
			"Deal 90% Power and apply 1 Bleed for 2 actions.",
			"One active enemy.", "Requires an active enemy.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[], [
				e.damage(e.TargetRole.PRIMARY, 90),
				e.keyword(
					e.TargetRole.PRIMARY,
					BattleKeywordOperation.Kind.APPLY_BLEED,
					0,
					2
				),
			]
		),
		_skill(
			&"follow_the_trail", "Follow the Trail",
			"Move up to 2 and deal 120% Power to a neighboring Bleeding enemy.",
			"Self Move 1-2, then one Bleeding enemy.", "Requires Bleed and a legal path.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[c.create(c.Kind.PRIMARY_BLEEDING)], [
				e.damage(e.TargetRole.PRIMARY, 120),
				e.self_move(2, 1),
			]
		),
		_skill(
			&"cornered_prey", "Cornered Prey",
			"Deal 170% Power to an enclosed Bleeding enemy and add 1 Bleed.",
			"One enclosed Bleeding enemy.", "Requires both neighboring slots occupied.", 4,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[
				c.create(c.Kind.PRIMARY_BLEEDING),
				c.create(c.Kind.PRIMARY_ENCLOSED),
			], [
				e.damage(e.TargetRole.PRIMARY, 170),
				e.keyword(
					e.TargetRole.PRIMARY,
					BattleKeywordOperation.Kind.APPLY_BLEED,
					0,
					2
				),
			]
		),
	]


static func _profile(
	minimum: int,
	maximum: int,
	side: int,
	adjacent: bool = false,
	allows_movement: bool = false
) -> RefCounted:
	var p: Script = load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return p.create(minimum, maximum, side, adjacent, allows_movement)


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
