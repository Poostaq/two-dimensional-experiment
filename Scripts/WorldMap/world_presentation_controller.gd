class_name WorldPresentationController
extends Node2D

static var CELL_SCENE: PackedScene = load("res://Scenes/world_cell_view.tscn")
const CELL_FLAT_WIDTH := 80.0
const CELL_POINT_HEIGHT := 92.0
const PREVIEW_SEED := "golden-alpha"

@export var auto_present_fixture: bool = true

@onready var _world_cells: Node2D = %WorldCells
@onready var _road_network: Node2D = %RoadNetwork
@onready var _world_camera: WorldCameraController = %WorldCamera
@onready var _minimap: WorldMinimap = %WorldMinimap
@onready var _hud: WorldMapHud = %WorldMapHud

var _plan: WorldPlan
var _player_coord: Vector2i
var _boss_coord: Vector2i


func _ready() -> void:
	if not auto_present_fixture:
		return
	var result := HexWorldGeneratorV1.new().generate(PREVIEW_SEED)
	if result.get("ok", false):
		present_plan(result["plan"])


func present_plan(plan: WorldPlan) -> bool:
	if not is_instance_valid(plan) or WorldPlanCodecV1.validate(plan) != null:
		return false
	var cells := plan.get_cells()
	if cells.size() != 217:
		return false
	var coords := HexWorldGeometry.get_canonical_coords(8)
	for coord: Vector2i in coords:
		if not cells.has(coord):
			return false
	_clear_children(_world_cells)
	_clear_children(_road_network)
	_plan = plan
	_player_coord = plan.get_start_coord()
	_boss_coord = plan.get_boss_coord()
	var roads := plan.get_roads()
	var road_topology := _build_road_topology(roads)
	for coord: Vector2i in coords:
		var road_edges: Array[Vector2i] = []
		if road_topology.has(coord):
			road_edges.assign(road_topology[coord])
		_add_world_cell(coord, cells[coord], road_edges)
	_add_roads(roads)
	var world_rect := _calculate_world_rect(coords)
	_world_camera.configure(world_rect, Vector2(1152.0, 648.0), CELL_FLAT_WIDTH)
	_world_camera.center_on(axial_to_world(_player_coord))
	if not _minimap.configure(plan, _player_coord, _boss_coord):
		return false
	if not _world_camera.view_changed.is_connected(_on_camera_view_changed):
		_world_camera.view_changed.connect(_on_camera_view_changed)
	_on_camera_view_changed(_world_camera.get_visible_world_rect())
	_hud.set_turn_state(0, false)
	var empty_formation: Array[RunCharacter] = []
	empty_formation.resize(6)
	_hud.set_formation(empty_formation)
	var terrain_tags: Array[String] = []
	_hud.set_context("safe", terrain_tags, false)
	_hud.set_party_available(true)
	return true


func _on_camera_view_changed(visible_world_rect: Rect2) -> void:
	_minimap.update_camera_footprint(visible_world_rect)


func axial_to_world(coord: Vector2i) -> Vector2:
	return Vector2(
		CELL_FLAT_WIDTH * (float(coord.x) + float(coord.y) * 0.5),
		CELL_POINT_HEIGHT * 0.75 * float(coord.y)
	)


func is_plan_presented() -> bool:
	return is_instance_valid(_plan) and _world_cells.get_child_count() == 217


func get_main_cell_count() -> int:
	return _world_cells.get_child_count()


func get_forest_cluster_count() -> int:
	return _plan.get_forest_clusters().size() if is_instance_valid(_plan) else 0


func get_town_count() -> int:
	return _minimap.get_town_count()


func get_road_count() -> int:
	return _road_network.get_child_count()


func get_player_coord() -> Vector2i:
	return _player_coord


func get_boss_coord() -> Vector2i:
	return _boss_coord


func get_plan_instance_id() -> int:
	return _plan.get_instance_id() if is_instance_valid(_plan) else 0


func _add_world_cell(coord: Vector2i, data: Dictionary, road_edges: Array[Vector2i]) -> void:
	var cell := CELL_SCENE.instantiate() as WorldCellView
	cell.name = "WorldCell_%d_%d" % [coord.x, coord.y]
	cell.position = axial_to_world(coord)
	_world_cells.add_child(cell)
	cell.configure(
		coord,
		String(data.get("encounter", "safe")).capitalize(),
		String(data.get("terrain", "plain")),
		road_edges,
		int(data.get("town_index", -1)) >= 0
	)
	if coord == _player_coord:
		cell.set_party_marker("player")
	elif coord == _boss_coord:
		cell.set_party_marker("boss")


func _build_road_topology(roads: Array) -> Dictionary:
	var topology := {}
	for edge_value: Variant in roads:
		var edge: Dictionary = edge_value
		var current: Vector2i = edge["a"]
		var destination: Vector2i = edge["b"]
		while current != destination:
			var next_coord := current
			var current_distance := HexWorldGeometry.get_hex_distance(current, destination)
			for neighbor: Vector2i in HexWorldGeometry.get_neighbors(current, 8):
				if HexWorldGeometry.get_hex_distance(neighbor, destination) < current_distance:
					next_coord = neighbor
					break
			if next_coord == current:
				break
			_append_road_direction(topology, current, next_coord - current)
			_append_road_direction(topology, next_coord, current - next_coord)
			current = next_coord
	return topology


func _append_road_direction(topology: Dictionary, coord: Vector2i, direction: Vector2i) -> void:
	var directions: Array[Vector2i] = []
	if topology.has(coord):
		directions.assign(topology[coord])
	if not directions.has(direction):
		directions.append(direction)
	topology[coord] = directions


func _add_roads(roads: Array) -> void:
	for index: int in range(roads.size()):
		var edge: Dictionary = roads[index]
		var route := Node2D.new()
		route.name = "Road_%d" % index
		route.set_meta("start_coord", edge["a"])
		route.set_meta("end_coord", edge["b"])
		_road_network.add_child(route)


func _calculate_world_rect(coords: Array[Vector2i]) -> Rect2:
	var first := axial_to_world(coords[0])
	var minimum := first
	var maximum := first
	for coord: Vector2i in coords:
		var point := axial_to_world(coord)
		minimum = minimum.min(point)
		maximum = maximum.max(point)
	var margin := Vector2(CELL_FLAT_WIDTH * 0.6, CELL_POINT_HEIGHT * 0.6)
	return Rect2(minimum - margin, maximum - minimum + margin * 2.0)


func _clear_children(parent: Node) -> void:
	for child: Node in parent.get_children():
		child.free()
