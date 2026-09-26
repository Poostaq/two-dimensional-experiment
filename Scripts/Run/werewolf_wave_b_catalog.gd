extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"werewolf_duskhide_ravager":
			return RunCharacter.new(class_id, "Duskhide Ravager", 6, 22, _ravager(), 9, 1, &"werewolf")
		&"werewolf_den_warden":
			return RunCharacter.new(class_id, "Den Warden", 6, 24, _warden(), 6, 2, &"werewolf")
		&"werewolf_moonblood_seer":
			return RunCharacter.new(class_id, "Moonblood Seer", 7, 19, _seer(), 6, 1, &"werewolf")
		_:
			return null


static func _ravager() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"reckless_claw", "Reckless Claw", 1, [e.damage(e.TargetRole.PRIMARY, 130)]),
		_skill(&"feed_through_pain", "Feed Through Pain", 2, [e.damage(e.TargetRole.PRIMARY, 140, 160), e.leech(e.TargetRole.ACTOR, 40)]),
		_skill(&"frenzied_lunge", "Frenzied Lunge", 5, [e.damage(e.TargetRole.PRIMARY, 210), e.optional_self_move()]),
	]


static func _warden() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"armor_the_weak", "Armor the Weak", 1, [e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 5)], BattleUnitState.Side.PLAYER),
		_skill(&"warning_snarl", "Warning Snarl", 2, [e.damage(e.TargetRole.PRIMARY, 130, 160)]),
		_skill(&"pack_intercept", "Pack Intercept", 4, [e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 3), e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 3)], BattleUnitState.Side.PLAYER),
	]


static func _seer() -> Array[CharacterSkill]:
	var e := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_skill(&"foretell_the_kill", "Foretell the Kill", 1, [e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)], BattleUnitState.Side.PLAYER),
		_skill(&"red_moon_strike", "Red Moon Strike", 2, [e.damage(e.TargetRole.PRIMARY, 120, 150), e.leech(e.TargetRole.ACTOR, 25)]),
		_skill(&"eclipse_hunt", "Eclipse Hunt", 5, [e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
	]


static func _skill(skill_id: StringName, display_name: String, cooldown: int, effects: Array[RefCounted], side: int = BattleUnitState.Side.ENEMY) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(1, 1, side)
	var target_side: int = CharacterSkill.TargetSide.ALLY if side == BattleUnitState.Side.PLAYER else CharacterSkill.TargetSide.ENEMY
	return CharacterSkill.create(skill_id, display_name, CharacterSkill.Kind.ACTIVE, display_name, "Authored target.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, target_side, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], effects)
