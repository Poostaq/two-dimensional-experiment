class_name HexTileView
extends Node2D

signal tile_selected(coordinate: Vector2i)
signal hover_changed(coordinate: Vector2i, is_hovered: bool)

const STATE_DEFAULT := "default"
const STATE_SAFE := "safe"
const STATE_COMBAT := "combat"
const STATE_VALID_MOVE := "valid_move"
const STATE_PLAYER := "player"
const STATE_BOSS := "boss"
const HOVER_WIDTH_MULTIPLIER := 1.75

@onready var _fill: Polygon2D = $Fill
@onready var _outline: Line2D = $Outline
@onready var _coord_label: Label = $CoordLabel

var coordinate: Vector2i = Vector2i.ZERO
var _default_outline_width: float = 0.0
var _is_hovered: bool = false


func _ready() -> void:
	_default_outline_width = _outline.width


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(_contains_viewport_point(event.position))
		return

	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT or not event.pressed:
			return
		if not _contains_viewport_point(event.position):
			return

		tile_selected.emit(coordinate)
		get_viewport().set_input_as_handled()


func configure(coord: Vector2i, show_debug_label: bool = false) -> void:
	coordinate = coord
	_coord_label.text = "%d,%d" % [coordinate.x, coordinate.y]
	_coord_label.visible = show_debug_label
	set_display_state(STATE_SAFE)


func set_display_state(state: String) -> void:
	match state:
		STATE_PLAYER:
			_fill.color = Color(0.15, 0.72, 0.95, 1.0)
			_outline.default_color = Color(0.88, 0.98, 1.0, 1.0)
		STATE_BOSS:
			_fill.color = Color(0.85, 0.18, 0.22, 1.0)
			_outline.default_color = Color(1.0, 0.78, 0.18, 1.0)
		STATE_VALID_MOVE:
			_fill.color = Color(0.36, 0.72, 0.38, 1.0)
			_outline.default_color = Color(0.8, 1.0, 0.62, 1.0)
		STATE_COMBAT:
			_fill.color = Color(0.72, 0.34, 0.22, 1.0)
			_outline.default_color = Color(1.0, 0.74, 0.36, 1.0)
		STATE_SAFE:
			_fill.color = Color(0.24, 0.28, 0.34, 1.0)
			_outline.default_color = Color(0.56, 0.63, 0.72, 1.0)
		_:
			_fill.color = Color(0.18, 0.2, 0.24, 1.0)
			_outline.default_color = Color(0.42, 0.46, 0.52, 1.0)


func _contains_viewport_point(viewport_point: Vector2) -> bool:
	var local_point: Vector2 = get_global_transform_with_canvas().affine_inverse() * viewport_point
	return Geometry2D.is_point_in_polygon(local_point, _fill.polygon)


func _set_hovered(value: bool) -> void:
	if _is_hovered == value:
		return

	_is_hovered = value
	_outline.width = _default_outline_width * HOVER_WIDTH_MULTIPLIER if value else _default_outline_width
	hover_changed.emit(coordinate, _is_hovered)
