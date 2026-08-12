class_name CharacterSkill
extends RefCounted

enum Kind {
	ACTIVE,
	PASSIVE,
}

enum TargetingMode {
	FREE,
	PREDEFINED,
}

enum TargetSide {
	SELF,
	ALLY,
	ENEMY,
}

enum TargetRule {
	SELECT_ONE,
	SELF,
	ALL_ACTIVE_ALLIES,
	FARTHEST_ACTIVE_ENEMY,
}

enum Requirement {
	NONE,
	FRONT_ROW,
	BACK_ROW,
	ABOVE_HALF_HP,
}

enum Effect {
	NONE,
	DAMAGE,
	SPEED_BOOST,
}

enum EffectDuration {
	NONE,
	NEXT_ACTION,
	CURRENT_ROUND,
}

enum CooldownMode {
	NONE,
	POST_USE_ACTIONS,
	ROUND_GATE,
}

var skill_id: StringName:
	get:
		return _skill_id
var display_name: String:
	get:
		return _display_name
var kind: Kind:
	get:
		return _kind
var effect_text: String:
	get:
		return _effect_text
var targeting_text: String:
	get:
		return _targeting_text
var requirements_text: String:
	get:
		return _requirements_text
var cooldown_text: String:
	get:
		return _cooldown_text
var targeting_mode: TargetingMode:
	get:
		return _targeting_mode
var target_side: TargetSide:
	get:
		return _target_side
var target_rule: TargetRule:
	get:
		return _target_rule
var requirement: Requirement:
	get:
		return _requirement
var effect: Effect:
	get:
		return _effect
var effect_magnitude: int:
	get:
		return _effect_magnitude
var effect_duration: int:
	get:
		return _effect_duration
var effect_duration_mode: EffectDuration:
	get:
		return _effect_duration_mode
var cooldown_mode: CooldownMode:
	get:
		return _cooldown_mode
var cooldown_actions: int:
	get:
		return _cooldown_actions
var unavailable_through_round: int:
	get:
		return _unavailable_through_round
var combo_definition: RefCounted:
	get:
		return _combo_definition.duplicate_definition() if is_instance_valid(_combo_definition) else null

var _skill_id: StringName = &""
var _display_name: String = ""
var _kind: Kind = Kind.ACTIVE
var _effect_text: String = ""
var _targeting_text: String = ""
var _requirements_text: String = ""
var _cooldown_text: String = ""
var _targeting_mode: TargetingMode = TargetingMode.PREDEFINED
var _target_side: TargetSide = TargetSide.SELF
var _target_rule: TargetRule = TargetRule.SELF
var _requirement: Requirement = Requirement.NONE
var _effect: Effect = Effect.NONE
var _effect_magnitude: int = 0
var _effect_duration: int = 0
var _effect_duration_mode: EffectDuration = EffectDuration.NONE
var _cooldown_mode: CooldownMode = CooldownMode.NONE
var _cooldown_actions: int = 0
var _unavailable_through_round: int = 0
var _combo_definition: RefCounted = null
var _is_valid: bool = false


