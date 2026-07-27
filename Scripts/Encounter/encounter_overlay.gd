class_name EncounterOverlay
extends CanvasLayer

signal close_requested
signal battle_requested(coordinate: Vector2i, encounter_type: String)

@onready var _encounter_type_label: Label = %EncounterTypeLabel
@onready var _close_debug_button: Button = $InputBlocker/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseDebugButton
@onready var _enter_battle_button: Button = %EnterBattleButton

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""


func _ready() -> void:
	var close_callable := Callable(self, "_on_close_debug_pressed")
	if not _close_debug_button.pressed.is_connected(close_callable):
		_close_debug_button.pressed.connect(close_callable)
	var battle_callable := Callable(self, "_on_enter_battle_pressed")
	if not _enter_battle_button.pressed.is_connected(battle_callable):
		_enter_battle_button.pressed.connect(battle_callable)
	_refresh_text()
	_refresh_actions()


func configure(coordinate: Vector2i, type: String) -> void:
	encounter_coordinate = coordinate
	encounter_type = type
	if is_node_ready():
		_refresh_text()
		_refresh_actions()


func can_enter_battle() -> bool:
	return encounter_type == HexMapModel.ENCOUNTER_COMBAT or encounter_type == HexMapModel.ENCOUNTER_BOSS


func _refresh_text() -> void:
	_encounter_type_label.text = encounter_type.capitalize()


func _refresh_actions() -> void:
	var eligible := can_enter_battle()
	_enter_battle_button.visible = eligible
	_enter_battle_button.disabled = not eligible


func _on_enter_battle_pressed() -> void:
	if not can_enter_battle():
		return
	get_viewport().set_input_as_handled()
	call_deferred("_emit_battle_requested")


func _emit_battle_requested() -> void:
	if can_enter_battle():
		battle_requested.emit(encounter_coordinate, encounter_type)


func _on_close_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	call_deferred("_emit_close_requested")


func _emit_close_requested() -> void:
	close_requested.emit()
