class_name WerewolfWaveBCatalog
extends RefCounted

const IDS: Array[StringName] = [
	&"werewolf_duskhide_ravager",
	&"werewolf_den_warden",
	&"werewolf_moonblood_seer",
]


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
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"reckless_claw", "Reckless Claw",
			"Deal 130% Power and lose 10% max HP, stopping at 1 HP.",
			"One active enemy.", "Self-damage cannot defeat the actor.", 0,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[], [
				e.damage(e.TargetRole.PRIMARY, 130),
				e.capped_self_damage(10),
			]
		),
		_skill(
			&"feed_through_pain", "Feed Through Pain",
			"Below 70% HP, deal 140% Power and Leech 40%.",
			"One active enemy.", "Actor must be below 70% HP.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.ACTOR_BELOW_SEVENTY_PERCENT_HP)], [
				e.damage(e.TargetRole.PRIMARY, 140, 160),
				e.leech(e.TargetRole.ACTOR, 40),
			]
		),
		_skill(
			&"frenzied_lunge", "Frenzied Lunge",
			"Below half HP, move up to 2 and deal 210% Power.",
			"Self Move 1-2, then one enemy.", "Actor must be below half HP.", 5,
			_profile(1, 1, BattleUnitState.Side.ENEMY, false, true),
			[c.create(c.Kind.ACTOR_BELOW_HALF_HP)], [
				e.damage(e.TargetRole.PRIMARY, 210),
				e.self_move(2, 1),
			]
		),
	]


static func _warden() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"armor_the_weak", "Armor the Weak",
			"A neighboring ally below half HP gains 5 Armor.",
			"One neighboring wounded ally.", "Requires an ally below half HP.", 1,
			_profile(1, 1, BattleUnitState.Side.PLAYER, true),
			[c.create(c.Kind.PRIMARY_BELOW_HALF_HP)], [
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 5),
			]
		),
		_skill(
			&"warning_snarl", "Warning Snarl",
			"Deal 130% Power to an enemy that hit an Armored ally this round.",
			"One qualifying enemy.", "Enemy must have hit an Armored ally.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_ATTACKED_ARMORED_ALLY_THIS_ROUND)], [
				e.damage(e.TargetRole.PRIMARY, 130, 160),
			]
		),
		_skill(
			&"pack_intercept", "Pack Intercept",
			"Swap with any ally; both of you gain 3 Armor.",
			"Self and one ally.", "Requires a legal path ending at the ally.", 4,
			_profile(1, 1, BattleUnitState.Side.PLAYER, false, true),
			[], [
				e.self_move(3, 1),
				e.keyword(e.TargetRole.ACTOR, BattleKeywordOperation.Kind.ADD_ARMOR, 3),
				e.keyword(e.TargetRole.PRIMARY, BattleKeywordOperation.Kind.ADD_ARMOR, 3),
			]
		),
	]


static func _seer() -> Array[CharacterSkill]:
	var e: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var c: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_skill(
			&"foretell_the_kill", "Foretell the Kill",
			"While an enemy is above half HP, grant one ally Advantage.",
			"One active ally.", "Requires an enemy above half HP.", 1,
			_profile(1, 1, BattleUnitState.Side.PLAYER),
			[c.create(c.Kind.ANY_ENEMY_ABOVE_HALF_HP)], [
				e.keyword(
					e.TargetRole.PRIMARY,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
		_skill(
			&"red_moon_strike", "Red Moon Strike",
			"Below half HP, deal 120% Power; with Advantage, deal 150% and Leech 25%.",
			"One enemy below half HP.", "Requires wounded prey.", 2,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_BELOW_HALF_HP)], [
				e.damage(e.TargetRole.PRIMARY, 120, 150),
				e.conditional_leech(e.TargetRole.ACTOR, 0, 25),
			]
		),
		_skill(
			&"eclipse_hunt", "Eclipse Hunt",
			"This round, each ally may move 1 after its first direct hit on wounded prey.",
			"One enemy below half HP.", "Requires wounded prey.", 5,
			_profile(1, 1, BattleUnitState.Side.ENEMY),
			[c.create(c.Kind.PRIMARY_BELOW_HALF_HP)], [
				e.post_hit_move_one(e.TargetRole.ALL_ACTIVE_ALLIES, 1),
			]
		),
	]


static func _profile(
	minimum: int,
	maximum: int,
	side: int,
	adjacent: bool = false,
	allows_movement: bool = false
) -> RefCounted:
	var p: Script = load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return p.create(minimum, maximum, side, adjacent, allows_movement)


static func _skill(
	skill_id: StringName,
	title: String,
	effect_text: String,
	targeting_text: String,
	requirements_text: String,
	cooldown: int,
	profile: RefCounted,
	conditions: Array[RefCounted],
	effects: Array[RefCounted]
) -> CharacterSkill:
	var cooldown_mode: int = (
		CharacterSkill.CooldownMode.NONE
		if cooldown == 0
		else CharacterSkill.CooldownMode.POST_USE_ACTIONS
	)
	return CharacterSkill.create(
		skill_id, title, CharacterSkill.Kind.ACTIVE, effect_text, targeting_text,
		requirements_text, "CD%d" % cooldown, CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY, CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE, 0, 0,
		CharacterSkill.EffectDuration.NONE, cooldown_mode,
		cooldown, 0, null, [], null, null, profile, conditions, effects
	)
