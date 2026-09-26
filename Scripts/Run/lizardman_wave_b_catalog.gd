class_name LizardmanWaveBCatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"lizardman_fang_alchemist",
	&"lizardman_reed_ambusher",
	&"lizardman_sunscale_warder",
]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"lizardman_fang_alchemist":
			return RunCharacter.new(class_id, "Fang Alchemist", 5, 21, _fang_alchemist(), 6, 2, &"lizardman")
		&"lizardman_reed_ambusher":
			return RunCharacter.new(class_id, "Reed Ambusher", 6, 19, _reed_ambusher(), 7, 1, &"lizardman")
		&"lizardman_sunscale_warder":
			return RunCharacter.new(class_id, "Sunscale Warder", 4, 24, _sunscale_warder(), 4, 3, &"lizardman")
		_:
			return null


static func _fang_alchemist() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"corrosive_dose", "Corrosive Dose",
			"Deal 70% Power and apply 1 Defense Poison for 3 rounds.",
			"One active enemy.", "Requires an active enemy.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[], [
				e.damage(e.TargetRole.PRIMARY, 70),
				e.poison(e.TargetRole.PRIMARY, &"defense", 1, 3),
			]
		),
		_skill(
			&"catalyze", "Catalyze",
			"Deal 80% Power, +20% per Poison stack (max 160%).",
			"One enemy with any Poison.", "Requires at least one Poison stack.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_HAS_ANY_POISON)], [
				e.poison_scaled_damage(e.TargetRole.PRIMARY, 80, 20, 160, &"", false, 20),
			]
		),
		_skill(
			&"antidote_exchange", "Antidote Exchange",
			"Move one Poison source from an ally to an enemy, preserving its axis and duration.",
			"One poisoned ally, then one enemy.", "Requires a live Poison source.", 4,
			_profile(
				2, 2, BattleUnitState.Side.PLAYER, false, false,
				[BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY]
			),
			[], [e.poison_transfer()]
		),
	]


static func _reed_ambusher() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"stillwater_focus", "Stillwater Focus",
			"If you have not moved this round, gain Advantage.",
			"Self.", "Requires no movement this round.", 1,
			_profile(0, 0, BattleUnitState.Side.PLAYER, false, true),
			[c.create(c.Kind.ACTOR_NOT_MOVED_THIS_ROUND)], [
				e.keyword(
					e.TargetRole.ACTOR,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
		_skill(
			&"sudden_lunge", "Sudden Lunge",
			"Move up to 3 and deal 160% Power to a neighboring enemy.",
			"Self Move 1-3, then one enemy.", "Requires a legal path and target.", 3,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[], [
				e.damage(e.TargetRole.PRIMARY, 160, 190),
				e.self_move(3, 1),
			]
		),
		_skill(
			&"vanish_into_reeds", "Vanish into Reeds",
			"Move up to 2 and gain 4 Armor.",
			"Self Move 1-2.", "Requires a legal movement path.", 3,
			_profile(0, 0, BattleUnitState.Side.PLAYER, false, true),
			[], [
				e.self_move(2, 1),
				e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
			]
		),
	]


static func _sunscale_warder() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"warming_armor", "Warming Armor",
			"A neighboring ally gains 4 Armor.",
			"One neighboring ally.", "Requires a legal adjacent ally.", 1,
			_profile(1, 1, BattleUnitState.Side.PLAYER, true),
			[], [
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
			]
		),
		_skill(
			&"reflecting_scale", "Reflecting Scale",
			"Spend up to 3 Armor to deal 50% Power per point to an enemy.",
			"One active enemy.", "Requires at least 1 Armor.", 3,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.ACTOR_HAS_ARMOR)], [
				e.armor_spend_damage(e.TargetRole.PRIMARY, 50, 3),
			]
		),
		_skill(
			&"solar_bulwark", "Solar Bulwark",
			"All active allies gain 4 Armor.",
			"Two to six active allies.", "Requires at least two legal allies.", 5,
			_profile(2, 6, BattleUnitState.Side.PLAYER),
			[], [
				e.keyword(
					e.TargetRole.ALL_SELECTED,
					BattleKeywordOperation.Kind.ADD_ARMOR,
					4
				),
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
