class_name ElfWaveBCatalog
extends RefCounted

const IDS: Array[StringName] = [&"elf_warden_of_the_grove", &"elf_crescent_duelist", &"elf_highborn_mystic"]


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"elf_warden_of_the_grove":
			return RunCharacter.new(class_id, "Warden of the Grove", 6, 18, _warden(), 4, 2, &"elf")
		&"elf_crescent_duelist":
			return RunCharacter.new(class_id, "Crescent Duelist", 8, 17, _duelist(), 7, 1, &"elf")
		&"elf_highborn_mystic":
			return RunCharacter.new(class_id, "Highborn Mystic", 7, 16, _mystic(), 8, 0, &"elf")
		_:
			return null


static func _warden() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"rooting_ward", "Rooting Ward", "Grant an ally 4 Armor; a selected adjacent enemy gains Snared.", "One ally and optionally one enemy.", "The enemy must be adjacent to the ally.", 1, _profile(1, 2, BattleUnitState.Side.PLAYER, false, false, [BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY]), [], [
			e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4),
			e.conditional_keyword(e.TargetRole.SECONDARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1, e.BonusCondition.PRIMARY_AND_SECONDARY_ADJACENT),
		]),
		_skill(&"calm_the_ring", "Calm the Ring", "Deal 90% Power to an enemy moved this round and force Move 1; with Advantage, deal 120%.", "One moved enemy.", "Requires prior movement and a legal path.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY, false, true), [c.create(c.Kind.PRIMARY_MOVED_THIS_ROUND)], [
			e.damage(e.TargetRole.PRIMARY, 90, 120),
			e.forced_target_move(e.TargetRole.PRIMARY, 1),
		]),
		_skill(&"dawnglass_barrier", "Dawnglass Barrier", "All active allies gain 4 Armor; if two or more are wounded, gain 6.", "All active allies.", "Requires an active ally.", 5, _profile(0, 0, BattleUnitState.Side.PLAYER, false, true), [], [
			e.conditional_armor(e.TargetRole.ALL_ACTIVE_ALLIES, 4, 6, e.BonusCondition.ALLIES_BELOW_HALF_AT_LEAST_TWO),
		]),
	]


static func _duelist() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"cut_the_angle", "Cut the Angle", "Move 2, then deal 100% Power; moved targets take 130%.", "Self Move 2, then one neighboring enemy.", "Requires a legal path and contact.", 1, _profile(1, 1, BattleUnitState.Side.ENEMY, true), [], [
			e.conditional_damage(e.TargetRole.PRIMARY, 100, 130, e.BonusCondition.MOVED_THIS_ROUND),
			e.self_move(2, 2),
		]),
		_skill(&"short_arc", "Short Arc", "Deal 150% Power to a marked enemy; if you moved this round, deal 180% and gain 2 Armor.", "One Advantaged or Snared enemy.", "Requires Advantage or Snared.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 150, 180, e.BonusCondition.ACTOR_MOVED_THIS_ROUND),
			e.conditional_armor(e.TargetRole.ACTOR, 0, 2, e.BonusCondition.ACTOR_MOVED_THIS_ROUND),
		]),
		_skill(&"final_flourish", "Final Flourish", "Deal 210% Power to an enemy below half HP; consume Advantage to deal 240%.", "One enemy below half HP.", "Target must be below half HP.", 5, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_BELOW_HALF_HP)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 210, 240, e.BonusCondition.PRIMARY_ADVANTAGE, true),
		]),
	]


static func _mystic() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(&"glyph_of_silence", "Glyph of Silence", "Deal 70% Power and apply Snared.", "One enemy.", "Requires an active enemy.", 1, _profile(1, 1, BattleUnitState.Side.ENEMY), [], [
			e.damage(e.TargetRole.PRIMARY, 70),
			e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1),
		]),
		_skill(&"echoed_star", "Echoed Star", "Deal 130% Power to a Snared enemy; with Advantage, deal 160%.", "One Snared enemy.", "Target must be Snared.", 2, _profile(1, 1, BattleUnitState.Side.ENEMY), [c.create(c.Kind.PRIMARY_SNARED)], [
			e.damage(e.TargetRole.PRIMARY, 130, 160),
		]),
		_skill(&"final_constellation", "Final Constellation", "Choose up to two enemies; primary takes 190%, or 230% if both are Snared; secondary takes 120%.", "One or two enemies, at least one Snared.", "At least one selected target must be Snared.", 5, _profile(1, 2, BattleUnitState.Side.ENEMY), [c.create(c.Kind.ANY_SELECTED_SNARED)], [
			e.conditional_damage(e.TargetRole.PRIMARY, 190, 230, e.BonusCondition.ALL_SELECTED_SNARED),
			e.damage(e.TargetRole.SECONDARY, 120),
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
