class_name BattleKeywordOperation
extends RefCounted

enum Kind {
	ADD_ARMOR,
	APPLY_ADVANTAGE,
	APPLY_SNARED,
	APPLY_BLEED,
	REDUCE_COOLDOWN,
}

var kind: Kind:
	get:
		return _kind
var target_id: StringName:
	get:
		return _target_id
var magnitude: int:
	get:
		return _magnitude
var duration: int:
	get:
		return _duration
var source: RefCounted:
	get:
		return _source.call("duplicate_source") if is_instance_valid(_source) else null
var affected_skill_id: StringName:
	get:
		return _affected_skill_id
var arms_snared_follow_up: bool:
	get:
		return _arms_snared_follow_up

var _kind: Kind = Kind.ADD_ARMOR
var _target_id: StringName = &""
var _magnitude: int = 0
var _duration: int = 0
var _source: RefCounted = null
var _affected_skill_id: StringName = &""
var _arms_snared_follow_up: bool = false


func _init(
	operation_kind: int,
	operation_target_id: StringName,
	operation_magnitude: int = 0,
	operation_duration: int = 0,
	operation_source: RefCounted = null,
	operation_affected_skill_id: StringName = &"",
	arm_snared_follow_up: bool = false
) -> void:
	if not _is_valid_input(
		operation_kind,
		operation_target_id,
		operation_magnitude,
		operation_duration,
		operation_source,
		operation_affected_skill_id,
		arm_snared_follow_up
	):
		push_error("BattleKeywordOperation requires valid kind, target, magnitude, duration, and source data.")
		return
	_kind = operation_kind as Kind
	_target_id = operation_target_id
	_magnitude = operation_magnitude
	_duration = operation_duration
	_source = operation_source.call("duplicate_source") if is_instance_valid(operation_source) else null
	_affected_skill_id = operation_affected_skill_id
	_arms_snared_follow_up = arm_snared_follow_up


static func create(
	operation_kind: int,
	operation_target_id: StringName,
	operation_magnitude: int = 0,
	operation_duration: int = 0,
	operation_source: RefCounted = null,
	operation_affected_skill_id: StringName = &"",
	arm_snared_follow_up: bool = false
) -> RefCounted:
	var operation: RefCounted = load("res://Scripts/Battle/battle_keyword_operation.gd").new(
		operation_kind,
		operation_target_id,
		operation_magnitude,
		operation_duration,
		operation_source,
		operation_affected_skill_id,
		arm_snared_follow_up
	)
	return operation if operation.is_valid() else null


func is_valid() -> bool:
	return not _target_id.is_empty()


func duplicate_operation() -> RefCounted:
	if not is_valid():
		return null
	var operation_script := load("res://Scripts/Battle/battle_keyword_operation.gd") as Script
	return operation_script.call("create", _kind, _target_id, _magnitude, _duration, _source, _affected_skill_id, _arms_snared_follow_up)


func with_target(resolved_target_id: StringName) -> RefCounted:
	if resolved_target_id.is_empty() or not is_valid():
		return null
	var operation_script := load("res://Scripts/Battle/battle_keyword_operation.gd") as Script
	return operation_script.call(
		"create",
		_kind,
		resolved_target_id,
		_magnitude,
		_duration,
		_source,
		_affected_skill_id,
		_arms_snared_follow_up
	)


static func _is_valid_input(
	operation_kind: int,
	operation_target_id: StringName,
	operation_magnitude: int,
	operation_duration: int,
	operation_source: RefCounted,
	operation_affected_skill_id: StringName,
	arm_snared_follow_up: bool
) -> bool:
	if operation_kind not in [
		Kind.ADD_ARMOR,
		Kind.APPLY_ADVANTAGE,
		Kind.APPLY_SNARED,
		Kind.APPLY_BLEED,
		Kind.REDUCE_COOLDOWN,
	] or operation_target_id.is_empty():
		return false
	if arm_snared_follow_up and operation_kind != Kind.APPLY_SNARED:
		return false
	match operation_kind:
		Kind.ADD_ARMOR:
			return operation_magnitude > 0 and operation_duration >= 0
		Kind.APPLY_ADVANTAGE, Kind.APPLY_SNARED, Kind.APPLY_BLEED:
			return operation_duration > 0 and _is_valid_keyword_source(operation_source)
		Kind.REDUCE_COOLDOWN:
			return operation_magnitude > 0 and operation_duration == 0 and not operation_affected_skill_id.is_empty()
	return false


static func _is_valid_keyword_source(candidate: RefCounted) -> bool:
	return (
		is_instance_valid(candidate)
		and candidate.has_method("is_valid")
		and candidate.has_method("duplicate_source")
		and candidate.call("is_valid")
	)
