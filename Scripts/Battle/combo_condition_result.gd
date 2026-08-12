class_name ComboConditionResult
extends RefCounted

var condition_type: int
var passed: bool
var relevant_target_ids: Array[StringName]:
	get:
		return _relevant_target_ids.duplicate()

var _relevant_target_ids: Array[StringName] = []


func _init(type_value: int, did_pass: bool, target_ids: Array) -> void:
	condition_type = type_value
	passed = did_pass
	for target_id: StringName in target_ids:
		_relevant_target_ids.append(target_id)
