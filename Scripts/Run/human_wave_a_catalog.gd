class_name HumanWaveACatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"human_vanguard",
	&"human_ranger",
	&"human_iron_sentinel",
]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"human_vanguard":
			return RunCharacter.new(class_id, "Vanguard", 5, 22, _vanguard(), 5, 3, &"human")
		&"human_ranger":
			return RunCharacter.new(class_id, "Ranger", 7, 18, _ranger(), 7, 1, &"human")
		&"human_iron_sentinel":
			return RunCharacter.new(class_id, "Iron Sentinel", 4, 25, _sentinel(), 4, 4, &"human")
		_:
			return null


static func _vanguard() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(
			&"commanding_step", "Commanding Step",
			"Move 1, then you and one neighboring ally gain 3 Armor.",
			"Self Move 1 and one neighboring ally.", "Requires a legal path and adjacent ally.", 1,
			_profile(1, 1, BattleUnitState.Side.PLAYER, true),
			[], [
				e.self_move(1),
				e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 3),
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 3),
			]
		),
		_skill(
			&"shielded_advance", "Shielded Advance",
			"Deal 115% Power; if you or a neighboring ally has Armor, deal 145%.",
			"One neighboring enemy.", "Requires contact.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY, true),
			[], [
				e.conditional_damage(
					e.TargetRole.PRIMARY, 115, 145,
					e.BonusCondition.ACTOR_OR_ADJACENT_ALLY_HAS_ARMOR
				),
			]
		),
		_skill(
			&"lineholders_verdict", "Lineholder's Verdict",
			"Deal 180% Power; if an ally acted before you this round, deal 210%.",
			"One active enemy.", "Requires allied sequencing for the bonus.", 5,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[], [
				e.conditional_damage(
					e.TargetRole.PRIMARY, 180, 210,
					e.BonusCondition.ALLY_ACTED_BEFORE_ACTOR_THIS_ROUND
				),
			]
		),
	]


static func _ranger() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"quick_draw", "Quick Draw",
			"Deal 90% Power and apply Snared until round end.",
			"One active enemy.", "Requires an active enemy.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[], [
				e.damage(e.TargetRole.PRIMARY, 90),
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1),
			]
		),
		_skill(
			&"pinning_volley", "Pinning Volley",
			"Deal 130% Power to a Snared enemy, then apply Advantage.",
			"One Snared enemy.", "Target must be Snared.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_SNARED)], [
				e.damage(e.TargetRole.PRIMARY, 130),
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1),
			]
		),
		_skill(
			&"break_the_angle", "Break the Angle",
			"Deal 170% Power to a Snared or Advantaged enemy; with both, consume Advantage and deal 210%.",
			"One marked enemy.", "Requires Snared or Advantage.", 4,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [
				e.conditional_damage(
					e.TargetRole.PRIMARY, 170, 210,
					e.BonusCondition.SNARED_AND_ADVANTAGE, true
				),
			]
		),
	]


static func _sentinel() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(
			&"brace_the_line", "Brace the Line",
			"You and one neighboring ally gain 4 Armor.",
			"Self and one neighboring ally.", "Requires an adjacent ally.", 1,
			_profile(1, 1, BattleUnitState.Side.PLAYER, true),
			[], [
				e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
			]
		),
		_skill(
			&"field_fortification", "Field Fortification",
			"Deal 100% Power; with at least 2 Armor, strip up to 2 Armor first.",
			"One neighboring enemy.", "Requires contact.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY, true),
			[], [
				e.armor_stripping_damage(
					e.TargetRole.PRIMARY, 100, 2, 0,
					e.BonusCondition.ACTOR_HAS_AT_LEAST_TWO_ARMOR
				),
			]
		),
		_skill(
			&"wall_of_steel", "Wall of Steel",
			"You and both neighboring allies gain 5 Armor; wounded targets gain 7.",
			"Self and two neighboring allies.", "Requires two adjacent allies.", 5,
			_profile(2, 2, BattleUnitState.Side.PLAYER, true),
			[], [
				e.conditional_armor(
					e.TargetRole.ACTOR, 5, 7,
					e.BonusCondition.TARGET_BELOW_HALF_HP
				),
				e.conditional_armor(
					e.TargetRole.ALL_SELECTED, 5, 7,
					e.BonusCondition.TARGET_BELOW_HALF_HP
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
