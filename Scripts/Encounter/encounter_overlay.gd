class_name EncounterOverlay
extends CanvasLayer

signal close_requested

@onready var _encounter_type_label: Label = %EncounterTypeLabel
@onready var _close_debug_button: Button = $InputBlocker/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/CloseDebugButton

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""


func _ready() -> void:
	var close_callable := Callable(self, "_on_close_debug_pressed")
	if not _close_debug_button.pressed.is_connected(close_callable):
		_close_debug_button.pressed.connect(close_callable)
	_refresh_text()


func configure(coordinate: Vector2i, type: String) -> void:
	encounter_coordinate = coordinate
	encounter_type = type
	if is_node_ready():
		_refresh_text()


func _refresh_text() -> void:
	_encounter_type_label.text = encounter_type.capitalize()


func _on_close_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	call_deferred("_emit_close_requested")


func _emit_close_requested() -> void:
	close_requested.emit()
