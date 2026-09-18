class_name LegacyDebugFixture
extends RefCounted

## Explicit legacy units for isolated combat/UI regression tests.

static func create_units() -> Array[BattleUnitState]:
	return [
		BattleUnitState.new(&"player_0", "Player Front 1", BattleUnitState.Side.PLAYER, 0, 8, 20, _skill_roster([
			_create_skill(&"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE, "Deal 7 damage.", "One selected active enemy.", "User must occupy a front-row slot.", "1 turn after use."),
			_create_skill(&"frontline_guard", "Frontline Guard", CharacterSkill.Kind.PASSIVE, "Reduce the next damage taken by an adjacent ally by 3.", "Adjacent active allies.", "User must occupy a front-row slot.", "None"),
		])),
		BattleUnitState.new(&"player_1", "Player Front 2", BattleUnitState.Side.PLAYER, 1, 6),
		BattleUnitState.new(&"player_2", "Player Front 3", BattleUnitState.Side.PLAYER, 2, 6, 20, _skill_roster([
			_create_skill(&"quick_step", "Quick Step", CharacterSkill.Kind.ACTIVE, "Gain 2 Speed until the end of the next turn.", "Self.", "None", "2 turns after use."),
		])),
		BattleUnitState.new(&"player_3", "Player Back 1", BattleUnitState.Side.PLAYER, 3, 4),
		BattleUnitState.new(&"player_4", "Player Back 2", BattleUnitState.Side.PLAYER, 4, 9, 20, _skill_roster([
			_create_skill(&"quick_strike", "Quick Strike", CharacterSkill.Kind.ACTIVE, "Deal 5 damage.", "One selected active enemy.", "None", "None"),
			_create_skill(&"rally", "Rally", CharacterSkill.Kind.ACTIVE, "Grant all active allies 2 Speed until the end of the round.", "All active allies, including the user.", "None", "2 turns after use."),
			_create_skill(&"evasion", "Evasion", CharacterSkill.Kind.PASSIVE, "Prevent the first damage instance received each round.", "Self.", "None", "None"),
			_create_skill(&"momentum", "Momentum", CharacterSkill.Kind.PASSIVE, "Gain 1 Speed after taking an action, lasting until battle ends.", "Self.", "User must remain active.", "None"),
		])),
		BattleUnitState.new(&"player_5", "Player Back 3", BattleUnitState.Side.PLAYER, 5, 2),
		BattleUnitState.new(&"enemy_0", "Enemy Front 1", BattleUnitState.Side.ENEMY, 0, 8, 20, _skill_roster([
			_create_skill(&"savage_blow", "Savage Blow", CharacterSkill.Kind.ACTIVE, "Deal 12 damage.", "One selected active enemy.", "User must be above 50% HP.", "2 turns after use."),
			_create_skill(&"blood_scent", "Blood Scent", CharacterSkill.Kind.PASSIVE, "Deal 3 additional damage to injured enemies.", "Enemies below 50% HP.", "Target must be below 50% HP.", "None"),
		])),
		BattleUnitState.new(&"enemy_4", "Enemy Back 2", BattleUnitState.Side.ENEMY, 4, 9, 20, _skill_roster([
			_create_skill(&"shadow_lunge", "Shadow Lunge", CharacterSkill.Kind.ACTIVE, "Deal 10 damage.", "Farthest active enemy.", "User must occupy a back-row slot.", "Unavailable for the first turn of battle; none after use."),
		])),
	]


static func _create_skill(
	id: StringName,
	display_name: String,
	kind: CharacterSkill.Kind,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> CharacterSkill:
	var targeting_mode: CharacterSkill.TargetingMode = CharacterSkill.TargetingMode.PREDEFINED
	var target_side: CharacterSkill.TargetSide = CharacterSkill.TargetSide.SELF
	var target_rule: CharacterSkill.TargetRule = CharacterSkill.TargetRule.SELF
	var requirement: CharacterSkill.Requirement = CharacterSkill.Requirement.NONE
	var mechanical_effect: CharacterSkill.Effect = CharacterSkill.Effect.NONE
	var effect_magnitude: int = 0
	var effect_duration: int = 0
	var effect_duration_mode: CharacterSkill.EffectDuration = CharacterSkill.EffectDuration.NONE
	var cooldown_mode: CharacterSkill.CooldownMode = CharacterSkill.CooldownMode.NONE
	var cooldown_actions: int = 0
	var unavailable_through_round: int = 0
	var combo_definition: RefCounted = null
	match id:
		&"shield_bash":
			targeting_mode = CharacterSkill.TargetingMode.FREE
			target_side = CharacterSkill.TargetSide.ENEMY
			target_rule = CharacterSkill.TargetRule.SELECT_ONE
			requirement = CharacterSkill.Requirement.FRONT_ROW
			mechanical_effect = CharacterSkill.Effect.DAMAGE
			effect_magnitude = 7
			cooldown_mode = CharacterSkill.CooldownMode.POST_USE_ACTIONS
			cooldown_actions = 1
		&"quick_step":
			target_side = CharacterSkill.TargetSide.SELF
			target_rule = CharacterSkill.TargetRule.SELF
			mechanical_effect = CharacterSkill.Effect.SPEED_BOOST
			effect_magnitude = 2
			effect_duration = 1
			effect_duration_mode = CharacterSkill.EffectDuration.NEXT_ACTION
			cooldown_mode = CharacterSkill.CooldownMode.POST_USE_ACTIONS
			cooldown_actions = 2
		&"quick_strike":
			targeting_mode = CharacterSkill.TargetingMode.FREE
			target_side = CharacterSkill.TargetSide.ENEMY
			target_rule = CharacterSkill.TargetRule.SELECT_ONE
			mechanical_effect = CharacterSkill.Effect.DAMAGE
			effect_magnitude = 5
			var condition_script: Script = load("res://Scripts/Battle/combo_condition.gd")
			var effect_script: Script = load("res://Scripts/Battle/combo_bonus_effect.gd")
			var definition_script: Script = load("res://Scripts/Battle/combo_definition.gd")
			combo_definition = definition_script.create(
				[condition_script.create(0)],
				[effect_script.create(0, 3)],
				"+3 damage if another ally damaged this target with a skill this round."
			)
		&"rally":
			target_side = CharacterSkill.TargetSide.ALLY
			target_rule = CharacterSkill.TargetRule.ALL_ACTIVE_ALLIES
			mechanical_effect = CharacterSkill.Effect.SPEED_BOOST
			effect_magnitude = 2
			effect_duration = 1
			effect_duration_mode = CharacterSkill.EffectDuration.CURRENT_ROUND
			cooldown_mode = CharacterSkill.CooldownMode.POST_USE_ACTIONS
			cooldown_actions = 2
		&"savage_blow":
			targeting_mode = CharacterSkill.TargetingMode.FREE
			target_side = CharacterSkill.TargetSide.ENEMY
			target_rule = CharacterSkill.TargetRule.SELECT_ONE
			requirement = CharacterSkill.Requirement.ABOVE_HALF_HP
			mechanical_effect = CharacterSkill.Effect.DAMAGE
			effect_magnitude = 12
			cooldown_mode = CharacterSkill.CooldownMode.POST_USE_ACTIONS
			cooldown_actions = 2
		&"shadow_lunge":
			target_side = CharacterSkill.TargetSide.ENEMY
			target_rule = CharacterSkill.TargetRule.FARTHEST_ACTIVE_ENEMY
			requirement = CharacterSkill.Requirement.BACK_ROW
			mechanical_effect = CharacterSkill.Effect.DAMAGE
			effect_magnitude = 10
			cooldown_mode = CharacterSkill.CooldownMode.ROUND_GATE
			unavailable_through_round = 1
	return CharacterSkill.new(
		id,
		display_name,
		kind,
		effect,
		targeting,
		requirements,
		cooldown,
		targeting_mode,
		target_side,
		target_rule,
		requirement,
		mechanical_effect,
		effect_magnitude,
		effect_duration,
		effect_duration_mode,
		cooldown_mode,
		cooldown_actions,
		unavailable_through_round,
		combo_definition
	)


static func _skill_roster(values: Array) -> Array[CharacterSkill]:
	var roster: Array[CharacterSkill] = []
	for value: Variant in values:
		roster.append(value as CharacterSkill)
	return roster