func _init(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String,
	targeting_mode_value: int = -1,
	target_side_value: int = -1,
	target_rule_value: int = -1,
	requirement_value: int = Requirement.NONE,
	effect_value: int = -1,
	effect_magnitude_value: int = -1,
	effect_duration_value: int = 0,
	effect_duration_mode_value: int = EffectDuration.NONE,
	cooldown_mode_value: int = CooldownMode.NONE,
	cooldown_actions_value: int = 0,
	unavailable_through_round_value: int = 0,
	combo_definition_value: RefCounted = null
) -> void:
	if not is_valid_definition(id, name, skill_kind, effect, targeting, requirements, cooldown):
		push_error("CharacterSkill requires non-blank identity, preview fields, and a valid kind.")
		return
	if targeting_mode_value < 0:
		targeting_mode_value = TargetingMode.FREE if skill_kind == Kind.ACTIVE else TargetingMode.PREDEFINED
	if target_side_value < 0:
		target_side_value = TargetSide.ENEMY if skill_kind == Kind.ACTIVE else TargetSide.SELF
	if target_rule_value < 0:
		target_rule_value = TargetRule.SELECT_ONE if skill_kind == Kind.ACTIVE else TargetRule.SELF
	if effect_value < 0:
		effect_value = Effect.DAMAGE if skill_kind == Kind.ACTIVE else Effect.NONE
	if effect_magnitude_value < 0:
		effect_magnitude_value = 1 if skill_kind == Kind.ACTIVE else 0
	if is_instance_valid(combo_definition_value) and (
		combo_definition_value.get_script().resource_path != "res://Scripts/Battle/combo_definition.gd"
		or not combo_definition_value.is_valid()
		or skill_kind != Kind.ACTIVE
		or target_rule_value != TargetRule.SELECT_ONE
	):
		push_error("CharacterSkill combo definitions require an active single-target skill.")
		return
	if not is_valid_mechanical_definition(
		skill_kind,
		targeting_mode_value,
		target_side_value,
		target_rule_value,
		requirement_value,
		effect_value,
		effect_magnitude_value,
		effect_duration_value,
		effect_duration_mode_value,
		cooldown_mode_value,
		cooldown_actions_value,
		unavailable_through_round_value
	):
		push_error("CharacterSkill requires a valid typed mechanical definition.")
		return
	_skill_id = id
	_display_name = name
	_kind = skill_kind as Kind
	_effect_text = effect
	_targeting_text = targeting
	_requirements_text = requirements
	_cooldown_text = cooldown
	_targeting_mode = targeting_mode_value as TargetingMode
	_target_side = target_side_value as TargetSide
	_target_rule = target_rule_value as TargetRule
	_requirement = requirement_value as Requirement
	_effect = effect_value as Effect
	_effect_magnitude = effect_magnitude_value
	_effect_duration = effect_duration_value
	_effect_duration_mode = effect_duration_mode_value as EffectDuration
	_cooldown_mode = cooldown_mode_value as CooldownMode
	_cooldown_actions = cooldown_actions_value
	_unavailable_through_round = unavailable_through_round_value
	_combo_definition = (
		combo_definition_value.duplicate_definition()
		if is_instance_valid(combo_definition_value)
		else null
	)
	_is_valid = true


static func create(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String,
	targeting_mode_value: int = -1,
	target_side_value: int = -1,
	target_rule_value: int = -1,
	requirement_value: int = Requirement.NONE,
	effect_value: int = -1,
	effect_magnitude_value: int = -1,
	effect_duration_value: int = 0,
	effect_duration_mode_value: int = EffectDuration.NONE,
	cooldown_mode_value: int = CooldownMode.NONE,
	cooldown_actions_value: int = 0,
	unavailable_through_round_value: int = 0,
	combo_definition_value: RefCounted = null
) -> CharacterSkill:
	var skill: CharacterSkill = CharacterSkill.new(
		id,
		name,
		skill_kind,
		effect,
		targeting,
		requirements,
		cooldown,
		targeting_mode_value,
		target_side_value,
		target_rule_value,
		requirement_value,
		effect_value,
		effect_magnitude_value,
		effect_duration_value,
		effect_duration_mode_value,
		cooldown_mode_value,
		cooldown_actions_value,
		unavailable_through_round_value,
		combo_definition_value
	)
	return skill if skill.is_valid() else null


