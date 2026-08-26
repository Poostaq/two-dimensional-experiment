class_name WorldRuntimeController
extends WorldPresentationController

signal autosave_failed(error: RefCounted)
signal autosave_recovered
signal launcher_return_requested

static var ENCOUNTER_SCENE: PackedScene = load("res://Scenes/encounter_overlay.tscn")
static var BATTLE_SCENE: PackedScene = load("res://Scenes/battle_arena.tscn")
static var PARTY_SCENE: PackedScene = load("res://Scenes/party_management.tscn")
static var SAVE_COORDINATOR_SCRIPT: GDScript = load(
	"res://Scripts/WorldMap/world_runtime_save_coordinator.gd"
)
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")
static var REPOSITORY_SCRIPT: GDScript = load(
	"res://Scripts/Run/world_single_slot_repository.gd"
)

var _model: WorldRuntimeModel = WorldRuntimeModel.new()
var _runtime_plan: WorldPlan
var _integration_failed: bool = false
var _roster: RunRoster = RunRoster.new()
var _active_encounter: EncounterOverlay
var _active_battle: BattleArena
var _active_party: PartyManagement
var _pending_recruitment_option: BattleRewardOption
var _pending_recruit: RunCharacter
var _save_coordinator: RefCounted
var _durable_run_state: RefCounted
var _pending_candidate_model: WorldRuntimeModel
var _pending_move_result: WorldMoveResult
var _autosave_overlay: WorldAutosaveFailureOverlay
var _session_applied: bool = false

@export var auto_initialize_runtime: bool = true


func _ready() -> void:
	if not _validate_dependencies():
		_fail_integration()
		return
	_wire_autosave_overlay()
	if not auto_initialize_runtime:
		return
	var generated := HexWorldGeneratorV1.new().generate(PREVIEW_SEED)
	if not bool(generated.get("ok", false)):
		_fail_integration()
		return
	configure_runtime(generated.get("plan") as WorldPlan)


func apply_session(session: Dictionary, repository: RefCounted = null) -> bool:
	_session_applied = false
	if (
		not session.get("plan") is WorldPlan
		or not session.get("run_state") is RefCounted
		or not session.get("resolved_seed") is String
		or String(session.get("resolved_seed", "")).is_empty()
	):
		_model.set_surface_blocked(true)
		var empty_destinations: Array[Vector2i] = []
		set_valid_destinations(empty_destinations)
		return false
	var plan := session.get("plan") as WorldPlan
	var run_state := session.get("run_state") as RefCounted
	if not _restore_roster(run_state):
		return false
	if not configure_runtime(plan):
		return false
	var target_repository := repository
	if not is_instance_valid(target_repository):
		target_repository = REPOSITORY_SCRIPT.new()
	if not configure_persistence(
		String(session.get("resolved_seed")), run_state, target_repository
	):
		return false
	_session_applied = true
	return true


func is_session_applied() -> bool:
	return _session_applied


func get_durable_run_state() -> RefCounted:
	return _durable_run_state


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


func configure_persistence(
	resolved_seed: String,
	run_state: RefCounted,
	repository: RefCounted
) -> bool:
	if (
		not is_instance_valid(_runtime_plan)
		or not is_instance_valid(run_state)
		or not _model.restore_run_state(run_state)
	):
		return false
	_save_coordinator = SAVE_COORDINATOR_SCRIPT.new()
	if not _save_coordinator.call(
		"configure", _runtime_plan, resolved_seed, run_state, repository
	):
		_save_coordinator = null
		return false
	_durable_run_state = _save_coordinator.call("get_durable_state") as RefCounted
	_apply_snapshot(_model.get_snapshot())
	return true


func retry_autosave() -> Dictionary:
	if not is_instance_valid(_save_coordinator):
		return {"ok": false, "value": null, "error": null}
	var move_was_pending := is_instance_valid(_pending_candidate_model)
	var result: Dictionary = _save_coordinator.call("retry_pending")
	if bool(result.get("ok", false)):
		if not move_was_pending and is_instance_valid(_durable_run_state):
			_model.restore_run_state(_durable_run_state)
			_apply_snapshot(_model.get_snapshot())
		autosave_recovered.emit()
	return result


