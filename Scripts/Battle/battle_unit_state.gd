class_name BattleUnitState
extends RefCounted

enum Side {
	PLAYER,
	ENEMY,
}

const DEFAULT_MAX_HP := 20

var unit_id: StringName
var display_name: String
var side: Side
var slot_index: int
var speed: int
var max_hp: int
var current_hp: int


func _init(
	id: StringName,
	name: String,
	unit_side: int,
	unit_slot_index: int,
	unit_speed: int,
	max_hp_value: int = DEFAULT_MAX_HP
) -> void:
	unit_id = id
	display_name = name
	side = unit_side
	slot_index = unit_slot_index
	speed = unit_speed
	max_hp = max_hp_value
	current_hp = max_hp_value


func is_active() -> bool:
	return current_hp > 0
