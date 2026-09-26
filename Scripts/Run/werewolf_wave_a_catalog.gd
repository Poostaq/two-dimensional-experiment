extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"werewolf_moonfang_skirmisher":
			return RunCharacter.new(class_id, "Moonfang Skirmisher", 9, 17, _moonfang(), 9, 0, &"werewolf")
		&"werewolf_pack_howler":
			return RunCharacter.new(class_id, "Pack Howler", 8, 20, _howler(), 6, 1, &"werewolf")
		&"werewolf_bloodtrail_stalker":
			return RunCharacter.new(class_id, "Bloodtrail Stalker", 8, 18, _stalker(), 8, 0, &"werewolf")
		_:
			return null


static func _moonfang() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"scent_blood", "Scent Blood", 1, [_damage(effect_script, 70), effect_script.keyword(effect_script.TargetRole.ACTOR, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
		_skill(&"pounce", "Pounce", 2, [_damage(effect_script, 140, 170), effect_script.optional_self_move()]),
		_skill(&"moonfang_finish", "Moonfang Finish", 4, [_damage(effect_script, 190), effect_script.leech(effect_script.TargetRole.ACTOR, 35)]),
	]


static func _howler() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"hunting_cry", "Hunting Cry", 2, [effect_script.keyword(effect_script.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)], BattleUnitState.Side.PLAYER, 1, 2),
		_skill(&"drive_the_pack", "Drive the Pack", 3, [effect_script.keyword(effect_script.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 1)], BattleUnitState.Side.PLAYER, 1, 2),
		_skill(&"full_moon_chorus", "Full-Moon Chorus", 5, [effect_script.keyword(effect_script.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 2)], BattleUnitState.Side.PLAYER, 1, 6),
	]


static func _stalker() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"rake", "Rake", 1, [_damage(effect_script, 90), effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_BLEED, 0, 2)]),
		_skill(&"follow_the_trail", "Follow the Trail", 2, [_damage(effect_script, 120), effect_script.optional_self_move()]),
		_skill(&"cornered_prey", "Cornered Prey", 4, [_damage(effect_script, 170), effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_BLEED, 0, 2)]),
	]


static func _damage(effect_script: Script, percent: int, advantage_percent: int = 0) -> RefCounted:
	return effect_script.damage(effect_script.TargetRole.PRIMARY, percent, advantage_percent)


static func _skill(skill_id: StringName, display_name: String, cooldown: int, effects: Array[RefCounted], side: int = BattleUnitState.Side.ENEMY, minimum: int = 1, maximum: int = 1) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(minimum, maximum, side)
	var target_side: int = CharacterSkill.TargetSide.ALLY if side == BattleUnitState.Side.PLAYER else CharacterSkill.TargetSide.ENEMY
	return CharacterSkill.create(skill_id, display_name, CharacterSkill.Kind.ACTIVE, display_name, "Authored target.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, target_side, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], effects)