static func is_valid_definition(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> bool:
	return (
		not String(id).strip_edges().is_empty()
		and not name.strip_edges().is_empty()
		and skill_kind in [Kind.ACTIVE, Kind.PASSIVE]
		and not effect.strip_edges().is_empty()
		and not targeting.strip_edges().is_empty()
		and not requirements.strip_edges().is_empty()
		and not cooldown.strip_edges().is_empty()
	)


static func is_valid_mechanical_definition(
	skill_kind: int,
	targeting_mode_value: int,
	target_side_value: int,
	target_rule_value: int,
	requirement_value: int,
	effect_value: int,
	effect_magnitude_value: int,
	effect_duration_value: int,
	effect_duration_mode_value: int,
	cooldown_mode_value: int,
	cooldown_actions_value: int,
	unavailable_through_round_value: int
) -> bool:
	if (
		skill_kind not in [Kind.ACTIVE, Kind.PASSIVE]
		or targeting_mode_value not in [TargetingMode.FREE, TargetingMode.PREDEFINED]
		or target_side_value not in [TargetSide.SELF, TargetSide.ALLY, TargetSide.ENEMY]
		or target_rule_value not in [
			TargetRule.SELECT_ONE,
			TargetRule.SELF,
			TargetRule.ALL_ACTIVE_ALLIES,
			TargetRule.FARTHEST_ACTIVE_ENEMY,
		]
		or requirement_value not in [
			Requirement.NONE,
			Requirement.FRONT_ROW,
			Requirement.BACK_ROW,
			Requirement.ABOVE_HALF_HP,
		]
		or effect_value not in [Effect.NONE, Effect.DAMAGE, Effect.SPEED_BOOST]
		or effect_duration_mode_value not in [
			EffectDuration.NONE,
			EffectDuration.NEXT_ACTION,
			EffectDuration.CURRENT_ROUND,
		]
		or cooldown_mode_value not in [
			CooldownMode.NONE,
			CooldownMode.POST_USE_ACTIONS,
			CooldownMode.ROUND_GATE,
		]
		or effect_magnitude_value < 0
		or effect_duration_value < 0
		or cooldown_actions_value < 0
		or unavailable_through_round_value < 0
	):
		return false
	if skill_kind == Kind.PASSIVE:
		return (
			effect_value == Effect.NONE
			and effect_magnitude_value == 0
			and effect_duration_value == 0
			and effect_duration_mode_value == EffectDuration.NONE
			and cooldown_mode_value == CooldownMode.NONE
			and cooldown_actions_value == 0
			and unavailable_through_round_value == 0
		)
	if effect_value == Effect.NONE:
		return false
	if targeting_mode_value == TargetingMode.FREE:
		if target_rule_value != TargetRule.SELECT_ONE or target_side_value == TargetSide.SELF:
			return false
	elif not (
		(target_rule_value == TargetRule.SELF and target_side_value == TargetSide.SELF)
		or (
			target_rule_value == TargetRule.ALL_ACTIVE_ALLIES
			and target_side_value == TargetSide.ALLY
		)
		or (
			target_rule_value == TargetRule.FARTHEST_ACTIVE_ENEMY
			and target_side_value == TargetSide.ENEMY
		)
	):
		return false
	if effect_value == Effect.DAMAGE and (
		effect_magnitude_value <= 0
		or effect_duration_value != 0
		or effect_duration_mode_value != EffectDuration.NONE
	):
		return false
	if effect_value == Effect.SPEED_BOOST and (
		effect_magnitude_value <= 0
		or effect_duration_value <= 0
		or effect_duration_mode_value == EffectDuration.NONE
	):
		return false
	match cooldown_mode_value:
		CooldownMode.NONE:
			return cooldown_actions_value == 0 and unavailable_through_round_value == 0
		CooldownMode.POST_USE_ACTIONS:
			return cooldown_actions_value > 0 and unavailable_through_round_value == 0
		CooldownMode.ROUND_GATE:
			return cooldown_actions_value == 0 and unavailable_through_round_value > 0
	return false


func mechanical_definition() -> Dictionary:
	return {
		"targeting_mode": _targeting_mode,
		"target_side": _target_side,
		"target_rule": _target_rule,
		"requirement": _requirement,
		"effect": _effect,
		"effect_magnitude": _effect_magnitude,
		"effect_duration": _effect_duration,
		"effect_duration_mode": _effect_duration_mode,
		"cooldown_mode": _cooldown_mode,
		"cooldown_actions": _cooldown_actions,
		"unavailable_through_round": _unavailable_through_round,
		"combo_definition": (
			_combo_definition.duplicate_definition()
			if is_instance_valid(_combo_definition)
			else null
		),
	}


func is_valid() -> bool:
	return _is_valid


func duplicate_skill() -> CharacterSkill:
	if not _is_valid:
		return null
	return CharacterSkill.new(
		_skill_id,
		_display_name,
		_kind,
		_effect_text,
		_targeting_text,
		_requirements_text,
		_cooldown_text,
		_targeting_mode,
		_target_side,
		_target_rule,
		_requirement,
		_effect,
		_effect_magnitude,
		_effect_duration,
		_effect_duration_mode,
		_cooldown_mode,
		_cooldown_actions,
		_unavailable_through_round,
		_combo_definition
	)
