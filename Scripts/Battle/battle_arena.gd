class_name BattleArena
extends Control

signal exit_requested

const SIDE_SLOT_COUNT := 6

@onready var _encounter_type_label: Label = %EncounterTypeLabel
@onready var _player_formation: GridContainer = %PlayerFormation
@onready var _enemy_formation: GridContainer = %EnemyFormation
@onready var _exit_debug_button: Button = %ExitBattleDebugButton

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""


func _ready() -> void:
	var exit_callable := Callable(self, "_on_exit_debug_pressed")
	if not _exit_debug_button.pressed.is_connected(exit_callable):
		_exit_debug_button.pressed.connect(exit_callable)
	_assign_slot_metadata(_player_formation, "player")
	_assign_slot_metadata(_enemy_formation, "enemy")
	_refresh_context()


func configure(coordinate: Vector2i, type: String) -> void:
	if type != HexMapModel.ENCOUNTER_COMBAT and type != HexMapModel.ENCOUNTER_BOSS:
		return
	encounter_coordinate = coordinate
	encounter_type = type
	if is_node_ready():
		_refresh_context()


func get_player_slots() -> Array[Control]:
	return _get_control_children(_player_formation)


func get_enemy_slots() -> Array[Control]:
	return _get_control_children(_enemy_formation)


func _get_control_children(formation: GridContainer) -> Array[Control]:
	var slots: Array[Control] = []
	for child: Node in formation.get_children():
		if child is Control:
			slots.append(child as Control)
	return slots


func _assign_slot_metadata(formation: GridContainer, side: String) -> void:
	var slots := _get_control_children(formation)
	for index: int in slots.size():
		slots[index].set_meta("side", side)
		slots[index].set_meta("slot_index", index)


func _refresh_context() -> void:
	if encounter_type.is_empty():
		_encounter_type_label.text = "Battle"
		return
	_encounter_type_label.text = "%s Battle" % encounter_type.capitalize()


func _on_exit_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	call_deferred("_emit_exit_requested")


func _emit_exit_requested() -> void:
	exit_requested.emit()
