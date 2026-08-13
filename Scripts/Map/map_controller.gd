class_name MapController
extends Node2D

const HEX_MAP_MODEL_PATH := "res://Scripts/Map/hex_map_model.gd"
const TILE_SCENE_PATH := "res://Scenes/map_hex_tile.tscn"
const ENCOUNTER_OVERLAY_SCENE_PATH := "res://Scenes/encounter_overlay.tscn"
const BATTLE_ARENA_SCENE_PATH := "res://Scenes/battle_arena.tscn"
const TILE_RADIUS := 38.0
const TILE_SPACING := 1.08
const TILE_STATE_DEFAULT := "default"
const TILE_STATE_VALID_MOVE := "valid_move"
const TILE_STATE_PLAYER := "player"
const TILE_STATE_SAFE := "safe"
const TILE_STATE_COMBAT := "combat"
const TILE_STATE_BOSS := "boss"
const DEFAULT_RUN_ID := "default-run"
const SUDDEN_DEATH_MOVE_THRESHOLD := 15

@onready var _map_root: Node2D = $MapRoot
@onready var _player_marker: Node2D = $MapRoot/PlayerMarker
@onready var _boss_marker: Node2D = $MapRoot/BossMarker
@onready var _ui_layer: CanvasLayer = $UI
@onready var _turn_counter_label: Label = %TurnCounterLabel

var player_coord: Vector2i = Vector2i.ZERO
var boss_coord: Vector2i = Vector2i.ZERO
var move_count: int = 0
var run_id: String = DEFAULT_RUN_ID
var encounter_types: Dictionary = {}

var _model: HexMapModel
var _tile_scene: PackedScene
var _encounter_overlay_scene: PackedScene
var _battle_arena_scene: PackedScene
var _active_encounter_overlay: EncounterOverlay
var _active_battle: BattleArena
var _run_roster: RunRoster = RunRoster.new()
var _sudden_death_active: bool = false
var _tiles: Dictionary = {}


func _ready() -> void:
	var model_script := load(HEX_MAP_MODEL_PATH) as Script
	_model = model_script.new() as HexMapModel
	_tile_scene = load(TILE_SCENE_PATH) as PackedScene
	_encounter_overlay_scene = load(ENCOUNTER_OVERLAY_SCENE_PATH) as PackedScene
	_battle_arena_scene = load(BATTLE_ARENA_SCENE_PATH) as PackedScene

	player_coord = _model.get_start_coord()
	boss_coord = _model.get_boss_coord()
	encounter_types = _model.get_encounter_types_for_run(run_id)

	_build_tiles()
	_refresh_visual_state()
	_refresh_turn_counter()


func set_run_id(value: String) -> void:
	run_id = DEFAULT_RUN_ID if value.is_empty() else value
	_run_roster = RunRoster.new()
	if _model == null:
		return

	close_active_encounter()
	exit_active_battle()
	player_coord = _model.get_start_coord()
	boss_coord = _model.get_boss_coord()
	move_count = 0
	_refresh_turn_counter()
	_sudden_death_active = false
	encounter_types = _model.get_encounter_types_for_run(run_id)
	_refresh_visual_state()


func get_run_roster_snapshot() -> Array[RunCharacter]:
	return _run_roster.get_characters()


func get_encounter_layout() -> Dictionary:
	return encounter_types.duplicate()


func get_encounter_type_at(coord: Vector2i) -> String:
	if not encounter_types.has(coord):
		return HexMapModel.ENCOUNTER_NONE
	return encounter_types[coord]


func is_sudden_death_active() -> bool:
	return _sudden_death_active


func get_runtime_encounter_type_at(coord: Vector2i) -> String:
	if not _model.is_valid_coord(coord):
		return HexMapModel.ENCOUNTER_NONE
	if coord == boss_coord:
		return HexMapModel.ENCOUNTER_BOSS
	if coord == _model.get_boss_coord():
		return HexMapModel.ENCOUNTER_SAFE
	return get_encounter_type_at(coord)


func has_active_encounter() -> bool:
	return is_instance_valid(_active_encounter_overlay)


func get_active_encounter() -> EncounterOverlay:
	return _active_encounter_overlay if has_active_encounter() else null


func close_active_encounter() -> void:
	if not has_active_encounter():
		_active_encounter_overlay = null
		return

	var overlay := _active_encounter_overlay
	_active_encounter_overlay = null
	if overlay.get_parent() != null:
		overlay.get_parent().remove_child(overlay)
	overlay.queue_free()


func has_active_battle() -> bool:
	return is_instance_valid(_active_battle)


func get_active_battle() -> BattleArena:
	return _active_battle if has_active_battle() else null


func exit_active_battle() -> void:
	if not has_active_battle():
		_active_battle = null
		return

	var battle := _active_battle
	_active_battle = null
	if battle.get_parent() != null:
		battle.get_parent().remove_child(battle)
	battle.queue_free()


func try_move_by_offset(offset: Vector2i) -> bool:
	return request_move(player_coord + offset)


