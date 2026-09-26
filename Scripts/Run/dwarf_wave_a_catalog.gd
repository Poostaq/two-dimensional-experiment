extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"dwarf_forgewarden":
			return _character(class_id, "Forgewarden", 3, 28, 5, 5, [&"iron_brace", &"runed_guard", &"unyielding_stone"])
		&"dwarf_siege_smith":
			return RunCharacter.new(class_id, "Siege Smith", 3, 26, _siege_smith(), 8, 3, &"dwarf")
		&"dwarf_rune_sentinel":
			return _character(class_id, "Rune Sentinel", 4, 27, 4, 4, [&"warded_step", &"rune_of_hold", &"living_plate"])
		_:
			return null


static func _character(id: StringName, name: String, speed: int, hp: int, power: int, defense: int, ids: Array[StringName]) -> RunCharacter:
	return RunCharacter.new(id, name, speed, hp, _skills(ids), power, defense, &"dwarf")


static func _siege_smith() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"test_the_plate", 1, e.armor_stripping_damage(e.TargetRole.PRIMARY, 110, 2)),
		_skill(&"hollow_core", 3, e.conditional_damage(e.TargetRole.PRIMARY, 150, 180, e.BonusCondition.LOST_THREE_ARMOR_THIS_ROUND)),
		_skill(&"breakers_verdict", 5, e.ignoring_armor_damage(e.TargetRole.PRIMARY, 210)),
	]


static func _skills(ids: Array[StringName]) -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var result: Array[CharacterSkill] = []
	for index: int in ids.size():
		result.append(_skill(ids[index], index + 1, e.damage(e.TargetRole.PRIMARY, 80 + index * 40)))
	return result


static func _skill(id: StringName, cooldown: int, effect: RefCounted) -> CharacterSkill:
	var p := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = p.create(1, 1, BattleUnitState.Side.ENEMY)
	return CharacterSkill.create(id, String(id).replace("_", " ").capitalize(), CharacterSkill.Kind.ACTIVE, String(id), "Authored target.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], [effect])
