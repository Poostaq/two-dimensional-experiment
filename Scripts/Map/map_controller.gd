class_name MapController
extends Node2D

const HEX_MAP_MODEL_PATH := "res://Scripts/Map/hex_map_model.gd"
const TILE_SCENE_PATH := "res://Scenes/map_hex_tile.tscn"
const TILE_RADIUS := 38.0
const TILE_SPACING := 1.08
const TILE_STATE_DEFAULT := "default"
const TILE_STATE_VALID_MOVE := "valid_move"
const TILE_STATE_PLAYER := "player"
const TILE_STATE_SAFE := "safe"
const TILE_STATE_COMBAT := "combat"
const TILE_STATE_BOSS := "boss"
const DEFAULT_RUN_ID := "default-run"
const ACTION_OFFSETS := {
	"map_move_e": Vector2i(1, 0),
	"map_move_ne": Vector2i(1, -1),
	"map_move_nw": Vector2i(0, -1),
	"map_move_w": Vector2i(-1, 0),
	"map_move_sw": Vector2i(-1, 1),
	"map_move_se": Vector2i(0, 1),
}

@onready var _map_root: Node2D = $MapRoot
@onready var _player_marker: Node2D = $MapRoot/PlayerMarker
@onready var _boss_marker: Node2D = $MapRoot/BossMarker

var player_coord: Vector2i = Vector2i.ZERO
var boss_coord: Vector2i = Vector2i.ZERO
var move_count: int = 0
var run_id: String = DEFAULT_RUN_ID
var encounter_types: Dictionary = {}

var _model: HexMapModel
var _tile_scene: PackedScene
var _tiles: Dictionary = {}


func _ready() -> void:
	var model_script := load(HEX_MAP_MODEL_PATH) as Script
	_model = model_script.new() as HexMapModel
	_tile_scene = load(TILE_SCENE_PATH) as PackedScene

	player_coord = _model.get_start_coord()
	boss_coord = _model.get_boss_coord()
	encounter_types = _model.get_encounter_types_for_run(run_id)

	_build_tiles()
	_refresh_visual_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	for action: String in ACTION_OFFSETS.keys():
		if event.is_action_pressed(action):
			try_move_by_offset(ACTION_OFFSETS[action])
			get_viewport().set_input_as_handled()
			return


func set_run_id(value: String) -> void:
	run_id = DEFAULT_RUN_ID if value.is_empty() else value
	if _model == null:
		return

	encounter_types = _model.get_encounter_types_for_run(run_id)
	_refresh_visual_state()


func get_encounter_layout() -> Dictionary:
	return encounter_types.duplicate()


func get_encounter_type_at(coord: Vector2i) -> String:
	if not encounter_types.has(coord):
		return HexMapModel.ENCOUNTER_NONE
	return encounter_types[coord]


func try_move_by_offset(offset: Vector2i) -> bool:
	return request_move(player_coord + offset)


func request_move(destination: Vector2i) -> bool:
	if not _model.is_valid_coord(destination):
		return false
	if not _model.are_adjacent(player_coord, destination):
		return false

	player_coord = destination
	move_count += 1
	_refresh_visual_state()
	return true


func axial_to_world(coord: Vector2i) -> Vector2:
	var radius := TILE_RADIUS * TILE_SPACING
	var x := sqrt(3.0) * radius * (float(coord.x) + float(coord.y) * 0.5)
	var y := 1.5 * radius * float(coord.y)
	return Vector2(x, y)


func _build_tiles() -> void:
	for child: Node in _map_root.get_children():
		if child != _player_marker and child != _boss_marker:
			child.queue_free()
	_tiles.clear()

	for coord: Vector2i in _model.get_all_coords():
		var tile := _tile_scene.instantiate()
		_map_root.add_child(tile)
		_map_root.move_child(tile, 0)
		tile.position = axial_to_world(coord)
		tile.configure(coord)
		_tiles[coord] = tile


func _refresh_visual_state() -> void:
	var valid_destinations: Dictionary = {}
	for coord: Vector2i in _model.get_neighbors(player_coord):
		valid_destinations[coord] = true

	for coord: Vector2i in _tiles.keys():
		var tile: Node = _tiles[coord]
		if coord == player_coord:
			tile.set_display_state(TILE_STATE_PLAYER)
		elif coord == boss_coord:
			tile.set_display_state(TILE_STATE_BOSS)
		elif valid_destinations.has(coord):
			tile.set_display_state(TILE_STATE_VALID_MOVE)
		else:
			tile.set_display_state(_get_tile_state_for_encounter(coord))

	_player_marker.position = axial_to_world(player_coord)
	_boss_marker.position = axial_to_world(boss_coord)


func _get_tile_state_for_encounter(coord: Vector2i) -> String:
	match get_encounter_type_at(coord):
		HexMapModel.ENCOUNTER_SAFE:
			return TILE_STATE_SAFE
		HexMapModel.ENCOUNTER_COMBAT:
			return TILE_STATE_COMBAT
		HexMapModel.ENCOUNTER_BOSS:
			return TILE_STATE_BOSS
		_:
			return TILE_STATE_DEFAULT

