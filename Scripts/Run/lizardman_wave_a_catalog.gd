extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"lizardman_venom_saurian":
			return RunCharacter.new(class_id, "Venom Saurian", 5, 20, _venom_saurian(), 7, 1, &"lizardman")
		&"lizardman_scale_sentinel":
			return RunCharacter.new(class_id, "Scale Sentinel", 3, 26, _scale_sentinel(), 4, 3, &"lizardman")
		&"lizardman_mire_spitter":
			return RunCharacter.new(class_id, "Mire Spitter", 6, 18, _mire_spitter(), 5, 1, &"lizardman")
		_:
			return null


static func _venom_saurian() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"weakening_bite", "Weakening Bite", 1, [_damage(effect_script, 80), effect_script.poison(effect_script.TargetRole.PRIMARY, &"power", 1, 3)]),
		_skill(&"venom_pulse", "Venom Pulse", 2, [_damage(effect_script, 100), effect_script.poison(effect_script.TargetRole.PRIMARY, &"power", 1, 3)]),
		_skill(&"cold_finish", "Cold Finish", 4, [_damage(effect_script, 120)]),
	]


static func _scale_sentinel() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"brace_scales", "Brace Scales", 1, [effect_script.keyword(effect_script.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 5)]),
		_skill(&"tail_check", "Tail Check", 2, [_damage(effect_script, 90, 120)]),
		_skill(&"layered_scales", "Layered Scales", 4, [effect_script.keyword(effect_script.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 8)]),
	]


static func _mire_spitter() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"slowing_spit", "Slowing Spit", 1, [_damage(effect_script, 70), effect_script.poison(effect_script.TargetRole.PRIMARY, &"speed", 1, 3)]),
		_skill(&"bog_down", "Bog Down", 2, [effect_script.poison(effect_script.TargetRole.PRIMARY, &"speed", 1, 3)]),
		_skill(&"saturate_ground", "Saturate Ground", 4, [effect_script.poison(effect_script.TargetRole.ALL_SELECTED, &"speed", 1, 3)], 2, 3),
	]


static func _damage(effect_script: Script, percent: int, advantage_percent: int = 0) -> RefCounted:
	return effect_script.damage(effect_script.TargetRole.PRIMARY, percent, advantage_percent)


static func _skill(skill_id: StringName, display_name: String, cooldown: int, effects: Array[RefCounted], minimum: int = 1, maximum: int = 1) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(minimum, maximum, BattleUnitState.Side.ENEMY)
	return CharacterSkill.create(skill_id, display_name, CharacterSkill.Kind.ACTIVE, display_name, "Authored target.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], effects)
