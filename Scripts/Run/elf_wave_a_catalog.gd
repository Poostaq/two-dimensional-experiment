class_name ElfWaveACatalog
extends RefCounted

const IDS: Array[StringName] = [&"elf_star_archer", &"elf_moon_sage", &"elf_wind_dancer"]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"elf_star_archer":
			return RunCharacter.new(class_id, "Star Archer", 8, 16, _star_archer(), 7, 1, &"elf")
		&"elf_moon_sage":
			return RunCharacter.new(class_id, "Moon Sage", 7, 15, _moon_sage(), 7, 0, &"elf")
		&"elf_wind_dancer":
			return RunCharacter.new(class_id, "Wind Dancer", 9, 14, _wind_dancer(), 6, 0, &"elf")
		_:
			return null


static func _star_archer() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"threaded_aim", "Threaded Aim", "Deal 90% Power and apply Advantage.", "One enemy.", "Requires an active enemy.", 1, _profile(1, 1, BattleUnitState.Side.ENEMY), [], [
			e.damage(e.TargetRole.PRIMARY, 90),
			e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1),
		]),
		_skill(&"needle_shot", "Needle Shot", "Deal 140% Power to an Advantaged enemy; moved targets take 170%.", "One Advantaged enemy.", "Target must have Advantage.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_ADVANTAGE)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 140, 170, e.BonusCondition.MOVED_THIS_ROUND),
		]),
		_skill(&"horizon_pierce", "Horizon Pierce", "Deal 200% Power to a marked enemy; consume Advantage to deal 230%.", "One Advantaged or Snared enemy.", "Requires Advantage or Snared.", 5, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 200, 230, e.BonusCondition.PRIMARY_ADVANTAGE, true),
		]),
	]


static func _moon_sage() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"silver_sigil", "Silver Sigil", "Deal 70% Power and apply Snared.", "One enemy.", "Requires an active enemy.", 1, _profile(1, 1, BattleUnitState.Side.ENEMY), [], [
			e.damage(e.TargetRole.PRIMARY, 70),
			e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1),
		]),
		_skill(&"lunar_thread", "Lunar Thread", "Deal 120% Power to a Snared enemy; moved targets take 150%.", "One Snared enemy.", "Target must be Snared.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_SNARED)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 120, 150, e.BonusCondition.MOVED_THIS_ROUND),
		]),
		_skill(&"crescent_collapse", "Crescent Collapse", "Deal 210% Power to a marked enemy; with Snared and Advantage, consume Advantage and deal 240%.", "One marked enemy.", "Requires Snared or Advantage.", 5, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 210, 240, e.BonusCondition.SNARED_AND_ADVANTAGE, true),
		]),
	]


static func _wind_dancer() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"step_through_wind", "Step Through Wind", "Move 2 and gain 2 Armor.", "Self Move 2.", "Requires a legal path.", 1, _profile(0, 0, BattleUnitState.Side.PLAYER, false, true), [], [
			e.self_move(2, 2),
			e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 2),
		]),
		_skill(&"arc_of_escape", "Arc of Escape", "Deal 120% Power to an enemy moved this round; with Advantage, deal 150%.", "One moved enemy.", "Requires prior movement.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)], [
			e.damage(e.TargetRole.PRIMARY, 120, 150),
		]),
		_skill(&"spiral_opening", "Spiral Opening", "Move 3, then deal 170% Power; crossing an occupied slot applies Snared.", "Self Move 3, then one neighboring enemy.", "Requires a legal path and contact.", 5, _profile(1, 1, BattleUnitState.Side.ENEMY, true), [], [
			e.self_move(3, 3),
			e.damage(e.TargetRole.PRIMARY, 170),
			e.conditional_keyword(
				e.TargetRole.PRIMARY,
				BattleKeywordOperation.Kind.APPLY_SNARED,
				0,
				1,
				e.BonusCondition.DECLARED_PATH_CROSSES_OCCUPIED_SLOT
			),
		]),
	]


static func _profile(minimum: int, maximum: int, side: int, adjacent: bool = false, allows_movement: bool = false) -> RefCounted:
	var p: Script = load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return p.create(minimum, maximum, side, adjacent, allows_movement)


static func _skill(skill_id: StringName, title: String, effect_text: String, targeting_text: String, requirements_text: String, cooldown: int, profile: RefCounted, conditions: Array[RefCounted], effects: Array[RefCounted]) -> CharacterSkill:
	return CharacterSkill.create(
		skill_id, title, CharacterSkill.Kind.ACTIVE, effect_text, targeting_text,
		requirements_text, "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0,
		CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		cooldown, 0, null, [], null, null, profile, conditions, effects
	)
