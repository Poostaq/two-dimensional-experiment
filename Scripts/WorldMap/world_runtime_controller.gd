class_name WorldRuntimeController
extends WorldPresentationController

var _model: WorldRuntimeModel = WorldRuntimeModel.new()
var _runtime_plan: WorldPlan
var _integration_failed: bool = false


func _ready() -> void:
	if not _validate_dependencies():
		_fail_integration()
		return
	var generated := HexWorldGeneratorV1.new().generate(PREVIEW_SEED)
	if not bool(generated.get("ok", false)):
		_fail_integration()
		return
	_runtime_plan = generated.get("plan") as WorldPlan
	if not is_instance_valid(_runtime_plan):
		_fail_integration()
		return
	if not present_plan(_runtime_plan) or not _model.configure(_runtime_plan):
		_fail_integration()
		return
	if not cell_selected.is_connected(_on_runtime_cell_selected):
		cell_selected.connect(_on_runtime_cell_selected)
	if not cell_inspected.is_connected(_on_runtime_cell_inspected):
		cell_inspected.connect(_on_runtime_cell_inspected)
	_apply_snapshot(_model.get_snapshot())


func get_runtime_snapshot() -> WorldRuntimeSnapshot:
	return _model.get_snapshot()


func request_move(destination: Vector2i) -> WorldMoveResult:
	var result := _model.request_move(destination)
	if result.is_accepted():
		_apply_snapshot(result.snapshot)
	return result


func get_valid_destinations() -> Array[Vector2i]:
	return _model.get_valid_destinations()


func has_integration_failed() -> bool:
	return _integration_failed


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
