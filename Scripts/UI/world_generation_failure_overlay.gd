class_name WorldGenerationFailureOverlay
extends Control

signal return_requested
signal diagnostics_copied(diagnostics: String)

const FAILURE_MESSAGE := "World generation failed. The run was not started."

@onready var _dimmer: ColorRect = $Dimmer
@onready var _center: CenterContainer = $Center
@onready var _failure_message: Label = %FailureMessage
@onready var _return_button: Button = %ReturnButton
@onready var _copy_diagnostics_button: Button = %CopyDiagnosticsButton

var _diagnostics_text: String = ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_failure_message.text = FAILURE_MESSAGE
	hide()
	get_viewport().size_changed.connect(_fit_to_viewport)
	call_deferred("_fit_to_viewport")
	_return_button.pressed.connect(_on_return_pressed)
	_copy_diagnostics_button.pressed.connect(_on_copy_diagnostics_pressed)


func _fit_to_viewport() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func present(error: WorldGenerationError, build_version: String) -> void:
	_diagnostics_text = WorldFailureFormatter.format_json_line(error, build_version).strip_edges()
	show()
	_return_button.grab_focus()


func get_diagnostics_text() -> String:
	return _diagnostics_text


func _on_return_pressed() -> void:
	hide()
	return_requested.emit()


func _on_copy_diagnostics_pressed() -> void:
	DisplayServer.clipboard_set(_diagnostics_text)
	diagnostics_copied.emit(_diagnostics_text)
