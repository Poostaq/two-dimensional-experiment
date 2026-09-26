extends RefCounted


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		&"lizardman_fang_alchemist":
			return RunCharacter.new(class_id, "Fang Alchemist", 5, 21, _skills(&"fang_alchemist"), 6, 2, &"lizardman")
		&"lizardman_reed_ambusher":
			return RunCharacter.new(class_id, "Reed Ambusher", 6, 19, _skills(&"reed_ambusher"), 7, 1, &"lizardman")
		&"lizardman_sunscale_warder":
			return RunCharacter.new(class_id, "Sunscale Warder", 4, 24, _skills(&"sunscale_warder"), 4, 3, &"lizardman")
		_:
			return null


static func _skills(kind: StringName) -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	match kind:
		&"fang_alchemist":
			return [
				_skill(&"corrosive_dose", "Corrosive Dose", 1, [_damage(effect_script, 70), effect_script.poison(effect_script.TargetRole.PRIMARY, &"defense", 1, 3)]),
				_skill(&"catalyze", "Catalyze", 2, [_damage(effect_script, 80)]),
				_skill(&"antidote_exchange", "Antidote Exchange", 4, [effect_script.poison(effect_script.TargetRole.PRIMARY, &"defense", 1, 3)]),
			]
		&"reed_ambusher":
			return [
				_skill(&"stillwater_focus", "Stillwater Focus", 1, [effect_script.keyword(effect_script.TargetRole.ACTOR, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
				_skill(&"sudden_lunge", "Sudden Lunge", 3, [_damage(effect_script, 160, 190), effect_script.optional_self_move()]),
				_skill(&"vanish_into_reeds", "Vanish into Reeds", 3, [effect_script.optional_self_move(), effect_script.keyword(effect_script.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 4)]),
			]
		&"sunscale_warder":
			return [
				_skill(&"warming_armor", "Warming Armor", 1, [effect_script.keyword(effect_script.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 4)], BattleUnitState.Side.PLAYER),
				_skill(&"reflecting_scale", "Reflecting Scale", 3, [_damage(effect_script, 150)]),
				_skill(&"solar_bulwark", "Solar Bulwark", 5, [effect_script.keyword(effect_script.TargetRole.ALL_SELECTED, BattleKeywordOperation.Kind.ADD_ARMOR, 4)], BattleUnitState.Side.PLAYER, 2, 4),
			]
	return []


static func _damage(effect_script: Script, percent: int, advantage_percent: int = 0) -> RefCounted:
	return effect_script.damage(effect_script.TargetRole.PRIMARY, percent, advantage_percent)


static func _skill(skill_id: StringName, display_name: String, cooldown: int, effects: Array[RefCounted], side: int = BattleUnitState.Side.ENEMY, minimum: int = 1, maximum: int = 1) -> CharacterSkill:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(minimum, maximum, side)
	var target_side: int = CharacterSkill.TargetSide.ALLY if side == BattleUnitState.Side.PLAYER else CharacterSkill.TargetSide.ENEMY
	return CharacterSkill.create(skill_id, display_name, CharacterSkill.Kind.ACTIVE, display_name, "Authored target.", "See class record.", "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, target_side, CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS, cooldown, 0, null, [], null, null, profile, [], effects)