func discard_pending_autosave() -> bool:
	if not is_instance_valid(_save_coordinator):
		return false
	var restored := _save_coordinator.call("discard_pending") as RefCounted
	if not is_instance_valid(restored) or not _model.restore_run_state(restored):
		return false
	_durable_run_state = restored
	_pending_candidate_model = null
	_pending_move_result = null
	_apply_snapshot(_model.get_snapshot())
	autosave_recovered.emit()
	return true


func is_autosave_blocked() -> bool:
	return (
		is_instance_valid(_save_coordinator)
		and bool(_save_coordinator.call("is_input_blocked"))
	)


func get_runtime_snapshot() -> WorldRuntimeSnapshot:
	return _model.get_snapshot()


func request_move(destination: Vector2i) -> WorldMoveResult:
	if not is_instance_valid(_save_coordinator):
		var legacy_result := _model.request_move(destination)
		if legacy_result.is_accepted():
			_apply_snapshot(legacy_result.snapshot)
			_open_encounter(legacy_result.snapshot.player_coord, legacy_result.encounter_type)
		return legacy_result
	if is_autosave_blocked():
		return _model.request_move(destination)
	var candidate: Dictionary = _model.create_move_candidate(destination)
	var result := candidate.get("result") as WorldMoveResult
	if not bool(candidate.get("ok", false)) or not is_instance_valid(result):
		return result
	_pending_candidate_model = candidate.get("model") as WorldRuntimeModel
	_pending_move_result = result
	var candidate_state := _build_candidate_state(_pending_candidate_model, false)
	var saved: Dictionary = _save_coordinator.call(
		"commit_candidate",
		candidate_state,
		Callable(self, "_publish_pending_move"),
		"accepted_move"
	)
	if not bool(saved.get("ok", false)):
		_model.set_surface_blocked(true)
		_apply_snapshot(_model.get_snapshot())
		autosave_failed.emit(saved.get("error") as RefCounted)
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


func _wire_autosave_overlay() -> void:
	_autosave_overlay = get_node_or_null("%AutosaveFailureOverlay") as WorldAutosaveFailureOverlay
	if not is_instance_valid(_autosave_overlay):
		return
	if not autosave_failed.is_connected(_on_autosave_failed):
		autosave_failed.connect(_on_autosave_failed)
	if not autosave_recovered.is_connected(_on_autosave_recovered):
		autosave_recovered.connect(_on_autosave_recovered)
	if not _autosave_overlay.retry_requested.is_connected(_on_autosave_retry_requested):
		_autosave_overlay.retry_requested.connect(_on_autosave_retry_requested)
	if not _autosave_overlay.return_requested.is_connected(_on_autosave_return_requested):
		_autosave_overlay.return_requested.connect(_on_autosave_return_requested)
	if not _autosave_overlay.diagnostics_copied.is_connected(_on_autosave_diagnostics_copied):
		_autosave_overlay.diagnostics_copied.connect(_on_autosave_diagnostics_copied)


func _on_autosave_failed(error: RefCounted) -> void:
	if is_instance_valid(_autosave_overlay) and is_instance_valid(error):
		_autosave_overlay.present(
			error,
			String(ProjectSettings.get_setting("application/config/version", "development"))
		)


func _on_autosave_retry_requested() -> void:
	retry_autosave()


func _on_autosave_return_requested() -> void:
	discard_pending_autosave()
	launcher_return_requested.emit()


func _on_autosave_diagnostics_copied(_diagnostics: String) -> void:
	pass


func _on_autosave_recovered() -> void:
	if is_instance_valid(_autosave_overlay):
		_autosave_overlay.dismiss()


