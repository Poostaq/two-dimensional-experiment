class_name DwarfWaveBCatalog
extends RefCounted

const IDS: Array[StringName] = [&"dwarf_quarrel_engineer", &"dwarf_hearthkeeper", &"dwarf_thunderbreaker"]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"dwarf_quarrel_engineer":
			return RunCharacter.new(class_id, "Quarrel Engineer", 4, 24, _engineer(), 6, 3, &"dwarf")
		&"dwarf_hearthkeeper":
			return RunCharacter.new(class_id, "Hearthkeeper", 4, 23, _keeper(), 4, 3, &"dwarf")
		&"dwarf_thunderbreaker":
			return RunCharacter.new(class_id, "Thunderbreaker", 2, 25, _breaker(), 8, 3, &"dwarf")
		_:
			return null


static func _engineer() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"shot_lock", "Shot-Lock", "Deal 85% Power and apply Snared.", "One enemy.", "Requires an active enemy.", 1, _profile(1, 1, BattleUnitState.Side.ENEMY), [], [
			e.damage(e.TargetRole.PRIMARY, 85),
			e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1),
		]),
		_skill(&"hammered_line", "Hammered Line", "Deal 130% Power to a Snared enemy; moved targets take 160%.", "One Snared enemy.", "Target must be Snared.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_SNARED)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 130, 160, e.BonusCondition.MOVED_THIS_ROUND),
		]),
		_skill(&"explosive_refit", "Explosive Refit", "Primary takes 180%; secondary takes 100%, or 120% when primary is Snared.", "One or two enemies.", "Requires at least one enemy.", 5, _profile(1, 2, BattleUnitState.Side.ENEMY), [], [
			e.damage(e.TargetRole.PRIMARY, 180),
			e.conditional_damage(e.TargetRole.SECONDARY, 100, 120, e.BonusCondition.PRIMARY_SELECTED_SNARED),
		]),
	]


static func _keeper() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"hearth_reset", "Hearth Reset", "An ally below 75% HP gains 4 Armor; below half HP, gain 6.", "One wounded ally.", "Target must be below 75% HP.", 1, _profile(1, 1, BattleUnitState.Side.PLAYER), [c.create(c.Kind.PRIMARY_BELOW_SEVENTY_FIVE_PERCENT_HP)], [
			e.conditional_armor(e.TargetRole.PRIMARY, 4, 6, e.BonusCondition.TARGET_BELOW_HALF_HP),
		]),
		_skill(&"warm_the_line", "Warm the Line", "You and neighboring allies gain 3 Armor; wounded targets gain 5.", "Self and one or two neighboring allies.", "Requires a neighboring ally.", 2, _profile(1, 2, BattleUnitState.Side.PLAYER, true), [], [
			e.conditional_armor(e.TargetRole.ACTOR, 3, 5, e.BonusCondition.TARGET_BELOW_HALF_HP),
			e.conditional_armor(e.TargetRole.ALL_SELECTED, 3, 5, e.BonusCondition.TARGET_BELOW_HALF_HP),
		]),
		_skill(&"shared_forge", "Shared Forge", "All allies gain 4 Armor; if two or more are wounded, gain 6.", "All active allies.", "Requires an active ally.", 5, _profile(0, 0, BattleUnitState.Side.PLAYER, false, true), [], [
			e.conditional_armor(e.TargetRole.ALL_ACTIVE_ALLIES, 4, 6, e.BonusCondition.ALLIES_BELOW_HALF_AT_LEAST_TWO),
		]),
	]


static func _breaker() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"weight_of_the_hammer", "Weight of the Hammer", "Strip up to 2 Armor, then deal 100% Power.", "One neighboring enemy.", "Requires contact.", 1, _profile(1, 1, BattleUnitState.Side.ENEMY, true), [], [
			e.armor_stripping_damage(e.TargetRole.PRIMARY, 100, 2),
		]),
		_skill(&"cracked_foundation", "Cracked Foundation", "Deal 160% Power to an enemy that lost Armor; 190% after losing at least 3.", "One qualifying enemy.", "Requires Armor loss this round.", 3, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_LOST_ARMOR_THIS_ROUND)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 160, 190, e.BonusCondition.LOST_THREE_ARMOR_THIS_ROUND),
		]),
		_skill(&"thunderfall_decision", "Thunderfall Decision", "Deal 220% Power ignoring Armor; targets that lost Armor take 250%.", "One neighboring enemy.", "Requires contact.", 5, _profile(1, 1, BattleUnitState.Side.ENEMY, true), [], [
			e.conditional_damage(e.TargetRole.PRIMARY, 220, 250, e.BonusCondition.LOST_ARMOR_THIS_ROUND, false, true),
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
