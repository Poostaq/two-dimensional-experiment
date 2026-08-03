class_name ComboCondition
extends RefCounted

enum Type {
	TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND,
}

var condition_type: Type:
	get:
		return _condition_type

var _condition_type: Type = Type.TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND
var _is_valid: bool = false


func _init(type_value: int) -> void:
	if type_value != Type.TARGET_DAMAGED_BY_DIFFERENT_ALLY_SKILL_THIS_ROUND:
		push_error("ComboCondition requires a supported type.")
		return
	_condition_type = type_value as Type
	_is_valid = true


static func create(type_value: int) -> RefCounted:
	var condition: RefCounted = load("res://Scripts/Battle/combo_condition.gd").new(type_value)
	return condition if condition.is_valid() else null


func is_valid() -> bool:
	return _is_valid


func duplicate_condition() -> RefCounted:
	return load("res://Scripts/Battle/combo_condition.gd").new(_condition_type) if _is_valid else null
