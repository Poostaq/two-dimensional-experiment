class_name NavigationHelp
extends Control

const CENTER := Vector2(110.0, 82.0)
const HEX_RADIUS := 30.0
const HEX_FILL := Color(0.18, 0.22, 0.28, 0.9)
const HEX_OUTLINE := Color(0.72, 0.82, 0.96, 1.0)
const PANEL_FILL := Color(0.05, 0.06, 0.08, 0.62)
const PANEL_OUTLINE := Color(0.45, 0.55, 0.68, 0.85)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_FILL, true)
	draw_rect(Rect2(Vector2.ZERO, size), PANEL_OUTLINE, false, 2.0)

	var points: PackedVector2Array = _build_hex_points(CENTER, HEX_RADIUS)
	draw_colored_polygon(points, HEX_FILL)
	var outline: PackedVector2Array = points
	outline.append(points[0])
	draw_polyline(outline, HEX_OUTLINE, 3.0, true)


func _build_hex_points(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(6):
		var angle := deg_to_rad(60.0 * float(index) - 30.0)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points
