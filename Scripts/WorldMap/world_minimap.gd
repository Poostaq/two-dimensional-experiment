class_name WorldMinimap
extends Control

const MINI_HEX_RADIUS := 8.0
const MAIN_TO_MINIMAP_SCALE := 0.1735
const CELL_COLORS := {
	"safe": Color("40584d"),
	"combat": Color("664141"),
	"boss": Color("613957"),
}
const HEX_DIRECTIONS := [
	Vector2(0.0, -1.0),
	Vector2(0.8660254, -0.5),
	Vector2(0.8660254, 0.5),
	Vector2(0.0, 1.0),
	Vector2(-0.8660254, 0.5),
	Vector2(-0.8660254, -0.5),
]

@onready var _surface: Node2D = %MapSurface
@onready var _cells: Node2D = %Cells
@onready var _towns: Node2D = %Towns
@onready var _player_icon: Sprite2D = %PlayerIcon
@onready var _player_label: Label = %PlayerLabel
@onready var _boss_icon: Sprite2D = %BossIcon
@onready var _boss_label: Label = %BossLabel
@onready var _camera_footprint: Line2D = %CameraFootprint

var _plan: WorldPlan
var _player_coord: Vector2i
var _boss_coord: Vector2i


func configure(plan: WorldPlan, player_coord: Vector2i, boss_coord: Vector2i) -> bool:
	if not is_instance_valid(plan) or WorldPlanCodecV1.validate(plan) != null:
		return false
	var cells := plan.get_cells()
	if cells.size() != 217 or not cells.has(player_coord) or not cells.has(boss_coord):
		return false
	_clear_children(_cells)
	_clear_children(_towns)
	_plan = plan
	_player_coord = player_coord
	_boss_coord = boss_coord
	for coord: Vector2i in HexWorldGeometry.get_canonical_coords(8):
		_add_cell(coord, cells[coord])
	_position_party_markers()
	update_camera_footprint(Rect2(-160.0, -120.0, 320.0, 240.0))
	return true


func update_camera_footprint(world_rect: Rect2) -> void:
	var top_left := _surface.position + world_rect.position * MAIN_TO_MINIMAP_SCALE
	var bottom_right := _surface.position + world_rect.end * MAIN_TO_MINIMAP_SCALE
	_camera_footprint.points = PackedVector2Array([
		top_left,
		Vector2(bottom_right.x, top_left.y),
		bottom_right,
		Vector2(top_left.x, bottom_right.y),
	])


func project_axial(coord: Vector2i) -> Vector2:
	var q := float(coord.x)
	var r := float(coord.y)
	return Vector2(
		MINI_HEX_RADIUS * sqrt(3.0) * (q + r * 0.5),
		MINI_HEX_RADIUS * 1.5 * r
	)


func get_cell_count() -> int:
	return _cells.get_child_count()


func get_town_count() -> int:
	return _towns.get_child_count()


func get_player_coord() -> Vector2i:
	return _player_coord


func get_boss_coord() -> Vector2i:
	return _boss_coord


func get_camera_footprint() -> PackedVector2Array:
	return _camera_footprint.points.duplicate()


func _add_cell(coord: Vector2i, data: Dictionary) -> void:
	var cell := Polygon2D.new()
	cell.name = "Cell_%d_%d" % [coord.x, coord.y]
	cell.position = _surface.position + project_axial(coord)
	cell.polygon = _hex_polygon(MINI_HEX_RADIUS - 0.8)
	cell.color = CELL_COLORS.get(String(data.get("encounter", "safe")), CELL_COLORS["safe"])
	_cells.add_child(cell)
	if int(data.get("town_index", -1)) >= 0:
		var town := Polygon2D.new()
		town.name = "Town_%d" % int(data["town_index"])
		town.position = cell.position
		town.polygon = PackedVector2Array([
			Vector2(-3.5, 3.0), Vector2(-3.5, -1.5), Vector2(0.0, -5.0),
			Vector2(3.5, -1.5), Vector2(3.5, 3.0),
		])
		town.color = Color("e2bb73")
		_towns.add_child(town)


func _position_party_markers() -> void:
	_player_icon.position = _surface.position + project_axial(_player_coord)
	_player_label.position = _player_icon.position + Vector2(-6.0, -7.0)
	_boss_icon.position = _surface.position + project_axial(_boss_coord)
	_boss_label.position = _boss_icon.position + Vector2(-6.0, -7.0)
	_player_icon.visible = true
	_player_label.visible = true
	_boss_icon.visible = true
	_boss_label.visible = true


func _hex_polygon(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for direction: Vector2 in HEX_DIRECTIONS:
		points.append(direction * radius)
	return points


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.free()