func request_move(destination: Vector2i) -> bool:
	if has_active_encounter() or has_active_battle():
		return false
	if not _model.is_valid_coord(destination):
		return false
	if not _model.are_adjacent(player_coord, destination):
		return false

	player_coord = destination
	move_count += 1
	_refresh_turn_counter()
	_refresh_visual_state()

	if player_coord == boss_coord:
		_open_encounter(destination, HexMapModel.ENCOUNTER_BOSS)
		return true

	if move_count == SUDDEN_DEATH_MOVE_THRESHOLD:
		_sudden_death_active = true
	elif _sudden_death_active and move_count > SUDDEN_DEATH_MOVE_THRESHOLD:
		boss_coord = _model.get_pursuit_step(boss_coord, player_coord)
		_refresh_visual_state()
		if boss_coord == player_coord:
			_open_encounter(destination, HexMapModel.ENCOUNTER_BOSS)
			return true

	_open_encounter(destination, get_runtime_encounter_type_at(destination))
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
		var tile: HexTileView = _tile_scene.instantiate() as HexTileView
		_map_root.add_child(tile)
		_map_root.move_child(tile, 0)
		tile.position = axial_to_world(coord)
		tile.configure(coord)
		tile.tile_selected.connect(_on_tile_selected)
		_tiles[coord] = tile


func _refresh_turn_counter() -> void:
	_turn_counter_label.text = "Turns: %d" % move_count


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


func _on_tile_selected(destination: Vector2i) -> void:
	request_move(destination)


func _open_encounter(destination: Vector2i, encounter_type: String) -> void:
	if has_active_encounter():
		return
	if _encounter_overlay_scene == null:
		push_error("Encounter overlay scene is missing: %s" % ENCOUNTER_OVERLAY_SCENE_PATH)
		return
	if _ui_layer == null:
		push_error("GameWorld is missing UI CanvasLayer for encounter overlay")
		return

	var overlay := _encounter_overlay_scene.instantiate() as EncounterOverlay
	if overlay == null:
		push_error("Encounter overlay scene root must be an EncounterOverlay")
		return

	_active_encounter_overlay = overlay
	overlay.configure(destination, encounter_type)
	overlay.close_requested.connect(Callable(self, "close_active_encounter"), CONNECT_ONE_SHOT)
	overlay.battle_requested.connect(Callable(self, "_on_battle_requested"))
	_ui_layer.add_child(overlay)


func _on_battle_requested(coordinate: Vector2i, encounter_type: String) -> void:
	if not has_active_encounter() or has_active_battle():
		return
	var overlay := get_active_encounter()
	if overlay.encounter_coordinate != coordinate or overlay.encounter_type != encounter_type:
		return
	if encounter_type != HexMapModel.ENCOUNTER_COMBAT and encounter_type != HexMapModel.ENCOUNTER_BOSS:
		return
	if _battle_arena_scene == null:
		push_error("Battle arena scene is missing: %s" % BATTLE_ARENA_SCENE_PATH)
		return
	if _ui_layer == null:
		push_error("GameWorld is missing UI CanvasLayer for battle arena")
		return

	var battle := _battle_arena_scene.instantiate() as BattleArena
	if battle == null:
		push_error("Battle arena scene root must be a BattleArena")
		return

	battle.configure(coordinate, encounter_type)
	battle.reward_confirmed.connect(Callable(self, "_on_reward_confirmed"))
	battle.exit_requested.connect(Callable(self, "exit_active_battle"), CONNECT_ONE_SHOT)
	_active_battle = battle
	_ui_layer.add_child(battle)
	var units := _run_roster.create_battle_units()
	for unit: BattleUnitState in battle.get_turn_queue():
		if unit.side == BattleUnitState.Side.ENEMY:
			units.append(unit)
	battle.configure_units(units)
	battle.configure_reward_options(_get_eligible_reward_options(encounter_type))
	close_active_encounter()


func _get_eligible_reward_options(event_type: String) -> Array[BattleRewardOption]:
	return _filter_eligible_reward_options(
		BattleRewardCatalog.get_options_for(event_type),
		_run_roster
	)


func _filter_eligible_reward_options(
	options: Array[BattleRewardOption],
	roster: RunRoster
) -> Array[BattleRewardOption]:
	var eligible: Array[BattleRewardOption] = []
	for option: BattleRewardOption in options:
		if option.kind != BattleRewardOption.Kind.RECRUITMENT:
			eligible.append(option)
			continue
		var recruit: RunCharacter = RunCharacterCatalog.create_for_reward(option.reward_id)
		if is_instance_valid(recruit) and roster.can_add(recruit.character_id):
			eligible.append(option)
	return eligible


func _on_reward_confirmed(option: BattleRewardOption) -> void:
	if not is_instance_valid(option) or option.kind != BattleRewardOption.Kind.RECRUITMENT:
		return
	var recruit: RunCharacter = RunCharacterCatalog.create_for_reward(option.reward_id)
	if not is_instance_valid(recruit):
		return
	_run_roster.try_add(recruit)


func _get_tile_state_for_encounter(coord: Vector2i) -> String:
	match get_runtime_encounter_type_at(coord):
		HexMapModel.ENCOUNTER_SAFE:
			return TILE_STATE_SAFE
		HexMapModel.ENCOUNTER_COMBAT:
			return TILE_STATE_COMBAT
		HexMapModel.ENCOUNTER_BOSS:
			return TILE_STATE_BOSS
		_:
			return TILE_STATE_DEFAULT
