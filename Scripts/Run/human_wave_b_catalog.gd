class_name HumanWaveBCatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"human_field_medic",
	&"human_crosbowman",
	&"human_duelist",
]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"human_field_medic":
			return RunCharacter.new(class_id, "Field Medic", 6, 19, _medic(), 4, 2, &"human")
		&"human_crosbowman":
			return RunCharacter.new(class_id, "Crosbowman", 6, 20, _crossbowman(), 6, 2, &"human")
		&"human_duelist":
			return RunCharacter.new(class_id, "Duelist", 7, 21, _duelist(), 8, 1, &"human")
		_:
			return null


static func _medic() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"combat_patch", "Combat Patch",
			"An ally below 75% HP gains 4 Armor; below half HP, gain 6.",
			"One wounded ally.", "Target must be below 75% HP.", 1,
			_profile(1, 1, BattleUnitState.Side.PLAYER),
			[c.create(c.Kind.PRIMARY_BELOW_SEVENTY_FIVE_PERCENT_HP)], [
				e.conditional_armor(
					e.TargetRole.PRIMARY, 4, 6,
					e.BonusCondition.TARGET_BELOW_HALF_HP
				),
			]
		),
		_skill(
			&"guarded_recovery", "Guarded Recovery",
			"An Armored ally gains 3 Armor; existing protection upgrades this to 5.",
			"One Armored ally.", "Target must have Armor.", 2,
			_profile(1, 1, BattleUnitState.Side.PLAYER),
			[c.create(c.Kind.PRIMARY_HAS_ARMOR)], [
				e.conditional_armor(
					e.TargetRole.PRIMARY, 3, 5,
					e.BonusCondition.TARGET_HAS_ARMOR
				),
			]
		),
		_skill(
			&"hold_the_wound", "Hold the Wound",
			"Every active ally below half HP gains 4 Armor; if two or more are wounded, gain 6.",
			"All active wounded allies.", "Requires at least one wounded ally.", 5,
			_profile(0, 0, BattleUnitState.Side.PLAYER, false, true),
			[], [
				e.conditional_armor(
					e.TargetRole.ALL_ACTIVE_WOUNDED_ALLIES, 4, 6,
					e.BonusCondition.ALLIES_BELOW_HALF_AT_LEAST_TWO
				),
			]
		),
	]


static func _crossbowman() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"sightline_mark", "Sightline Mark",
			"Deal 80% Power and apply Advantage until round end.",
			"One active enemy.", "Requires an active enemy.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[], [
				e.damage(e.TargetRole.PRIMARY, 80),
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1),
			]
		),
		_skill(
			&"repeating_shot", "Repeating Shot",
			"Deal 140% Power to an Advantaged or Snared enemy; consume Advantage to deal 170%.",
			"One marked enemy.", "Requires Advantage or Snared.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [
				e.conditional_damage(
					e.TargetRole.PRIMARY, 140, 170,
					e.BonusCondition.PRIMARY_ADVANTAGE, true
				),
			]
		),
		_skill(
			&"commanding_volley", "Commanding Volley",
			"Choose up to two enemies; an Advantaged first target takes 180%, all others 120%.",
			"One or two active enemies.", "Requires at least one enemy.", 5,
			_profile(1, 2, BattleUnitState.Side.ENEMY),
			[], [
				e.conditional_damage(
					e.TargetRole.PRIMARY, 120, 180,
					e.BonusCondition.PRIMARY_ADVANTAGE
				),
				e.damage(e.TargetRole.SECONDARY, 120),
			]
		),
	]


static func _duelist() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"cut_the_distance", "Cut the Distance",
			"Move 2, then deal 100% Power; a target moved this round takes 130%.",
			"Self Move 2, then one neighboring enemy.", "Requires a legal path and contact.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY, true),
			[], [
				e.conditional_damage(
					e.TargetRole.PRIMARY, 100, 130,
					e.BonusCondition.MOVED_THIS_ROUND
				),
				e.self_move(2, 2),
			]
		),
		_skill(
			&"counterstep", "Counterstep",
			"Deal 140% Power to an enemy that hit you or an adjacent ally; marked targets take 170%.",
			"One qualifying enemy.", "Requires a direct hit this round.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_ATTACKED_ACTOR_OR_ADJACENT_ALLY_THIS_ROUND)], [
				e.conditional_damage(
					e.TargetRole.PRIMARY, 140, 170,
					e.BonusCondition.SNARED_OR_ADVANTAGE
				),
			]
		),
		_skill(
			&"final_verdict", "Final Verdict",
			"Deal 210% Power to an enemy below half HP; consume Advantage to deal 240%.",
			"One enemy below half HP.", "Target must be below half HP.", 5,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_BELOW_HALF_HP)], [
				e.conditional_damage(
					e.TargetRole.PRIMARY, 210, 240,
					e.BonusCondition.PRIMARY_ADVANTAGE, true
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
