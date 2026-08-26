class_name WorldAutosaveFailureOverlay
extends Control

signal retry_requested
signal return_requested
signal diagnostics_copied(diagnostics: String)

@onready var _message: Label = %FailureMessage
@onready var _diagnostics: TextEdit = %DiagnosticsText
@onready var _retry_button: Button = %RetryButton
@onready var _return_button: Button = %ReturnButton
@onready var _copy_button: Button = %CopyButton

var _diagnostics_text: String = ""


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    get_viewport().size_changed.connect(_fit_to_viewport)
    _fit_to_viewport()
    _retry_button.pressed.connect(_on_retry_pressed)
    _return_button.pressed.connect(_on_return_pressed)
    _copy_button.pressed.connect(_on_copy_pressed)
    hide()


func _fit_to_viewport() -> void:
    position = Vector2.ZERO
    size = get_viewport_rect().size


func present(error: RefCounted, build_version: String) -> void:
    _message.text = "Autosave failed. Authoritative input is paused."
    _diagnostics_text = WorldFailureFormatter.format_json_line(error, build_version).strip_edges()
    _diagnostics.text = _diagnostics_text
    show()
    _retry_button.grab_focus()


func dismiss() -> void:
    hide()


func get_diagnostics_text() -> String:
    return _diagnostics_text


func _on_retry_pressed() -> void:
    retry_requested.emit()


func _on_return_pressed() -> void:
    return_requested.emit()


func _on_copy_pressed() -> void:
    DisplayServer.clipboard_set(_diagnostics_text)
    diagnostics_copied.emit(_diagnostics_text)
