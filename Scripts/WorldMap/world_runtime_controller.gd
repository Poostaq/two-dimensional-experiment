class_name WorldRuntimeController
extends WorldPresentationController

static var ENCOUNTER_SCENE: PackedScene = load("res://Scenes/encounter_overlay.tscn")
static var BATTLE_SCENE: PackedScene = load("res://Scenes/battle_arena.tscn")
static var PARTY_SCENE: PackedScene = load("res://Scenes/party_management.tscn")

var _model: WorldRuntimeModel = WorldRuntimeModel.new()
var _runtime_plan: WorldPlan
var _integration_failed: bool = false
var _roster: RunRoster = RunRoster.new()
var _active_encounter: EncounterOverlay
var _active_battle: BattleArena
var _active_party: PartyManagement

@export var auto_initialize_runtime: bool = true


func _ready() -> void:
	if not _validate_dependencies():
		_fail_integration()
		return
	if not auto_initialize_runtime:
		return
	var generated := HexWorldGeneratorV1.new().generate(PREVIEW_SEED)
	if not bool(generated.get("ok", false)):
		_fail_integration()
		return
	configure_runtime(generated.get("plan") as WorldPlan)


func configure_runtime(plan: WorldPlan) -> bool:
	if _integration_failed or not is_instance_valid(plan) or not _model.configure(plan):
		_fail_integration()
		return false
	_runtime_plan = plan
	if not present_plan(_runtime_plan):
		_fail_integration()
		return false
	if not cell_selected.is_connected(_on_runtime_cell_selected):
		cell_selected.connect(_on_runtime_cell_selected)
	if not cell_inspected.is_connected(_on_runtime_cell_inspected):
		cell_inspected.connect(_on_runtime_cell_inspected)
	var hud := get_node("%WorldMapHud") as WorldMapHud
	if not hud.party_requested.is_connected(open_party_management):
		hud.party_requested.connect(open_party_management)
	_apply_snapshot(_model.get_snapshot())
	return not _integration_failed


func get_runtime_snapshot() -> WorldRuntimeSnapshot:
	return _model.get_snapshot()


func request_move(destination: Vector2i) -> WorldMoveResult:
	var result := _model.request_move(destination)
	if result.is_accepted():
		_apply_snapshot(result.snapshot)
		_open_encounter(result.snapshot.player_coord, result.encounter_type)
	return result


func has_active_encounter() -> bool:
	return is_instance_valid(_active_encounter)


func close_active_encounter() -> void:
	_on_encounter_close_requested()


func has_active_battle() -> bool:
	return is_instance_valid(_active_battle)


func open_party_management() -> void:
	if _integration_failed or has_active_encounter() or has_active_battle() or has_active_party_management():
		return
	_model.set_surface_blocked(true)
	_active_party = PARTY_SCENE.instantiate() as PartyManagement
	get_node("PartyHost").add_child(_active_party)
	_active_party.configure_normal(_roster.get_slot_snapshot())
	_active_party.move_requested.connect(_on_party_move_requested)
	_active_party.close_requested.connect(_on_party_close_requested)
	_apply_snapshot(_model.get_snapshot())


func has_active_party_management() -> bool:
	return is_instance_valid(_active_party)


func get_valid_destinations() -> Array[Vector2i]:
	return _model.get_valid_destinations()


func has_integration_failed() -> bool:
	return _integration_failed


func _open_encounter(coord: Vector2i, encounter_type: String) -> void:
	if has_active_encounter():
		return
	_active_encounter = ENCOUNTER_SCENE.instantiate() as EncounterOverlay
	get_node("EncounterHost").add_child(_active_encounter)
	_active_encounter.configure(coord, encounter_type)
	_active_encounter.close_requested.connect(_on_encounter_close_requested)
	_active_encounter.battle_requested.connect(_on_battle_requested)


func _on_encounter_close_requested() -> void:
	if not has_active_encounter():
		return
	var was_boss := _active_encounter.encounter_type.to_lower() == "boss"
	_active_encounter.queue_free()
	_active_encounter = null
	if not was_boss:
		_model.close_ordinary_encounter()
		_apply_snapshot(_model.get_snapshot())


