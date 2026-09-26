class_name OrcWaveBCatalog
extends RefCounted

const IDS: Array[StringName] = [&"orc_chainwarden", &"orc_war_drummer", &"orc_siegebreaker"]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"orc_chainwarden":
			return RunCharacter.new(class_id, "Chainwarden", 4, 27, _chainwarden_skills(), 4, 4, &"orc")
		&"orc_war_drummer":
			return RunCharacter.new(class_id, "War Drummer", 5, 24, _war_drummer_skills(), 4, 3, &"orc")
		&"orc_siegebreaker":
			return RunCharacter.new(class_id, "Siegebreaker", 2, 25, _siegebreaker_skills(), 8, 3, &"orc")
		_:
			return null


static func _chainwarden_skills() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"chain_lash", "Chain Lash", "Deal 70% Power and move an enemy 1.",
			"One active enemy.", "Requires a legal Move 1 path.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY), [],
			[e.damage(e.TargetRole.PRIMARY, 70), e.forced_target_move(e.TargetRole.PRIMARY, 1)]
		),
		_skill(
			&"yank_back", "Yank Back", "Move an already-moved enemy 2, then deal 100% Power.",
			"One active enemy.", "Target must have moved this round; requires a legal Move 2 path.", 3,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)],
			[e.forced_target_move(e.TargetRole.PRIMARY, 2), e.damage(e.TargetRole.PRIMARY, 100)]
		),
		_skill(
			&"lockdown", "Lockdown", "Stun one enemy moved this round.",
			"One active enemy.", "Front row; target moved this round without Stun Guard.", 5,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)],
			[e.stun(e.TargetRole.PRIMARY)],
			CharacterSkill.Requirement.FRONT_ROW
		),
	]


static func _war_drummer_skills() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"marching_beat", "Marching Beat", "Grant one eligible ally Advantage until round end.",
			"One active ally.", "Requires an eligible ally.", 2,
			_profile(1, 1, BattleUnitState.Side.PLAYER), [],
			[e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]
		),
		_skill(
			&"crushing_cadence", "Crushing Cadence", "After an ally hits, deal 120% Power; with Advantage, deal 150%.",
			"One active enemy.", "Target must have been hit by an ally this round.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_HIT_BY_ALLY_THIS_ROUND)],
			[e.damage(e.TargetRole.PRIMARY, 120, 150)]
		),
		_skill(
			&"war_tempo", "War Tempo", "All active allies gain 3 Armor.",
			"All selected active allies.", "Requires at least two allies able to gain Armor.", 5,
			_profile(2, 6, BattleUnitState.Side.PLAYER), [],
			[e.keyword(e.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 3)]
		),
	]


static func _siegebreaker_skills() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"test_the_plate", "Test the Plate", "Remove up to 2 Armor, then deal 110% Power.",
			"One neighboring enemy.", "Requires contact.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY, true), [],
			[e.armor_stripping_damage(e.TargetRole.PRIMARY, 110, 2)]
		),
		_skill(
			&"crack_armor", "Crack Armor", "After Armor is lost, remove up to 3 more and deal 140% Power; with Advantage, remove up to 5.",
			"One active enemy.", "Target must have lost Armor this round.", 3,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_LOST_ARMOR_THIS_ROUND)],
			[e.armor_stripping_damage(e.TargetRole.PRIMARY, 140, 3, 5)]
		),
		_skill(
			&"demolishing_blow", "Demolishing Blow", "Deal 210% Power to a neighboring enemy, ignoring Armor.",
			"One neighboring enemy.", "Requires contact.", 5,
			_profile(1, 1, BattleUnitState.Side.ENEMY, true), [],
			[e.ignoring_armor_damage(e.TargetRole.PRIMARY, 210)]
		),
	]


static func _profile(minimum: int, maximum: int, side: int, adjacent: bool = false) -> RefCounted:
	var p: Script = load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return p.create(minimum, maximum, side, adjacent)


static func _skill(
	skill_id: StringName,
	title: String,
	effect_text: String,
	targeting_text: String,
	requirements_text: String,
	cooldown: int,
	profile: RefCounted,
	conditions: Array[RefCounted],
	effects: Array[RefCounted],
	requirement: int = CharacterSkill.Requirement.NONE
) -> CharacterSkill:
	return CharacterSkill.create(
		skill_id, title, CharacterSkill.Kind.ACTIVE, effect_text, targeting_text,
		requirements_text, "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE,
		requirement, CharacterSkill.Effect.NONE, 0, 0,
		CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		cooldown, 0, null, [], null, null, profile, conditions, effects
	)