func _restore_roster(run_state: RefCounted) -> bool:
	if not is_instance_valid(run_state):
		return false
	var ids := run_state.get("formation") as Array[StringName]
	if ids.size() != RunRoster.MAX_ROSTER_SIZE:
		return false
	var available: Array[RunCharacter] = RunCharacterCatalog.create_starters()
	for reward_id: StringName in [
		RunCharacterCatalog.COMBAT_SCOUT_REWARD_ID,
		RunCharacterCatalog.BOSS_CHAMPION_REWARD_ID,
	]:
		var reward_character := RunCharacterCatalog.create_for_reward(reward_id)
		if is_instance_valid(reward_character):
			available.append(reward_character)
	var restored_slots: Array[RunCharacter] = []
	restored_slots.resize(RunRoster.MAX_ROSTER_SIZE)
	for slot_index: int in ids.size():
		var expected_id := ids[slot_index]
		if expected_id.is_empty():
			continue
		for character: RunCharacter in available:
			if character.character_id == expected_id:
				restored_slots[slot_index] = character
				break
		if not is_instance_valid(restored_slots[slot_index]):
			return false
	_roster = RunRoster.new(restored_slots)
	return true


func _open_encounter(coord: Vector2i, encounter_type: String) -> void:
	if has_active_encounter():
		return
	_active_encounter = ENCOUNTER_SCENE.instantiate() as EncounterOverlay
	get_node("EncounterHost").add_child(_active_encounter)
	_active_encounter.configure(coord, encounter_type.to_lower())
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
		if not _commit_current_authoritative("encounter_resolution", true):
			return
		_apply_snapshot(_model.get_snapshot())


func _on_battle_requested(coord: Vector2i, encounter_type: String) -> void:
	if has_active_battle():
		return
	if has_active_encounter():
		_active_encounter.queue_free()
		_active_encounter = null
	var normalized_encounter := encounter_type.to_lower()
	_active_battle = BATTLE_SCENE.instantiate() as BattleArena
	get_node("BattleHost").add_child(_active_battle)
	_active_battle.configure(coord, normalized_encounter)
	_active_battle.configure_units(_roster.create_battle_units())
	_active_battle.configure_reward_options(BattleRewardCatalog.get_options_for(normalized_encounter))
	_active_battle.exit_requested.connect(_on_battle_closed)
	_active_battle.battle_completed.connect(_on_battle_completed)
	_active_battle.reward_confirmed.connect(_on_reward_confirmed)
	_active_battle.recruitment_placement_requested.connect(_on_recruitment_placement_requested)


func _on_battle_completed(_outcome: BattleOutcome.Type) -> void:
	pass


func _on_reward_confirmed(_option: BattleRewardOption) -> void:
	_commit_current_authoritative("reward_completion", false)


func _on_recruitment_placement_requested(option: BattleRewardOption) -> void:
	if not has_active_battle() or has_active_party_management() or not is_instance_valid(option):
		return
	var recruit := RunCharacterCatalog.create_for_reward(option.reward_id)
	if not is_instance_valid(recruit) or _roster.has_character(recruit.character_id):
		_active_battle.restore_pending_recruitment(option)
		return
	_pending_recruitment_option = option
	_pending_recruit = recruit
	_active_party = PARTY_SCENE.instantiate() as PartyManagement
	get_node("PartyHost").add_child(_active_party)
	_active_party.placement_requested.connect(_on_recruitment_add_requested)
	_active_party.replacement_requested.connect(_on_recruitment_replace_requested)
	_active_party.placement_cancelled.connect(_on_recruitment_cancelled)
	if _roster.is_full():
		_active_party.configure_replacement(_roster.get_slot_snapshot(), recruit)
	else:
		_active_party.configure_placement(_roster.get_slot_snapshot(), recruit)


func _on_recruitment_add_requested(destination_slot: int, expected_id: StringName) -> void:
	if not is_instance_valid(_pending_recruit) or _pending_recruit.character_id != expected_id:
		return
	if _roster.try_add_at(_pending_recruit, destination_slot) == RunRoster.AddResult.ADDED:
		_complete_recruitment()


func _on_recruitment_replace_requested(destination_slot: int, expected_character_id: StringName, expected_recruit_id: StringName) -> void:
	if not is_instance_valid(_pending_recruit) or _pending_recruit.character_id != expected_recruit_id:
		return
	if _roster.try_replace_at(_pending_recruit, destination_slot, expected_character_id) == RunRoster.ReplaceResult.REPLACED:
		_complete_recruitment()


