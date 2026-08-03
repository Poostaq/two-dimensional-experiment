class_name ComboBonusEffect
extends RefCounted

enum Type {
	BONUS_DAMAGE,
}

var effect_type: Type:
	get:
		return _effect_type
var magnitude: int:
	get:
		return _magnitude

var _effect_type: Type = Type.BONUS_DAMAGE
var _magnitude: int = 0
var _is_valid: bool = false


func _init(type_value: int, magnitude_value: int) -> void:
	if type_value != Type.BONUS_DAMAGE or magnitude_value <= 0:
		push_error("ComboBonusEffect requires a supported type and positive magnitude.")
		return
	_effect_type = type_value as Type
	_magnitude = magnitude_value
	_is_valid = true


static func create(type_value: int, magnitude_value: int) -> RefCounted:
	var effect: RefCounted = load("res://Scripts/Battle/combo_bonus_effect.gd").new(type_value, magnitude_value)
	return effect if effect.is_valid() else null


func is_valid() -> bool:
	return _is_valid


func duplicate_effect() -> RefCounted:
	return load("res://Scripts/Battle/combo_bonus_effect.gd").new(_effect_type, _magnitude) if _is_valid else null
