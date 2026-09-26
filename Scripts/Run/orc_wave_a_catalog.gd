class_name OrcWaveACatalog
extends RefCounted

const IDS: Array[StringName] = [&"orc_iron_tusk_vanguard", &"orc_bonebreaker_reaver", &"orc_bloodbanner_captain"]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"orc_iron_tusk_vanguard":
			return RunCharacter.new(class_id, "Iron Tusk Vanguard", 2, 30, _iron_tusk_skills(), 5, 5, &"orc")
		&"orc_bonebreaker_reaver":
			return RunCharacter.new(class_id, "Bonebreaker Reaver", 4, 26, _bonebreaker_skills(), 8, 2, &"orc")
		&"orc_bloodbanner_captain":
			return RunCharacter.new(class_id, "Bloodbanner Captain", 3, 28, _bloodbanner_skills(), 5, 4, &"orc")
		_:
			return null


static func _iron_tusk_skills() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(
			&"brace_line", "Brace Line", "You and a neighboring ally each gain 4 Armor.",
			"One active adjacent ally.", "Requires a legal adjacent ally.", 1,
			_profile(1, 1, BattleUnitState.Side.PLAYER, true),
			[], [e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 4), e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4)]
		),
		_skill(
			&"shield_ram", "Shield Ram", "Deal 100% Power and move an enemy 1; with Advantage, deal 140%.",
			"One neighboring enemy.", "Requires a legal Move 1 path.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY, true),
			[], [e.damage(e.TargetRole.PRIMARY, 100, 140), e.forced_target_move(e.TargetRole.PRIMARY, 1)]
		),
		_skill(
			&"hold_the_gap", "Hold the Gap", "You and both neighboring allies each gain 5 Armor.",
			"Two active adjacent allies.", "Requires both neighboring allies.", 4,
			_profile(2, 2, BattleUnitState.Side.PLAYER, true),
			[], [e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 5), e.keyword(e.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 5)]
		),
	]


static func _bonebreaker_skills() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"crushing_entry", "Crushing Entry", "Deal 100% Power and move a neighboring enemy 1.",
			"One neighboring enemy.", "Requires a legal Move 1 path.", 1,
			_profile(1, 1, BattleUnitState.Side.ENEMY, true),
			[], [e.damage(e.TargetRole.PRIMARY, 100), e.forced_target_move(e.TargetRole.PRIMARY, 1)]
		),
		_skill(
			&"break_formation", "Break Formation", "Deal 150% Power to an enemy moved or Stunned this round; with Advantage, deal 180%.",
			"One active enemy.", "Target must have moved or be Stunned this round.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_MOVED_OR_STUNNED_THIS_ROUND)],
			[e.damage(e.TargetRole.PRIMARY, 150, 180)]
		),
		_skill(
			&"execution_swing", "Execution Swing", "From the front, deal 200% Power to an enemy below half HP, ignoring Armor.",
			"One active enemy.", "Front row; target below half HP.", 4,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_BELOW_HALF_HP)],
			[e.ignoring_armor_damage(e.TargetRole.PRIMARY, 200)],
			CharacterSkill.Requirement.FRONT_ROW
		),
	]


static func _bloodbanner_skills() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"plant_banner", "Plant Banner", "You and neighboring allies each gain 3 Armor.",
			"One or two active adjacent allies.", "Requires an ally able to gain Armor.", 2,
			_profile(1, 2, BattleUnitState.Side.PLAYER, true),
			[], [e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 3), e.keyword(e.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 3)]
		),
		_skill(
			&"rally_strike", "Rally Strike", "Deal 90% Power and grant an ally 3 Armor; with Advantage, grant 5.",
			"One enemy, then one ally.", "Requires both legal targets.", 2,
			_profile(2, 2, BattleUnitState.Side.ENEMY, false, [BattleUnitState.Side.ENEMY, BattleUnitState.Side.PLAYER]),
			[], [e.damage(e.TargetRole.PRIMARY, 90), e.conditional_armor(e.TargetRole.SECONDARY, 3, 5, e.BonusCondition.PRIMARY_ADVANTAGE)]
		),
		_skill(
			&"last_standard", "Last Standard", "If two allies are below half HP, all allies gain 5 Armor.",
			"All selected active allies.", "Requires two allies below half HP.", 5,
			_profile(1, 6, BattleUnitState.Side.PLAYER),
			[c.create(c.Kind.ALLIES_BELOW_HALF_AT_LEAST_TWO)],
			[e.keyword(e.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 5)]
		),
	]


static func _profile(
	minimum: int,
	maximum: int,
	side: int,
	adjacent: bool = false,
	ordered_sides: Array[int] = []
) -> RefCounted:
	var p: Script = load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return p.create(minimum, maximum, side, adjacent, false, ordered_sides)


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