func _complete_recruitment() -> void:
	if not _commit_current_authoritative("recruitment_completion", false):
		return
	var option := _pending_recruitment_option
	_close_recruitment_party()
	if has_active_battle() and is_instance_valid(option):
		_active_battle.complete_pending_recruitment(option)


func _on_recruitment_cancelled() -> void:
	var option := _pending_recruitment_option
	_close_recruitment_party()
	if has_active_battle() and is_instance_valid(option):
		_active_battle.restore_pending_recruitment(option)


func _close_recruitment_party() -> void:
	if has_active_party_management():
		_active_party.queue_free()
	_active_party = null
	_pending_recruitment_option = null
	_pending_recruit = null


func _on_battle_closed() -> void:
	if not has_active_battle():
		return
	_active_battle.queue_free()
	_active_battle = null
	_close_recruitment_party()
	_model.close_ordinary_encounter()
	if not _commit_current_authoritative("encounter_resolution", true):
		return
	_apply_snapshot(_model.get_snapshot())


func _on_party_move_requested(source_slot: int, destination_slot: int, character_id: StringName) -> void:
	var move_result := _roster.try_move(source_slot, destination_slot, character_id)
	if move_result not in [RunRoster.MoveResult.MOVED, RunRoster.MoveResult.SWAPPED]:
		return
	if not _commit_current_authoritative("party_move", false):
		return
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


func _publish_pending_move(state: RefCounted) -> void:
	if not is_instance_valid(_pending_candidate_model) or not is_instance_valid(_pending_move_result):
		return
	_model = _pending_candidate_model
	_durable_run_state = state
	var result := _pending_move_result
	_pending_candidate_model = null
	_pending_move_result = null
	_apply_snapshot(result.snapshot)
	_open_encounter(result.snapshot.player_coord, result.encounter_type)


func _publish_current_state(state: RefCounted) -> void:
	_durable_run_state = state


func _commit_current_authoritative(event_name: String, consume_current: bool) -> bool:
	if not is_instance_valid(_save_coordinator):
		return true
	var candidate_state := _build_candidate_state(_model, consume_current)
	var saved: Dictionary = _save_coordinator.call(
		"commit_candidate",
		candidate_state,
		Callable(self, "_publish_current_state"),
		event_name
	)
	if bool(saved.get("ok", false)):
		return true
	_model.set_surface_blocked(true)
	_apply_snapshot(_model.get_snapshot())
	autosave_failed.emit(saved.get("error") as RefCounted)
	return false


func _build_candidate_state(model: WorldRuntimeModel, consume_current: bool) -> RefCounted:
	if not is_instance_valid(_durable_run_state) or not is_instance_valid(model):
		return null
	var data := _durable_run_state.call("to_dictionary") as Dictionary
	var snapshot := model.get_snapshot()
	data["player_coord"] = [snapshot.player_coord.x, snapshot.player_coord.y]
	data["boss_coord"] = [snapshot.boss_coord.x, snapshot.boss_coord.y]
	data["move_count"] = snapshot.move_count
	data["boss_active"] = snapshot.sudden_death_active
	data["boss_engaged"] = snapshot.boss_encounter_open
	data["formation"] = _formation_ids()
	if consume_current:
		var consumed := data.get("consumed_encounters", []) as Array
		var coord_value := [snapshot.player_coord.x, snapshot.player_coord.y]
		if not consumed.has(coord_value):
			consumed.append(coord_value)
		data["consumed_encounters"] = consumed
	var decoded: Dictionary = RUN_STATE_SCRIPT.from_dictionary(data, _runtime_plan)
	return decoded.get("value") as RefCounted if bool(decoded.get("ok", false)) else null


func _formation_ids() -> Array[StringName]:
	var formation: Array[StringName] = []
	for character: RunCharacter in _roster.get_slot_snapshot():
		formation.append(character.character_id if is_instance_valid(character) else &"")
	return formation


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
	hud.set_formation(_roster.get_slot_snapshot())
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
