class_name GoblinWaveACatalog
extends RefCounted

const SCRAPSHIELD_BRUISER_ID := &"scrapshield_bruiser"
const WIREFANG_SKIRMISHER_ID := &"wirefang_skirmisher"
const SNAREWRIGHT_ID := &"snarewright"


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	match class_id:
		SCRAPSHIELD_BRUISER_ID:
			return RunCharacter.new(
				class_id,
				"Scrapshield Bruiser",
				7,
				20,
				_scrapshield_skills(),
				4,
				2
			)
		WIREFANG_SKIRMISHER_ID:
			return RunCharacter.new(
				class_id,
				"Wirefang Skirmisher",
				10,
				14,
				_wirefang_skills(),
				6,
				0
			)
		SNAREWRIGHT_ID:
			return RunCharacter.new(
				class_id,
				"Snarewright",
				9,
				16,
				_snarewright_skills(),
				4,
				1
			)
		_:
			return null


static func _scrapshield_skills() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_active_skill(
			&"shield_tap",
			"Shield Tap",
			"Deal 85% Power. If this enemy attacked an ally this round, that ally gains 2 Armor.",
			"One active enemy.",
			"None",
			1,
			_enemy_profile(1, 1),
			[],
			[
				effect_script.damage(effect_script.TargetRole.PRIMARY, 85),
				effect_script.keyword(
					effect_script.TargetRole.HISTORY_ALLY,
					BattleKeywordOperation.Kind.ADD_ARMOR,
					2
				),
			]
		),
		_active_skill(
			&"pack_brace",
			"Pack Brace",
			"You and one adjacent ally gain 3 Armor.",
			"One active adjacent ally.",
			"Requires a legal adjacent ally.",
			2,
			_ally_profile(true),
			[],
			[
				effect_script.keyword(
					effect_script.TargetRole.ACTOR,
					BattleKeywordOperation.Kind.ADD_ARMOR,
					3
				),
				effect_script.keyword(
					effect_script.TargetRole.PRIMARY,
					BattleKeywordOperation.Kind.ADD_ARMOR,
					3
				),
			]
		),
		_active_skill(
			&"banner_nudge",
			"Banner Nudge",
			"Apply Advantage to one enemy until round end.",
			"One active enemy.",
			"None",
			3,
			_enemy_profile(1, 1),
			[],
			[
				effect_script.keyword(
					effect_script.TargetRole.PRIMARY,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
	]


static func _wirefang_skills() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	return [
		_active_skill(
			&"quick_mark",
			"Quick Mark",
			"Deal 90% Power, then apply Advantage until round end.",
			"One active enemy.",
			"None",
			1,
			_enemy_profile(1, 1),
			[],
			[
				effect_script.damage(effect_script.TargetRole.PRIMARY, 90),
				effect_script.keyword(
					effect_script.TargetRole.PRIMARY,
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					0,
					1
				),
			]
		),
		_active_skill(
			&"cheap_finish",
			"Cheap Finish",
			"Deal 120% Power; consume the target's Advantage to deal 160% instead.",
			"One active enemy.",
			"None",
			2,
			_enemy_profile(1, 1),
			[],
			[
				effect_script.damage(effect_script.TargetRole.PRIMARY, 120, 160),
			]
		),
		_active_skill(
			&"slipstep",
			"Slipstep",
			"Optionally move 1, then gain 2 Armor.",
			"Self.",
			"An explicitly chosen path must remain legal.",
			3,
			_optional_move_profile(),
			[],
			[
				effect_script.optional_self_move(),
				effect_script.keyword(
					effect_script.TargetRole.ACTOR,
					BattleKeywordOperation.Kind.ADD_ARMOR,
					2
				),
			]
		),
	]


static func _snarewright_skills() -> Array[CharacterSkill]:
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var condition_script := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return [
		_active_skill(
			&"tripline_tag",
			"Tripline Tag",
			"Apply Snared. The first later allied direct hit this round applies Advantage after damage.",
			"One active enemy.",
			"None",
			1,
			_enemy_profile(1, 1),
			[],
			[
				effect_script.keyword(
					effect_script.TargetRole.PRIMARY,
					BattleKeywordOperation.Kind.APPLY_SNARED,
					0,
					1
				),
			]
		),
		_active_skill(
			&"holdfast_wire",
			"Holdfast Wire",
			"Against a Snared enemy, deal 115% Power and reduce Speed by 1 this round.",
			"One active enemy.",
			"Target must be Snared.",
			2,
			_enemy_profile(1, 1),
			[condition_script.create(condition_script.Kind.PRIMARY_SNARED)],
			[
				effect_script.damage(effect_script.TargetRole.PRIMARY, 115),
				effect_script.speed(effect_script.TargetRole.PRIMARY, -1, 1),
			]
		),
		_active_skill(
			&"ring_net",
			"Ring Net",
			"Apply Snared to up to 2 enemies until round end.",
			"One or two active enemies.",
			"All selected targets must remain valid.",
			4,
			_enemy_profile(1, 2),
			[],
			[
				effect_script.keyword(
					effect_script.TargetRole.ALL_SELECTED,
					BattleKeywordOperation.Kind.APPLY_SNARED,
					0,
					1
				),
			]
		),
	]


static func _active_skill(
	skill_id: StringName,
	display_name: String,
	effect_text: String,
	targeting_text: String,
	requirements_text: String,
	cooldown: int,
	profile: RefCounted,
	conditions: Array[RefCounted],
	effects: Array[RefCounted]
) -> CharacterSkill:
	return CharacterSkill.create(
		skill_id,
		display_name,
		CharacterSkill.Kind.ACTIVE,
		effect_text,
		targeting_text,
		requirements_text,
		"CD%d" % cooldown,
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.NONE,
		0,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		cooldown,
		0,
		null,
		[],
		null,
		null,
		profile,
		conditions,
		effects
	)


static func _enemy_profile(minimum: int, maximum: int) -> RefCounted:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return profile_script.create(
		minimum,
		maximum,
		BattleUnitState.Side.ENEMY,
		false,
		false
	)


static func _ally_profile(requires_adjacency: bool) -> RefCounted:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return profile_script.create(
		1,
		1,
		BattleUnitState.Side.PLAYER,
		requires_adjacency,
		false
	)


static func _optional_move_profile() -> RefCounted:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return profile_script.create(
		0,
		0,
		BattleUnitState.Side.PLAYER,
		false,
		true
	)
