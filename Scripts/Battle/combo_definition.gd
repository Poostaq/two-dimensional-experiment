class_name ComboDefinition
extends RefCounted

const CONDITION_PATH := "res://Scripts/Battle/combo_condition.gd"
const BONUS_EFFECT_PATH := "res://Scripts/Battle/combo_bonus_effect.gd"

var conditions: Array[RefCounted]:
	get:
		return _duplicate_conditions()
var bonus_effects: Array[RefCounted]:
	get:
		return _duplicate_effects()
var description_text: String:
	get:
		return _description_text

var _conditions: Array[RefCounted] = []
var _bonus_effects: Array[RefCounted] = []
var _description_text: String = ""
var _is_valid: bool = false


func _init(condition_values: Array, effect_values: Array, description: String) -> void:
	if condition_values.is_empty() or effect_values.is_empty() or description.strip_edges().is_empty():
		push_error("ComboDefinition requires conditions, effects, and description text.")
		return
	for value: Variant in condition_values:
		if (
			not value is RefCounted
			or value.get_script().resource_path != CONDITION_PATH
			or not value.is_valid()
		):
			push_error("ComboDefinition requires valid conditions.")
			return
	for value: Variant in effect_values:
		if (
			not value is RefCounted
			or value.get_script().resource_path != BONUS_EFFECT_PATH
			or not value.is_valid()
		):
			push_error("ComboDefinition requires valid bonus effects.")
			return
	for value: RefCounted in condition_values:
		_conditions.append(value.duplicate_condition())
	for value: RefCounted in effect_values:
		_bonus_effects.append(value.duplicate_effect())
	_description_text = description
	_is_valid = true


static func create(
	condition_values: Array,
	effect_values: Array,
	description: String
) -> RefCounted:
	var definition: RefCounted = load("res://Scripts/Battle/combo_definition.gd").new(condition_values, effect_values, description)
	return definition if definition.is_valid() else null


func is_valid() -> bool:
	return _is_valid


func duplicate_definition() -> RefCounted:
	return load("res://Scripts/Battle/combo_definition.gd").new(_conditions, _bonus_effects, _description_text) if _is_valid else null


func _duplicate_conditions() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for condition: RefCounted in _conditions:
		result.append(condition.duplicate_condition())
	return result


func _duplicate_effects() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for effect: RefCounted in _bonus_effects:
		result.append(effect.duplicate_effect())
	return result
