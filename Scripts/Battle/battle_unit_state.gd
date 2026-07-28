class_name BattleUnitState
extends RefCounted

enum Side {
	PLAYER,
	ENEMY,
}

var unit_id: StringName
var display_name: String
var side: Side
var slot_index: int
var speed: int


func _init(
	id: StringName,
	name: String,
	unit_side: int,
	unit_slot_index: int,
	unit_speed: int
) -> void:
	unit_id = id
	display_name = name
	side = unit_side
	slot_index = unit_slot_index
	speed = unit_speed
