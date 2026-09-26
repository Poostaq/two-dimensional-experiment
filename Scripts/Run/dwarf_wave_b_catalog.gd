extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"dwarf_quarrel_engineer":
			return _character(class_id, "Quarrel Engineer", 4, 24, 6, 3, [&"shot_lock", &"hammered_line", &"explosive_refit"])
		&"dwarf_hearthkeeper":
			return _character(class_id, "Hearthkeeper", 4, 23, 4, 3, [&"hearth_reset", &"warm_the_line", &"shared_forge"])
		&"dwarf_thunderbreaker":
			return RunCharacter.new(class_id, "Thunderbreaker", 2, 25, _thunderbreaker(), 8, 3, &"dwarf")
		_:
			return null


static func _character(id: StringName, name: String, speed: int, hp: int, power: int, defense: int, ids: Array[StringName]) -> RunCharacter:
	return RunCharacter.new(id, name, speed, hp, _skills(ids), power, defense, &"dwarf")


static func _thunderbreaker() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"weight_of_the_hammer", 1, e.armor_stripping_damage(e.TargetRole.PRIMARY, 100, 2)),
		_skill(&"cracked_foundation", 3, e.conditional_damage(e.TargetRole.PRIMARY, 160, 190, e.BonusCondition.LOST_THREE_ARMOR_THIS_ROUND)),
		_skill(&"thunderfall_decision", 5, e.conditional_damage(e.TargetRole.PRIMARY, 220, 250, e.BonusCondition.LOST_ARMOR_THIS_ROUND, false, true)),
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
