class_name LizardmanWaveACatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"lizardman_venom_saurian",
	&"lizardman_scale_sentinel",
	&"lizardman_mire_spitter",
]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"lizardman_venom_saurian":
			return RunCharacter.new(class_id, "Venom Saurian", 5, 20, _venom_saurian(), 7, 1, &"lizardman")
		&"lizardman_scale_sentinel":
			return RunCharacter.new(class_id, "Scale Sentinel", 3, 26, _scale_sentinel(), 4, 3, &"lizardman")
		&"lizardman_mire_spitter":
			return RunCharacter.new(class_id, "Mire Spitter", 6, 18, _mire_spitter(), 5, 1, &"lizardman")
		_:
			return null


static func _venom_saurian() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"weakening_bite", "Weakening Bite",
			"Deal 80% Power and apply 1 Power Poison for 3 rounds.",
			"One active enemy.", "Requires an active enemy.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[], [
				e.damage(e.TargetRole.PRIMARY, 80),
				e.poison(e.TargetRole.PRIMARY, &"power", 1, 3),
			]
		),
		_skill(
			&"venom_pulse", "Venom Pulse",
			"Deal 100% Power and add 1 stack to your Power Poison.",
			"One enemy with your Power Poison.", "Requires your Power Poison.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_POWER_POISON_FROM_ACTOR)], [
				e.damage(e.TargetRole.PRIMARY, 100),
				e.poison(e.TargetRole.PRIMARY, &"power", 1, 3, &"weakening_bite"),
			]
		),
		_skill(
			&"cold_finish", "Cold Finish",
			"Deal 120% Power, +20% per Power Poison stack (max 180%).",
			"One enemy with your Power Poison.", "Requires your Power Poison.", 4,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_POWER_POISON_FROM_ACTOR)], [
				e.poison_scaled_damage(
					e.TargetRole.PRIMARY, 120, 20, 180, &"power", true, 20,
					&"weakening_bite"
				),
			]
		),
	]


static func _scale_sentinel() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"brace_scales", "Brace Scales", "Gain 5 Armor.",
			"Self.", "Requires Armor capacity.", 1,
			_profile(0, 0, BattleUnitState.Side.PLAYER, false, true),
			[], [e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 5)]
		),
		_skill(
			&"tail_check", "Tail Check",
			"Deal 90% Power and move a neighbor 1; with Advantage, deal 120%.",
			"One neighboring enemy.", "Requires a legal Move 1 path.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY, true),
			[], [
				e.damage(e.TargetRole.PRIMARY, 90, 120),
				e.forced_target_move(e.TargetRole.PRIMARY, 1),
			]
		),
		_skill(
			&"layered_scales", "Layered Scales", "Gain 8 Armor.",
			"Self.", "Requires 2 Armor or less.", 4,
			_profile(0, 0, BattleUnitState.Side.PLAYER, false, true),
			[c.create(c.Kind.ACTOR_ARMOR_AT_MOST_TWO)],
			[e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 8)]
		),
	]


static func _mire_spitter() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"slowing_spit", "Slowing Spit",
			"Deal 70% Power and apply 1 Speed Poison for 3 rounds.",
			"One active enemy.", "Requires an active enemy.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[], [
				e.damage(e.TargetRole.PRIMARY, 70),
				e.poison(e.TargetRole.PRIMARY, &"speed", 1, 3),
			]
		),
		_skill(
			&"bog_down", "Bog Down",
			"Add 1 Speed Poison stack and move the target 1.",
			"One enemy with your Speed Poison.", "Requires your Poison and a legal path.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_SPEED_POISON_FROM_ACTOR)], [
				e.poison(e.TargetRole.PRIMARY, &"speed", 1, 3, &"slowing_spit"),
				e.forced_target_move(e.TargetRole.PRIMARY, 1),
			]
		),
		_skill(
			&"saturate_ground", "Saturate Ground",
			"Apply 1 Speed Poison to up to three enemies for 3 rounds.",
			"Two or three active enemies.", "Requires at least two legal targets.", 4,
			_profile(2, 3, BattleUnitState.Side.ENEMY),
			[], [e.poison(e.TargetRole.ALL_SELECTED, &"speed", 1, 3)]
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