func _on_battle_requested(coord: Vector2i, encounter_type: String) -> void:
	if has_active_battle():
		return
	if has_active_encounter():
		_active_encounter.queue_free()
		_active_encounter = null
	_active_battle = BATTLE_SCENE.instantiate() as BattleArena
	get_node("BattleHost").add_child(_active_battle)
	_active_battle.configure(coord, encounter_type)
	_active_battle.configure_units(_roster.create_battle_units())
	_active_battle.exit_requested.connect(_on_battle_closed)
	_active_battle.battle_completed.connect(_on_battle_completed)


func _on_battle_completed(_outcome: BattleOutcome.Type) -> void:
	_on_battle_closed()


func _on_battle_closed() -> void:
	if not has_active_battle():
		return
	_active_battle.queue_free()
	_active_battle = null
	_model.close_ordinary_encounter()
	_apply_snapshot(_model.get_snapshot())


func _on_party_move_requested(source_slot: int, destination_slot: int, character_id: StringName) -> void:
	_roster.try_move(source_slot, destination_slot, character_id)
	if has_active_party_management():
		_active_party.refresh_slots(_roster.get_slot_snapshot())
	var hud := get_node("%WorldMapHud") as WorldMapHud
	hud.set_formation(_roster.get_slot_snapshot())


func _on_party_close_requested() -> void:
	if not has_active_party_management():
		return
	_active_party.queue_free()
	_active_party = null
	_model.set_surface_blocked(false)
	_apply_snapshot(_model.get_snapshot())


func _apply_snapshot(snapshot: WorldRuntimeSnapshot) -> void:
	if _integration_failed or not is_instance_valid(snapshot):
		return
	if not apply_runtime_snapshot(snapshot):
		_fail_integration()
		return
	var destinations := _model.get_valid_destinations()
	set_valid_destinations(destinations)
	var hud := get_node_or_null("%WorldMapHud") as WorldMapHud
	if not is_instance_valid(hud):
		_fail_integration()
		return
	var empty_formation: Array[RunCharacter] = []
	empty_formation.resize(6)
	hud.set_formation(empty_formation)
	var terrain_tags: Array[String] = []
	var cells := _runtime_plan.get_cells()
	var cell_data: Dictionary = cells.get(snapshot.player_coord, {})
	var terrain := String(cell_data.get("terrain", "plain"))
	if terrain != "plain":
		terrain_tags.append(terrain)
	hud.set_context(
		_model.get_runtime_encounter_type(snapshot.player_coord),
		terrain_tags,
		not destinations.is_empty()
	)
	hud.set_party_available(not snapshot.input_blocked)
	_apply_camera_visibility_rule(snapshot.player_coord)


func _apply_camera_visibility_rule(player_coord: Vector2i) -> void:
	var camera := get_world_camera()
	if not is_instance_valid(camera):
		_fail_integration()
		return
	var player_position := axial_to_world(player_coord)
	if not camera.get_visible_world_rect().has_point(player_position):
		camera.center_on(player_position)


func _on_runtime_cell_selected(coord: Vector2i) -> void:
	if _integration_failed:
		return
	request_move(coord)


func _on_runtime_cell_inspected(coord: Vector2i) -> void:
	if _integration_failed or not is_instance_valid(_runtime_plan):
		return
	var cells := _runtime_plan.get_cells()
	if not cells.has(coord):
		return
	var hud := get_node_or_null("%WorldMapHud") as WorldMapHud
	if not is_instance_valid(hud):
		_fail_integration()
		return
	var data: Dictionary = cells[coord]
	var terrain_tags: Array[String] = []
	var terrain := String(data.get("terrain", "plain"))
	if terrain != "plain":
		terrain_tags.append(terrain)
	hud.set_context(_model.get_runtime_encounter_type(coord), terrain_tags, get_valid_destinations().has(coord))


func _validate_dependencies() -> bool:
	return (
		is_instance_valid(get_node_or_null("%WorldCells"))
		and is_instance_valid(get_node_or_null("%WorldCamera"))
		and is_instance_valid(get_node_or_null("%WorldMinimap"))
		and is_instance_valid(get_node_or_null("%WorldMapHud"))
		and is_instance_valid(get_node_or_null("EncounterHost"))
		and is_instance_valid(get_node_or_null("BattleHost"))
		and is_instance_valid(get_node_or_null("PartyHost"))
	)


func _fail_integration() -> void:
	_integration_failed = true
	_model.set_surface_blocked(true)
	var empty_destinations: Array[Vector2i] = []
	set_valid_destinations(empty_destinations)
