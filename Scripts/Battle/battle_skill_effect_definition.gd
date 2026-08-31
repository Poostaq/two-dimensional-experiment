class_name BattleSkillEffectDefinition
extends RefCounted

enum Kind {
	DAMAGE,
	KEYWORD,
	SPEED,
	OPTIONAL_SELF_MOVE,
}

enum TargetRole {
	ACTOR,
	PRIMARY,
	ALL_SELECTED,
	HISTORY_ALLY,
}

var kind: Kind:
	get:
		return _kind
var target_role: TargetRole:
	get:
		return _target_role
var power_percent: int:
	get:
		return _power_percent
var advantage_power_percent: int:
	get:
		return _advantage_power_percent
var keyword_kind: BattleKeywordOperation.Kind:
	get:
		return _keyword_kind
var magnitude: int:
	get:
		return _magnitude
var duration: int:
	get:
		return _duration

var _kind: Kind = Kind.DAMAGE
var _target_role: TargetRole = TargetRole.ACTOR
var _power_percent: int = 0
var _advantage_power_percent: int = 0
var _keyword_kind: BattleKeywordOperation.Kind = BattleKeywordOperation.Kind.ADD_ARMOR
var _magnitude: int = 0
var _duration: int = 0
var _is_valid: bool = false


func _init(
	effect_kind: int,
	role: int,
	percent: int = 0,
	advantage_percent: int = 0,
	operation_kind: int = BattleKeywordOperation.Kind.ADD_ARMOR,
	effect_magnitude: int = 0,
	effect_duration: int = 0
) -> void:
	if not _is_valid_input(
		effect_kind,
		role,
		percent,
		advantage_percent,
		operation_kind,
		effect_magnitude,
		effect_duration
	):
		return
	_kind = effect_kind as Kind
	_target_role = role as TargetRole
	_power_percent = percent
	_advantage_power_percent = advantage_percent
	_keyword_kind = operation_kind as BattleKeywordOperation.Kind
	_magnitude = effect_magnitude
	_duration = effect_duration
	_is_valid = true


static func damage(
	role: int,
	percent: int,
	advantage_percent: int = 0
) -> RefCounted:
	return _create(Kind.DAMAGE, role, percent, advantage_percent)


static func keyword(
	role: int,
	operation_kind: int,
	effect_magnitude: int = 0,
	effect_duration: int = 0
) -> RefCounted:
	return _create(
		Kind.KEYWORD,
		role,
		0,
		0,
		operation_kind,
		effect_magnitude,
		effect_duration
	)


static func speed(
	role: int,
	effect_magnitude: int,
	effect_duration: int
) -> RefCounted:
	return _create(
		Kind.SPEED,
		role,
		0,
		0,
		BattleKeywordOperation.Kind.ADD_ARMOR,
		effect_magnitude,
		effect_duration
	)


static func optional_self_move() -> RefCounted:
	return _create(Kind.OPTIONAL_SELF_MOVE, TargetRole.ACTOR)


func is_valid() -> bool:
	return _is_valid


func duplicate_definition() -> RefCounted:
	if not is_valid():
		return null
	return _create(
		_kind,
		_target_role,
		_power_percent,
		_advantage_power_percent,
		_keyword_kind,
		_magnitude,
		_duration
	)


static func _create(
	effect_kind: int,
	role: int,
	percent: int = 0,
	advantage_percent: int = 0,
	operation_kind: int = BattleKeywordOperation.Kind.ADD_ARMOR,
	effect_magnitude: int = 0,
	effect_duration: int = 0
) -> RefCounted:
	var definition: RefCounted = load("res://Scripts/Battle/battle_skill_effect_definition.gd").new(
		effect_kind,
		role,
		percent,
		advantage_percent,
		operation_kind,
		effect_magnitude,
		effect_duration
	)
	return definition if definition.is_valid() else null


static func _is_valid_input(
	effect_kind: int,
	role: int,
	percent: int,
	advantage_percent: int,
	operation_kind: int,
	effect_magnitude: int,
	effect_duration: int
) -> bool:
	if effect_kind not in [Kind.DAMAGE, Kind.KEYWORD, Kind.SPEED, Kind.OPTIONAL_SELF_MOVE]:
		return false
	if role not in [TargetRole.ACTOR, TargetRole.PRIMARY, TargetRole.ALL_SELECTED, TargetRole.HISTORY_ALLY]:
		return false
	match effect_kind:
		Kind.DAMAGE:
			return (
				role in [TargetRole.PRIMARY, TargetRole.ALL_SELECTED]
				and percent > 0
				and (advantage_percent == 0 or advantage_percent > percent)
				and effect_magnitude == 0
				and effect_duration == 0
			)
		Kind.KEYWORD:
			if advantage_percent != 0:
				return false
			if operation_kind not in [
				BattleKeywordOperation.Kind.ADD_ARMOR,
				BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
				BattleKeywordOperation.Kind.APPLY_SNARED,
				BattleKeywordOperation.Kind.APPLY_BLEED,
				BattleKeywordOperation.Kind.REDUCE_COOLDOWN,
			]:
				return false
			if operation_kind == BattleKeywordOperation.Kind.ADD_ARMOR:
				return effect_magnitude > 0 and effect_duration == 0
			if operation_kind in [
				BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
				BattleKeywordOperation.Kind.APPLY_SNARED,
				BattleKeywordOperation.Kind.APPLY_BLEED,
			]:
				return effect_magnitude == 0 and effect_duration > 0
			return effect_magnitude > 0 and effect_duration == 0
		Kind.SPEED:
			return (
				advantage_percent == 0
				and role in [TargetRole.ACTOR, TargetRole.PRIMARY, TargetRole.ALL_SELECTED]
				and effect_magnitude != 0
				and effect_duration > 0
			)
		Kind.OPTIONAL_SELF_MOVE:
			return (
				role == TargetRole.ACTOR
				and advantage_percent == 0
				and percent == 0
				and effect_magnitude == 0
				and effect_duration == 0
			)
	return false
