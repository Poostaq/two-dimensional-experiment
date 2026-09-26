class_name HarpyWaveBCatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"harpy_skyhook_raider",
	&"harpy_nestguard",
	&"harpy_carrion_cantor",
]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"harpy_skyhook_raider":
			return RunCharacter.new(class_id, "Skyhook Raider", 8, 18, _raider(), 7, 1, &"harpy")
		&"harpy_nestguard":
			return RunCharacter.new(class_id, "Nestguard", 7, 20, _nestguard(), 5, 1, &"harpy")
		&"harpy_carrion_cantor":
			return RunCharacter.new(class_id, "Carrion Cantor", 9, 16, _cantor(), 7, 0, &"harpy")
		_:
			return null


static func _raider() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"hook_and_lift", "Hook and Lift",
			"Force an enemy to move 2, then grant the selected ally Advantage.",
			"One enemy, then one ally.", "Requires a legal enemy Move 2 path.", 2,
			_profile(
				2, 2, BattleUnitState.Side.ENEMY, false, true,
				[BattleUnitState.Side.ENEMY, BattleUnitState.Side.PLAYER]
			),
			[], [
				e.forced_target_move(e.TargetRole.PRIMARY, 2),
				e.keyword(
					e.TargetRole.SECONDARY,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
		_skill(
			&"drop_out_of_line", "Drop Out of Line",
			"Deal 160% Power to an enemy moved at least 2 this round; with Advantage, deal 190%.",
			"One enemy moved at least 2 this round.", "Requires cumulative Move 2 or more.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_MOVED_TWO_OR_MORE_THIS_ROUND)], [
				e.damage(e.TargetRole.PRIMARY, 160, 190),
			]
		),
		_skill(
			&"snatch_away", "Snatch Away",
			"Force an enemy to move 3.",
			"One active enemy.", "Requires a legal enemy Move 3 path.", 5,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[], [e.forced_target_move(e.TargetRole.PRIMARY, 3)]
		),
	]


static func _nestguard() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"covering_wings", "Covering Wings",
			"Grant a neighboring ally 4 Armor.",
			"One neighboring active ally.", "Requires adjacency.", 1,
			_profile(1, 1, BattleUnitState.Side.PLAYER, true),
			[], [e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4)]
		),
		_skill(
			&"warning_screech", "Warning Screech",
			"Deal 130% Power to an enemy that hit an Armored ally this round; with Advantage, deal 160%.",
			"One qualifying enemy.", "Enemy must have hit an Armored ally.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_ATTACKED_ARMORED_ALLY_THIS_ROUND)], [
				e.damage(e.TargetRole.PRIMARY, 130, 160),
			]
		),
		_skill(
			&"rescue_flight", "Rescue Flight",
			"Swap with any ally; both units gain 3 Armor.",
			"Self and one ally.", "Requires a legal path ending at the ally.", 4,
			_profile(1, 1, BattleUnitState.Side.PLAYER, false, true),
			[], [
				e.self_move(3, 1),
				e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 3),
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 3),
			]
		),
	]


static func _cantor() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"cutting_note", "Cutting Note",
			"Deal 90% Power and force the enemy to move 1.",
			"One active enemy.", "Requires a legal enemy Move 1 path.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[], [
				e.damage(e.TargetRole.PRIMARY, 90),
				e.forced_target_move(e.TargetRole.PRIMARY, 1),
			]
		),
		_skill(
			&"rending_chorus", "Rending Chorus",
			"Deal 110% Power to an enemy moved this round and apply Bleed for 2 actions.",
			"One enemy moved this round.", "Requires prior movement.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)], [
				e.damage(e.TargetRole.PRIMARY, 110),
				e.keyword(
					e.TargetRole.PRIMARY,
					BattleKeywordOperation.Kind.APPLY_BLEED,
					0,
					2
				),
			]
		),
		_skill(
			&"funeral_spiral", "Funeral Spiral",
			"Move up to 3 and deal 80% Power to up to two selected Bleeding enemies.",
			"Self Move 0-3, then one or two Bleeding enemies.", "Primary target must be Bleeding.", 5,
			_profile(1, 2, BattleUnitState.Side.ENEMY, false, true),
			[c.create(c.Kind.PRIMARY_BLEEDING)], [
				e.damage(e.TargetRole.ALL_SELECTED, 80),
				e.optional_self_move(3),
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
