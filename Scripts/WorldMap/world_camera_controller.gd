class_name WorldCameraController
extends Camera2D

const MIN_HEXES_ACROSS := 3.0
const DEFAULT_HEXES_ACROSS := 5.0
const MAX_HEXES_ACROSS := 11.0
const ZOOM_STEP_FACTOR := 1.12

var _world_rect: Rect2
var _viewport_size: Vector2
var _cell_flat_width: float = 1.0
var _hexes_across: float = DEFAULT_HEXES_ACROSS
var _dragging: bool = false
var _last_drag_position: Vector2


func configure(world_rect: Rect2, viewport_size: Vector2, cell_flat_width: float) -> void:
	_world_rect = world_rect
	_viewport_size = viewport_size
	_cell_flat_width = maxf(cell_flat_width, 1.0)
	position = _world_rect.get_center()
	set_default_zoom()


func set_default_zoom() -> void:
	_set_hexes_across(DEFAULT_HEXES_ACROSS)
	_clamp_position()


func zoom_by_steps(steps: int, anchor: Vector2) -> void:
	if steps == 0:
		return
	var old_zoom := zoom.x
	var multiplier := pow(ZOOM_STEP_FACTOR, float(-steps))
	var requested := clampf(_hexes_across * multiplier, MIN_HEXES_ACROSS, MAX_HEXES_ACROSS)
	var world_anchor := position + (anchor - _viewport_size * 0.5) / old_zoom
	_set_hexes_across(requested)
	position = world_anchor - (anchor - _viewport_size * 0.5) / zoom.x
	_clamp_position()


func pan_by(pointer_delta: Vector2) -> void:
	position -= pointer_delta / zoom.x
	_clamp_position()


func begin_drag(pointer_position: Vector2) -> void:
	_dragging = true
	_last_drag_position = pointer_position


func drag_to(pointer_position: Vector2) -> void:
	if not _dragging:
		return
	pan_by(pointer_position - _last_drag_position)
	_last_drag_position = pointer_position


func end_drag() -> void:
	_dragging = false


func is_dragging() -> bool:
	return _dragging


func get_hexes_across() -> float:
	return _hexes_across


func get_visible_world_rect() -> Rect2:
	var visible_size := _viewport_size / zoom.x
	return Rect2(position - visible_size * 0.5, visible_size)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event := event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_WHEEL_UP and button_event.pressed:
			zoom_by_steps(1, button_event.position)
		elif button_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and button_event.pressed:
			zoom_by_steps(-1, button_event.position)
		elif button_event.button_index == MOUSE_BUTTON_LEFT:
			if button_event.pressed:
				begin_drag(button_event.position)
			else:
				end_drag()
	elif event is InputEventMouseMotion and _dragging:
		drag_to((event as InputEventMouseMotion).position)


func _set_hexes_across(value: float) -> void:
	_hexes_across = clampf(value, MIN_HEXES_ACROSS, MAX_HEXES_ACROSS)
	var zoom_value := _viewport_size.x / (_hexes_across * _cell_flat_width)
	zoom = Vector2.ONE * zoom_value


func _clamp_position() -> void:
	var half_visible := (_viewport_size / zoom.x) * 0.5
	var minimum := _world_rect.position + half_visible
	var maximum := _world_rect.end - half_visible
	if minimum.x > maximum.x:
		position.x = _world_rect.get_center().x
	else:
		position.x = clampf(position.x, minimum.x, maximum.x)
	if minimum.y > maximum.y:
		position.y = _world_rect.get_center().y
	else:
		position.y = clampf(position.y, minimum.y, maximum.y)
