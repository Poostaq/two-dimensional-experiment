class_name DwarfWaveACatalog
extends RefCounted

const IDS: Array[StringName] = [&"dwarf_forgewarden", &"dwarf_siege_smith", &"dwarf_rune_sentinel"]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"dwarf_forgewarden":
			return RunCharacter.new(class_id, "Forgewarden", 3, 28, _forgewarden(), 5, 5, &"dwarf")
		&"dwarf_siege_smith":
			return RunCharacter.new(class_id, "Siege Smith", 3, 26, _smith(), 8, 3, &"dwarf")
		&"dwarf_rune_sentinel":
			return RunCharacter.new(class_id, "Rune Sentinel", 4, 27, _sentinel(), 4, 4, &"dwarf")
		_:
			return null


static func _forgewarden() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"iron_brace", "Iron Brace", "You and one neighboring ally gain 4 Armor.", "Self and one neighboring ally.", "Requires an adjacent ally.", 1, _profile(1, 1, BattleUnitState.Side.PLAYER, true), [], [
			e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
			e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
		]),
		_skill(&"runed_guard", "Runed Guard", "Deal 90% Power; with Armor, you and one neighboring ally gain 2 Armor.", "One neighboring enemy, then one neighboring ally.", "Requires both targets.", 2, _profile(2, 2, BattleUnitState.Side.ENEMY, true, false, [BattleUnitState.Side.ENEMY, BattleUnitState.Side.PLAYER]), [], [
			e.damage(e.TargetRole.PRIMARY, 90),
			e.conditional_armor(e.TargetRole.ACTOR, 0, 2, e.BonusCondition.ACTOR_HAS_ARMOR),
			e.conditional_armor(e.TargetRole.SECONDARY, 0, 2, e.BonusCondition.ACTOR_HAS_ARMOR),
		]),
		_skill(&"unyielding_stone", "Unyielding Stone", "You and both neighboring allies gain 5 Armor; wounded targets gain 7.", "Self and two neighboring allies.", "Requires two adjacent allies.", 5, _profile(2, 2, BattleUnitState.Side.PLAYER, true), [], [
			e.conditional_armor(e.TargetRole.ACTOR, 5, 7, e.BonusCondition.TARGET_BELOW_HALF_HP),
			e.conditional_armor(e.TargetRole.ALL_SELECTED, 5, 7, e.BonusCondition.TARGET_BELOW_HALF_HP),
		]),
	]


static func _smith() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"test_the_plate", "Test the Plate", "Strip up to 2 Armor, then deal 110% Power.", "One neighboring enemy.", "Requires contact.", 1, _profile(1, 1, BattleUnitState.Side.ENEMY, true), [], [
			e.armor_stripping_damage(e.TargetRole.PRIMARY, 110, 2),
		]),
		_skill(&"hollow_core", "Hollow Core", "Deal 150% Power to an enemy that lost Armor; 180% after losing at least 3.", "One qualifying enemy.", "Requires Armor loss this round.", 3, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_LOST_ARMOR_THIS_ROUND)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 150, 180, e.BonusCondition.LOST_THREE_ARMOR_THIS_ROUND),
		]),
		_skill(&"breakers_verdict", "Breaker's Verdict", "Deal 210% Power ignoring Armor; unarmored targets take 240%.", "One neighboring enemy.", "Requires contact.", 5, _profile(1, 1, BattleUnitState.Side.ENEMY, true), [], [
			e.conditional_damage(e.TargetRole.PRIMARY, 210, 240, e.BonusCondition.NO_ARMOR, false, true),
		]),
	]


static func _sentinel() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"warded_step", "Warded Step", "Move self or one ally 1, then grant 3 Armor.", "Self or one ally.", "Requires a legal Move 1 path.", 1, _profile(1, 1, BattleUnitState.Side.PLAYER, false, true), [], [
			e.forced_target_move(e.TargetRole.PRIMARY, 1),
			e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 3),
		]),
		_skill(&"rune_of_hold", "Rune of Hold", "Deal 100% Power to an enemy moved this round and apply Snared.", "One moved enemy.", "Requires prior movement.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)], [
			e.damage(e.TargetRole.PRIMARY, 100),
			e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1),
		]),
		_skill(&"living_plate", "Living Plate", "All allies gain 4 Armor; with 3 Armor, the most injured ally gains 2 more.", "All active allies.", "Requires an active ally.", 5, _profile(0, 0, BattleUnitState.Side.PLAYER, false, true), [], [
			e.keyword(e.TargetRole.ALL_ACTIVE_ALLIES, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
			e.conditional_armor(e.TargetRole.MOST_INJURED_ACTIVE_ALLY, 0, 2, e.BonusCondition.ACTOR_HAS_AT_LEAST_THREE_ARMOR),
		]),
	]


static func _profile(minimum: int, maximum: int, side: int, adjacent: bool = false, allows_movement: bool = false, ordered_sides: Array[int] = []) -> RefCounted:
	var p: Script = load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return p.create(minimum, maximum, side, adjacent, allows_movement, ordered_sides)


static func _skill(skill_id: StringName, title: String, effect_text: String, targeting_text: String, requirements_text: String, cooldown: int, profile: RefCounted, conditions: Array[RefCounted], effects: Array[RefCounted]) -> CharacterSkill:
	return CharacterSkill.create(
		skill_id, title, CharacterSkill.Kind.ACTIVE, effect_text, targeting_text,
		requirements_text, "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0,
		CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		cooldown, 0, null, [], null, null, profile, conditions, effects
	)
