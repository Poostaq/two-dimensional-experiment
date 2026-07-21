class_name HexTileView
extends Node2D

const STATE_DEFAULT := "default"
const STATE_VALID_MOVE := "valid_move"
const STATE_PLAYER := "player"
const STATE_BOSS := "boss"

@onready var _fill: Polygon2D = $Fill
@onready var _outline: Line2D = $Outline
@onready var _coord_label: Label = $CoordLabel

var coordinate := Vector2i.ZERO


func configure(coord: Vector2i, show_debug_label: bool = false) -> void:
	coordinate = coord
	_coord_label.text = "%d,%d" % [coordinate.x, coordinate.y]
	_coord_label.visible = show_debug_label
	set_display_state(STATE_DEFAULT)


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
		_:
			_fill.color = Color(0.24, 0.28, 0.34, 1.0)
			_outline.default_color = Color(0.56, 0.63, 0.72, 1.0)
