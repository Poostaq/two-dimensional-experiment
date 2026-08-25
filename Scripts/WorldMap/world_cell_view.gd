class_name WorldCellView
extends Node2D

const CELL_FLAT_WIDTH := 80.0
const CELL_POINT_HEIGHT := 92.0
const MARKER_OUTLINE_WIDTH := 2.0
const ENCOUNTER_COLORS := {
	"Safe": Color("526b5b"),
	"Combat": Color("754b4b"),
	"Boss": Color("6f3d65"),
}

@onready var _encounter_fill: Polygon2D = $EncounterBase/Fill
@onready var _terrain_fill: Polygon2D = $TerrainLayer/ForestFill
@onready var _road_lines: Node2D = $RoadLayer/RoadLines
@onready var _town_buildings: Node2D = $TownLayer/Buildings
@onready var _highlight_outline: Line2D = $HighlightLayer/Outline
@onready var _marker_plate: Polygon2D = $MarkerLayer/Plate
@onready var _marker_outline: Line2D = $MarkerLayer/Outline
@onready var _party_marker: Sprite2D = $MarkerLayer/PartyIcon
@onready var _party_label: Label = $ContextLayer/PartyLabel

var coordinate: Vector2i
var encounter_type: String = "Safe"
var terrain_type: String = ""
var is_town: bool = false


func configure(
	coord: Vector2i,
	cell_encounter_type: String,
	terrain: String,
	road_edges: Array[Vector2i],
	cell_is_town: bool
) -> void:
	coordinate = coord
	encounter_type = cell_encounter_type
	terrain_type = terrain
	is_town = cell_is_town
	_encounter_fill.color = ENCOUNTER_COLORS.get(encounter_type, ENCOUNTER_COLORS["Safe"])
	_terrain_fill.visible = terrain_type == "forest"
	_town_buildings.visible = is_town
	_configure_roads(road_edges)


func set_highlighted(value: bool) -> void:
	_highlight_outline.visible = value


func set_party_marker(kind: String) -> void:
	var normalized := kind.to_lower()
	var has_marker := normalized == "player" or normalized == "boss"
	_marker_plate.visible = has_marker
	_marker_outline.visible = has_marker
	_party_marker.visible = has_marker
	_party_label.visible = has_marker
	if not has_marker:
		return
	var is_player := normalized == "player"
	_party_marker.modulate = Color("55d879") if is_player else Color("ef5b62")
	_party_label.text = "P" if is_player else "B"
	_party_label.tooltip_text = "Player Party" if is_player else "Boss Party"


func road_corridor_width(flat_width: float) -> float:
	return maxf(4.0, ceilf(0.20 * flat_width))


func town_footprint(flat_width: float, point_height: float) -> Rect2:
	return Rect2(
		-0.30 * flat_width,
		-0.25 * point_height,
		0.60 * flat_width,
		0.50 * point_height
	)


func marker_plate_diameter(flat_width: float, point_height: float) -> float:
	return ceilf(0.44 * minf(flat_width, point_height))


func marker_silhouette_diameter(flat_width: float, point_height: float) -> float:
	return 0.38 * minf(flat_width, point_height)


func marker_outline_width() -> float:
	return MARKER_OUTLINE_WIDTH


func _configure_roads(road_edges: Array[Vector2i]) -> void:
	for child: Node in _road_lines.get_children():
		child.free()
	for direction: Vector2i in road_edges:
		var line := Line2D.new()
		line.width = road_corridor_width(CELL_FLAT_WIDTH)
		line.default_color = Color("c8a66a")
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		line.add_point(Vector2.ZERO)
		line.add_point(_axial_direction_to_point(direction))
		_road_lines.add_child(line)


func _axial_direction_to_point(direction: Vector2i) -> Vector2:
	var x := CELL_FLAT_WIDTH * (float(direction.x) + float(direction.y) * 0.5)
	var y := CELL_POINT_HEIGHT * 0.75 * float(direction.y)
	return Vector2(x, y).normalized() * CELL_FLAT_WIDTH * 0.52
