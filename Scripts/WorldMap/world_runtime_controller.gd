class_name WorldRuntimeController
extends WorldPresentationController

signal autosave_failed(error: RefCounted)
signal autosave_recovered
signal launcher_return_requested

enum TerminalPhase { PLAYING, LOSS_COMMITTING, LOSS_SAVE_FAILED, LOSS_DURABLE, RETURNED }

var _terminal_phase: TerminalPhase = TerminalPhase.PLAYING
var _session_generation: int = 0
var _battle_generation: int = 0
var _pending_battle_receipt: Dictionary = {}
var _battle_settled: bool = false
var _gold_panel: Control
var _gold_ack_callback: Callable
var _pending_ack_id: String = ""
static var ACKNOWLEDGEMENT_RULES: Script = load("res://Scripts/Run/battle_reward_acknowledgement_rules.gd")

static var SETTLEMENT_RULES: Script = load("res://Scripts/Run/battle_settlement_rules.gd")
static var RESULT_RECORD: Script = load("res://Scripts/Battle/battle_result_record.gd")

enum RecruitmentState {
	IDLE,
	REWARD_SELECTED,
	RECRUITMENT_PENDING,
	PLACEMENT_OPEN,
	PLACEMENT_CONFIRMED,
	PLACEMENT_CANCELLED,
	SAVE_FAILED,
	REWARD_COMPLETED,
}

static var ENCOUNTER_SCENE: PackedScene = load("res://Scenes/encounter_overlay.tscn")
static var BATTLE_SCENE: PackedScene = load("res://Scenes/battle_arena.tscn")
static var PARTY_SCENE: PackedScene = load("res://Scenes/party_management.tscn")
static var SAVE_COORDINATOR_SCRIPT: GDScript = load(
	"res://Scripts/WorldMap/world_runtime_save_coordinator.gd"
)
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")
static var CACHE_RULES_SCRIPT: GDScript = load("res://Scripts/Run/quartermaster_cache_rules.gd")
static var RECOVERY_RULES_SCRIPT: GDScript = load(
	"res://Scripts/Run/post_battle_recovery_rules.gd"
)
static var PREPARATION_RECORD_SCRIPT: GDScript = load(
	"res://Scripts/Battle/battle_preparation_record.gd"
)
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
var _pending_recruitment_roster: RunRoster
var _recruitment_state: RecruitmentState = RecruitmentState.IDLE
var _save_coordinator: RefCounted
var _durable_run_state: RefCounted
var _pending_candidate_model: WorldRuntimeModel
var _pending_move_result: WorldMoveResult
var _autosave_overlay: WorldAutosaveFailureOverlay
var _session_applied: bool = false
var _active_battle_recovery_handled: bool = false

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
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return false
	var requested_state: RefCounted = session.get("run_state") as RefCounted
	if not is_instance_valid(requested_state) or not requested_state.is_playable():
		return false
	_session_generation += 1
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
	if not _initialize_or_validate_durable_health(run_state):
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
	_wire_gold_panel()
	if has_pending_gold_reward():
		_present_pending_gold_reward()
	else:
		_restore_persisted_preparation()
	return true


func is_session_applied() -> bool:
	return _session_applied


func get_durable_run_state() -> RefCounted:
	return _durable_run_state


func configure_runtime(plan: WorldPlan) -> bool:
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return false
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
	if _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward() or not is_instance_valid(run_state) or not run_state.is_playable():
		return false
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
	if _integration_failed or _terminal_phase in [TerminalPhase.LOSS_COMMITTING, TerminalPhase.LOSS_DURABLE, TerminalPhase.RETURNED]:
		return {"ok": false, "value": null, "error": null}
	var terminal_retry: bool = _terminal_phase == TerminalPhase.LOSS_SAVE_FAILED
	if terminal_retry:
		_terminal_phase = TerminalPhase.LOSS_COMMITTING
	if not is_instance_valid(_save_coordinator):
		return {"ok": false, "value": null, "error": null}
	var move_was_pending := is_instance_valid(_pending_candidate_model)
	var result: Dictionary = _save_coordinator.call("retry_pending")
	if terminal_retry:
		if not result.get("ok", false):
			_terminal_phase = TerminalPhase.LOSS_SAVE_FAILED
		return result
	if bool(result.get("ok", false)):
		if not move_was_pending and is_instance_valid(_durable_run_state):
			_model.restore_run_state(_durable_run_state)
			if has_active_battle() or has_pending_gold_reward():
				_model.set_surface_blocked(true)
			_apply_snapshot(_model.get_snapshot())
		autosave_recovered.emit()
	return result


func discard_pending_autosave() -> bool:
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING:
		return false
	if not is_instance_valid(_save_coordinator):
		return false
	var restored := _save_coordinator.call("discard_pending") as RefCounted
	if not is_instance_valid(restored) or not _model.restore_run_state(restored):
		return false
	_durable_run_state = restored
	_pending_ack_id = ""
	_model.set_surface_blocked(has_active_battle() or has_pending_gold_reward())
	if has_pending_gold_reward():
		_present_pending_gold_reward()
	_pending_candidate_model = null
	_pending_move_result = null
	if _recruitment_state == RecruitmentState.SAVE_FAILED:
		_pending_recruitment_roster = null
		_recruitment_state = RecruitmentState.PLACEMENT_OPEN
		if has_active_party_management():
			_active_party.refresh_slots(_roster.get_slot_snapshot())
	_apply_snapshot(_model.get_snapshot())
	autosave_recovered.emit()
	return true


func is_run_termination_pending() -> bool:
	return _integration_failed or _terminal_phase != TerminalPhase.PLAYING


func is_autosave_blocked() -> bool:
	return (
		is_instance_valid(_save_coordinator)
		and bool(_save_coordinator.call("is_input_blocked"))
	)


func get_runtime_snapshot() -> WorldRuntimeSnapshot:
	return _model.get_snapshot()


func request_move(destination: Vector2i) -> WorldMoveResult:
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or has_pending_gold_reward():
		_model.set_surface_blocked(true)
		return _model.request_move(destination)
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
	var candidate_state := _build_candidate_state(_pending_candidate_model, false, null, true)
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
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return
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


func get_recruitment_state() -> RecruitmentState:
	return _recruitment_state


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
			String(ProjectSettings.get_setting("application/config/version", "development")),
			_terminal_phase == TerminalPhase.PLAYING
		)


func _on_autosave_retry_requested() -> void:
	retry_autosave()


func _on_autosave_return_requested() -> void:
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING:
		return
	if discard_pending_autosave():
		_invalidate_gold_callbacks()
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
	for class_id: StringName in RunCharacterCatalog.get_goblin_class_ids():
		var regular_character := RunCharacterCatalog.create_by_class_id(class_id)
		if is_instance_valid(regular_character):
			available.append(regular_character)
	for commander_id: StringName in GoblinCommanderCatalog.get_commander_ids():
		var commander_character := GoblinCommanderCatalog.create_by_commander_id(commander_id)
		if is_instance_valid(commander_character):
			available.append(commander_character)
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
	if has_pending_gold_reward() or has_active_encounter():
		return
	_active_encounter = ENCOUNTER_SCENE.instantiate() as EncounterOverlay
	get_node("EncounterHost").add_child(_active_encounter)
	_active_encounter.configure(coord, encounter_type.to_lower())
	_active_encounter.close_requested.connect(_on_encounter_close_requested)
	_active_encounter.battle_requested.connect(_on_battle_requested)


func _on_encounter_close_requested() -> void:
	if has_pending_gold_reward() or not has_active_encounter():
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
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return
	if has_active_battle():
		return
	_battle_generation += 1
	_pending_battle_receipt = {}
	_battle_settled = false
	_recruitment_state = RecruitmentState.IDLE
	_active_battle_recovery_handled = false
	if has_active_encounter():
		_active_encounter.queue_free()
		_active_encounter = null
	var normalized_encounter := encounter_type.to_lower()
	_active_battle = BATTLE_SCENE.instantiate() as BattleArena
	get_node("BattleHost").add_child(_active_battle)
	_active_battle.configure(coord, normalized_encounter)
	var durable_health: Dictionary[StringName, int] = {}
	if is_instance_valid(_durable_run_state):
		durable_health = _durable_run_state.call("get_character_hp_snapshot")
	var battle_units: Array[BattleUnitState] = _roster.create_battle_units(durable_health)
	if battle_units.size() != _roster.size():
		_active_battle.queue_free()
		_active_battle = null
		_fail_integration()
		return
	_active_battle.configure_party_units(battle_units)
	_active_battle.configure_production_settlement(_session_applied)
	if not _session_applied:
		_active_battle.configure_reward_options(BattleRewardCatalog.get_options_for(normalized_encounter))
	_active_battle.exit_requested.connect(_on_bound_battle_closed.bind(_session_generation, _battle_generation, _active_battle))
	_active_battle.battle_completed.connect(_on_battle_completed.bind(_session_generation, _battle_generation, _active_battle))
	if not _session_applied:
		_active_battle.reward_selected.connect(_on_reward_selected)
		_active_battle.reward_confirmed.connect(_on_reward_confirmed)
		_active_battle.recruitment_placement_requested.connect(_on_recruitment_placement_requested)
	_active_battle.preparation_commit_requested.connect(_on_preparation_commit_requested)
	_configure_battle_preparation(coord, normalized_encounter)


func _configure_battle_preparation(coord: Vector2i, encounter_type: String) -> void:
	if encounter_type != "combat" or not is_instance_valid(_durable_run_state):
		return
	var persisted := _durable_run_state.get("battle_preparation") as RefCounted
	if is_instance_valid(persisted) and persisted.state != BattlePreparationRecord.State.NONE:
		if persisted.encounter_coord != coord or persisted.encounter_type != encounter_type:
			_fail_integration()
			return
		var restored: bool = (
			_active_battle.configure_preparation(persisted)
			if persisted.state == BattlePreparationRecord.State.OFFERED
			else _active_battle.apply_committed_preparation(persisted)
		)
		if not restored:
			_fail_integration()
		return
	if not bool(_durable_run_state.get("cache_ready")) or not _roster.has_character(CACHE_RULES_SCRIPT.BRAKKA_ID):
		return
	var identity := _active_battle.get_setup_identity() as RefCounted
	if not is_instance_valid(identity):
		_fail_integration()
		return
	var preparation_id := StringName(
		"cache:%d:%d:%s" % [coord.x, coord.y, identity.canonical_key.left(12)]
	)
	var offered := PREPARATION_RECORD_SCRIPT.offered(
		preparation_id, coord, encounter_type, identity.canonical_key
	) as RefCounted
	if not is_instance_valid(offered) or not _active_battle.configure_preparation(offered):
		_fail_integration()
		return
	_commit_preparation_state(offered, false, "_publish_preparation_offer", "battle_preparation_offer")


func _on_preparation_commit_requested(
	choice: int,
	target_unit_id: StringName,
	expected_setup_key: String
) -> void:
	if _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or not has_active_battle() or not is_instance_valid(_durable_run_state):
		return
	var offered: RefCounted = _durable_run_state.get("battle_preparation") as RefCounted
	var identity: RefCounted = _active_battle.get_setup_identity() as RefCounted
	if (
		not is_instance_valid(offered)
		or offered.state != BattlePreparationRecord.State.OFFERED
		or not bool(_durable_run_state.get("cache_ready"))
		or not is_instance_valid(identity)
		or offered.setup_key != expected_setup_key
		or identity.canonical_key != expected_setup_key
	):
		return
	var committed: RefCounted = PREPARATION_RECORD_SCRIPT.committed(
		offered.preparation_id,
		offered.encounter_coord,
		offered.encounter_type,
		offered.setup_key,
		choice as BattlePreparationRecord.Choice,
		target_unit_id
	) as RefCounted
	if not is_instance_valid(committed):
		return
	_commit_preparation_state(
		committed, true, "_publish_preparation_commit", "battle_preparation_commit"
	)


func _commit_preparation_state(
	record: RefCounted,
	consume_cache: bool,
	publish_method: StringName,
	event_name: String
) -> void:
	var candidate_state: RefCounted = _build_preparation_candidate(record, consume_cache)
	if not is_instance_valid(candidate_state):
		return
	if not is_instance_valid(_save_coordinator):
		call(publish_method, candidate_state)
		return
	var saved: Dictionary = _save_coordinator.call(
		"commit_candidate", candidate_state, Callable(self, publish_method), event_name
	)
	if not bool(saved.get("ok", false)):
		_model.set_surface_blocked(true)
		_apply_snapshot(_model.get_snapshot())
		autosave_failed.emit(saved.get("error") as RefCounted)


func _build_preparation_candidate(record: RefCounted, consume_cache: bool) -> RefCounted:
	if not is_instance_valid(_durable_run_state) or not is_instance_valid(record):
		return null
	var data: Dictionary = _durable_run_state.call("to_dictionary") as Dictionary
	data["battle_preparation"] = record.call("to_dictionary")
	if consume_cache:
		var consumed: Dictionary = CACHE_RULES_SCRIPT.after_consumption(
			bool(_durable_run_state.get("cache_ready"))
		)
		if consumed.is_empty():
			return null
		data["cache_move_progress"] = int(consumed.get("progress"))
		data["cache_ready"] = bool(consumed.get("ready"))
	var decoded: Dictionary = RUN_STATE_SCRIPT.from_dictionary(data, _runtime_plan)
	return decoded.get("value") as RefCounted if bool(decoded.get("ok", false)) else null


func _publish_preparation_offer(state: RefCounted) -> void:
	if not is_instance_valid(state):
		return
	_durable_run_state = state
	_apply_snapshot(_model.get_snapshot())


func _publish_preparation_commit(state: RefCounted) -> void:
	if not is_instance_valid(state) or not has_active_battle():
		return
	var record := state.get("battle_preparation") as RefCounted
	if not is_instance_valid(record) or not _active_battle.apply_committed_preparation(record):
		_fail_integration()
		return
	_durable_run_state = state
	_apply_snapshot(_model.get_snapshot())


func _restore_persisted_preparation() -> void:
	if not is_instance_valid(_durable_run_state) or has_active_battle():
		return
	var record := _durable_run_state.get("battle_preparation") as RefCounted
	if is_instance_valid(record) and record.state != BattlePreparationRecord.State.NONE:
		_on_battle_requested(record.encounter_coord, record.encounter_type)


func _on_battle_completed(outcome: BattleOutcome.Type, session_generation: int = -1, battle_generation: int = -1, source: BattleArena = null) -> void:
	if session_generation != -1 and (session_generation != _session_generation or battle_generation != _battle_generation or source != _active_battle):
		return
	if not has_active_battle():
		return
	if not _session_applied:
		_on_legacy_battle_completed(outcome)
		return
	var receipt: Dictionary = _active_battle.get_terminal_result()
	if receipt.is_empty() or outcome == BattleOutcome.Type.IN_PROGRESS:
		return
	var expected_outcome: String = "victory" if outcome == BattleOutcome.Type.VICTORY else "defeat"
	if receipt.get("outcome") != expected_outcome:
		_fail_integration()
		return
	if not _pending_battle_receipt.is_empty():
		if RESULT_RECORD.canonical_key(receipt) != RESULT_RECORD.canonical_key(_pending_battle_receipt):
			_fail_integration()
		return
	if _terminal_phase != TerminalPhase.PLAYING:
		return
	if outcome == BattleOutcome.Type.DEFEAT:
		_terminal_phase = TerminalPhase.LOSS_COMMITTING
	_model.set_surface_blocked(true)
	var built: Dictionary = SETTLEMENT_RULES.build_candidate(_durable_run_state, _runtime_plan, receipt)
	if not built.get("ok", false):
		_fail_integration()
		return
	if built.get("duplicate", false):
		return
	_pending_battle_receipt = receipt.duplicate(true)
	var candidate: RefCounted = built.value
	var saved: Dictionary = _save_coordinator.commit_candidate(candidate, Callable(self, "_publish_battle_settlement").bind(_session_generation, _battle_generation, _active_battle), "battle_settlement", outcome != BattleOutcome.Type.DEFEAT)
	if saved.get("ok", false):
		return
	if not _save_coordinator.is_input_blocked():
		_fail_integration()
		return
	if outcome == BattleOutcome.Type.DEFEAT:
		_terminal_phase = TerminalPhase.LOSS_SAVE_FAILED
	_apply_snapshot(_model.get_snapshot())
	autosave_failed.emit(saved.get("error") as RefCounted)


func _publish_battle_settlement(state: RefCounted, generation: int, battle_generation: int, source: BattleArena) -> void:
	if generation != _session_generation or battle_generation != _battle_generation or not is_instance_valid(source) or source != _active_battle:
		return
	if _battle_settled:
		return
	_battle_settled = true
	_durable_run_state = state
	if not state.is_playable():
		_terminal_phase = TerminalPhase.LOSS_DURABLE
		if is_instance_valid(_autosave_overlay):
			_autosave_overlay.dismiss()
		_terminal_phase = TerminalPhase.RETURNED
		launcher_return_requested.emit()
		return
	_model.restore_run_state(state)
	_model.set_surface_blocked(has_active_battle())
	_apply_snapshot(_model.get_snapshot())
	_present_pending_gold_reward()


func _on_bound_battle_closed(session_generation: int, battle_generation: int, source: BattleArena) -> void:
	if session_generation != _session_generation or battle_generation != _battle_generation or source != _active_battle:
		return
	_on_battle_closed()


func _on_legacy_battle_completed(outcome: BattleOutcome.Type) -> void:
	if (
		outcome != BattleOutcome.Type.VICTORY
		or _active_battle_recovery_handled
		or not has_active_battle()
	):
		return
	var recovered_health := _calculate_recovered_health(
		_active_battle.get_terminal_player_health_snapshot()
	)
	if recovered_health.is_empty():
		_fail_integration()
		return
	var candidate_state := _build_candidate_state(
		_model, false, null, false, recovered_health
	)
	if not is_instance_valid(candidate_state):
		_fail_integration()
		return
	_active_battle_recovery_handled = true
	if not is_instance_valid(_save_coordinator):
		_publish_current_state(candidate_state)
		return
	var saved: Dictionary = _save_coordinator.call(
		"commit_candidate",
		candidate_state,
		Callable(self, "_publish_current_state"),
		"battle_victory_recovery"
	)
	if bool(saved.get("ok", false)):
		return
	_model.set_surface_blocked(true)
	_apply_snapshot(_model.get_snapshot())
	autosave_failed.emit(saved.get("error") as RefCounted)


func _on_reward_selected(option: BattleRewardOption) -> void:
	if _session_applied:
		return
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return
	if (
		_recruitment_state == RecruitmentState.IDLE
		and is_instance_valid(option)
		and option.kind == BattleRewardOption.Kind.RECRUITMENT
	):
		_recruitment_state = RecruitmentState.REWARD_SELECTED


func _on_reward_confirmed(_option: BattleRewardOption) -> void:
	if _session_applied:
		return
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return
	_commit_current_authoritative("reward_completion", false)


func _on_recruitment_placement_requested(option: BattleRewardOption) -> void:
	if _session_applied:
		return
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return
	if (
		not has_active_battle()
		or has_active_party_management()
		or not is_instance_valid(option)
		or _recruitment_state not in [
			RecruitmentState.IDLE,
			RecruitmentState.REWARD_SELECTED,
		]
	):
		return
	_recruitment_state = RecruitmentState.RECRUITMENT_PENDING
	var recruit := RunCharacterCatalog.create_for_reward(option.reward_id)
	if not is_instance_valid(recruit) or _roster.has_character(recruit.character_id):
		_active_battle.restore_pending_recruitment(option)
		_recruitment_state = RecruitmentState.REWARD_SELECTED
		return
	_pending_recruitment_option = option
	_pending_recruit = recruit
	_pending_recruitment_roster = null
	_active_party = PARTY_SCENE.instantiate() as PartyManagement
	get_node("PartyHost").add_child(_active_party)
	_active_party.placement_requested.connect(_on_recruitment_add_requested)
	_active_party.replacement_requested.connect(_on_recruitment_replace_requested)
	_active_party.placement_cancelled.connect(_on_recruitment_cancelled)
	_active_party.close_requested.connect(_on_recruitment_cancelled)
	if _roster.is_full():
		_active_party.configure_replacement(_roster.get_slot_snapshot(), recruit)
	else:
		_active_party.configure_placement(_roster.get_slot_snapshot(), recruit)
	_recruitment_state = RecruitmentState.PLACEMENT_OPEN


func _on_recruitment_add_requested(destination_slot: int, expected_id: StringName) -> void:
	if _session_applied:
		return
	if (
		_recruitment_state != RecruitmentState.PLACEMENT_OPEN
		or is_autosave_blocked()
		or not is_instance_valid(_pending_recruit)
		or _pending_recruit.character_id != expected_id
	):
		return
	var candidate: RunRoster = RunRoster.new(_roster.get_slot_snapshot())
	if candidate.try_add_at(_pending_recruit, destination_slot) == RunRoster.AddResult.ADDED:
		_commit_recruitment_candidate(candidate)


func _on_recruitment_replace_requested(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName
) -> void:
	if _session_applied:
		return
	if (
		_recruitment_state != RecruitmentState.PLACEMENT_OPEN
		or is_autosave_blocked()
		or not is_instance_valid(_pending_recruit)
		or _pending_recruit.character_id != expected_recruit_id
	):
		return
	var candidate: RunRoster = RunRoster.new(_roster.get_slot_snapshot())
	if (
		candidate.try_replace_at(
			_pending_recruit,
			destination_slot,
			expected_character_id
		)
		== RunRoster.ReplaceResult.REPLACED
	):
		_commit_recruitment_candidate(candidate)


func _commit_recruitment_candidate(candidate: RunRoster) -> void:
	if _session_applied:
		return
	_recruitment_state = RecruitmentState.PLACEMENT_CONFIRMED
	_pending_recruitment_roster = candidate
	if not is_instance_valid(_save_coordinator):
		_publish_recruitment_without_persistence()
		return
	var candidate_state := _build_candidate_state(_model, false, candidate)
	var saved: Dictionary = _save_coordinator.call(
		"commit_candidate",
		candidate_state,
		Callable(self, "_publish_recruitment_state"),
		"recruitment_completion"
	)
	if bool(saved.get("ok", false)):
		return
	_recruitment_state = RecruitmentState.SAVE_FAILED
	_model.set_surface_blocked(true)
	_apply_snapshot(_model.get_snapshot())
	autosave_failed.emit(saved.get("error") as RefCounted)


func _publish_recruitment_without_persistence() -> void:
	if not is_instance_valid(_pending_recruitment_roster):
		return
	_roster = _pending_recruitment_roster
	_finish_recruitment_publication()


func _publish_recruitment_state(state: RefCounted) -> void:
	if not is_instance_valid(_pending_recruitment_roster) or not is_instance_valid(state):
		return
	_roster = _pending_recruitment_roster
	_durable_run_state = state
	_finish_recruitment_publication()


func _finish_recruitment_publication() -> void:
	_recruitment_state = RecruitmentState.REWARD_COMPLETED
	var option := _pending_recruitment_option
	_close_recruitment_party(false)
	if has_active_battle() and is_instance_valid(option):
		_active_battle.complete_pending_recruitment(option)


func _on_recruitment_cancelled() -> void:
	if _recruitment_state != RecruitmentState.PLACEMENT_OPEN:
		return
	var option := _pending_recruitment_option
	_recruitment_state = RecruitmentState.PLACEMENT_CANCELLED
	_close_recruitment_party(false)
	if has_active_battle() and is_instance_valid(option):
		_active_battle.restore_pending_recruitment(option)
	_recruitment_state = RecruitmentState.REWARD_SELECTED


func _close_recruitment_party(reset_state: bool = true) -> void:
	if has_active_party_management():
		_active_party.queue_free()
	_active_party = null
	_pending_recruitment_option = null
	_pending_recruit = null
	_pending_recruitment_roster = null
	if reset_state:
		_recruitment_state = RecruitmentState.IDLE


func _on_battle_closed() -> void:
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return
	if not has_active_battle():
		return
	_active_battle.queue_free()
	_active_battle = null
	_close_recruitment_party(_recruitment_state != RecruitmentState.REWARD_COMPLETED)
	_model.close_ordinary_encounter()
	if not _battle_settled and not _commit_current_authoritative("encounter_resolution", true):
		return
	_apply_snapshot(_model.get_snapshot())


func _on_party_move_requested(source_slot: int, destination_slot: int, character_id: StringName) -> void:
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return
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
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or has_pending_gold_reward():
		return
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
	_apply_snapshot(_model.get_snapshot())


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


func _build_candidate_state(
	model: WorldRuntimeModel,
	consume_current: bool,
	roster: RunRoster = null,
	accrue_cache: bool = false,
	health_override: Dictionary[StringName, int] = {}
) -> RefCounted:
	if not is_instance_valid(_durable_run_state) or not is_instance_valid(model):
		return null
	var data: Dictionary = _durable_run_state.call("to_dictionary") as Dictionary
	var snapshot: WorldRuntimeSnapshot = model.get_snapshot()
	data["player_coord"] = [snapshot.player_coord.x, snapshot.player_coord.y]
	data["boss_coord"] = [snapshot.boss_coord.x, snapshot.boss_coord.y]
	data["move_count"] = snapshot.move_count
	data["boss_active"] = snapshot.sudden_death_active
	data["boss_engaged"] = snapshot.boss_encounter_open
	data["formation"] = _formation_ids(roster)
	var source_roster: RunRoster = roster if is_instance_valid(roster) else _roster
	var reconciled_health: Dictionary[StringName, int] = _reconcile_health_for_roster(
		source_roster, health_override
	)
	if reconciled_health.is_empty():
		return null
	var serialized_health: Dictionary = {}
	for character_id: StringName in reconciled_health:
		serialized_health[String(character_id)] = reconciled_health[character_id]
	data["character_hp"] = serialized_health
	if accrue_cache:
		var commander_id: StringName = (
			CACHE_RULES_SCRIPT.BRAKKA_ID
			if _roster.has_character(CACHE_RULES_SCRIPT.BRAKKA_ID)
			else &""
		)
		var cache_state: Dictionary = CACHE_RULES_SCRIPT.after_accepted_move(
			commander_id,
			int(data.get("cache_move_progress", 0)),
			bool(data.get("cache_ready", false))
		)
		data["cache_move_progress"] = int(cache_state.get("progress", 0))
		data["cache_ready"] = bool(cache_state.get("ready", false))
	if consume_current:
		var consumed: Array = data.get("consumed_encounters", []) as Array
		var coord_value: Array[int] = [snapshot.player_coord.x, snapshot.player_coord.y]
		if not consumed.has(coord_value):
			consumed.append(coord_value)
		data["consumed_encounters"] = consumed
		data["battle_preparation"] = PREPARATION_RECORD_SCRIPT.none().call("to_dictionary")
	var decoded: Dictionary = RUN_STATE_SCRIPT.from_dictionary(data, _runtime_plan)
	return decoded.get("value") as RefCounted if bool(decoded.get("ok", false)) else null


func _initialize_or_validate_durable_health(run_state: RefCounted) -> bool:
	var current: Dictionary[StringName, int] = run_state.call("get_character_hp_snapshot")
	var expected_ids: Dictionary[StringName, RunCharacter] = {}
	for character: RunCharacter in _roster.get_characters():
		expected_ids[character.character_id] = character
	if not bool(run_state.call("has_character_hp_snapshot")):
		var initialized: Dictionary[StringName, int] = {}
		for character_id: StringName in expected_ids:
			initialized[character_id] = expected_ids[character_id].max_hp
		return bool(run_state.call("set_character_hp_snapshot", initialized))
	if current.size() != expected_ids.size():
		return false
	for character_id: StringName in current:
		if not expected_ids.has(character_id):
			return false
		var hp: int = current[character_id]
		if hp < 1 or hp > expected_ids[character_id].max_hp:
			return false
	return true


func _reconcile_health_for_roster(
	roster: RunRoster,
	health_override: Dictionary[StringName, int] = {}
) -> Dictionary[StringName, int]:
	if not is_instance_valid(roster):
		return {}
	var existing: Dictionary[StringName, int] = health_override
	if existing.is_empty() and is_instance_valid(_durable_run_state):
		existing = _durable_run_state.call("get_character_hp_snapshot")
	var result: Dictionary[StringName, int] = {}
	for character: RunCharacter in roster.get_characters():
		var hp: int = int(existing.get(character.character_id, character.max_hp))
		if hp < 1 or hp > character.max_hp:
			return {}
		result[character.character_id] = hp
	if not health_override.is_empty() and existing.size() != result.size():
		return {}
	return result


func _calculate_recovered_health(
	terminal_snapshot: Array[Dictionary]
) -> Dictionary[StringName, int]:
	if terminal_snapshot.size() != _roster.size():
		return {}
	var roster_by_id: Dictionary[StringName, RunCharacter] = {}
	for character: RunCharacter in _roster.get_characters():
		roster_by_id[character.character_id] = character
	var recovered: Dictionary[StringName, int] = {}
	for entry: Dictionary in terminal_snapshot:
		var character_id: StringName = entry.get("character_id", &"") as StringName
		if character_id.is_empty() or recovered.has(character_id) or not roster_by_id.has(character_id):
			return {}
		var character: RunCharacter = roster_by_id[character_id]
		var final_hp_value: Variant = entry.get("final_hp")
		var max_hp_value: Variant = entry.get("max_hp")
		if (
			not final_hp_value is int
			or not max_hp_value is int
			or int(max_hp_value) != character.max_hp
		):
			return {}
		var next_hp: int = RECOVERY_RULES_SCRIPT.calculate_next_hp(
			character_id, int(final_hp_value), int(max_hp_value)
		)
		if next_hp < 1:
			return {}
		recovered[character_id] = next_hp
	return recovered if recovered.size() == roster_by_id.size() else {}


func _formation_ids(roster: RunRoster = null) -> Array[String]:
	var source: RunRoster = roster if is_instance_valid(roster) else _roster
	var formation: Array[String] = []
	for character: RunCharacter in source.get_slot_snapshot():
		formation.append(String(character.character_id) if is_instance_valid(character) else "")
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
	hud.set_gold_balance(int(_durable_run_state.get("gold")) if is_instance_valid(_durable_run_state) else 0)
	var cache_progress: int = 0
	var cache_ready: bool = false
	if is_instance_valid(_durable_run_state):
		cache_progress = int(_durable_run_state.get("cache_move_progress"))
		cache_ready = bool(_durable_run_state.get("cache_ready"))
	hud.set_cache_state(
		_roster.has_character(CACHE_RULES_SCRIPT.BRAKKA_ID), cache_progress, cache_ready
	)
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


func has_pending_gold_reward() -> bool:
	return is_instance_valid(_durable_run_state) and not String(_durable_run_state.get("pending_reward_battle_id")).is_empty()


func _wire_gold_panel() -> void:
	_gold_panel = get_node_or_null("GoldRewardHost/BattleGoldRewardPanel") as Control
	if not is_instance_valid(_gold_panel):
		_fail_integration()
		return
	if _gold_ack_callback.is_valid() and _gold_panel.acknowledgement_requested.is_connected(_gold_ack_callback):
		_gold_panel.acknowledgement_requested.disconnect(_gold_ack_callback)
	_gold_ack_callback = _on_bound_gold_acknowledgement.bind(_session_generation, _gold_panel)
	_gold_panel.acknowledgement_requested.connect(_gold_ack_callback)


func _on_bound_gold_acknowledgement(battle_id: String, generation: int, source: Control) -> void:
	if generation != _session_generation or not is_instance_valid(source) or source != _gold_panel:
		return
	acknowledge_gold_reward(battle_id)


func _present_pending_gold_reward() -> void:
	if not has_pending_gold_reward() or not is_instance_valid(_gold_panel):
		return
	var battle_id: String = _durable_run_state.pending_reward_battle_id
	for receipt: Dictionary in _durable_run_state.battle_settlements:
		if receipt.battle_id != battle_id:
			continue
		if has_active_battle():
			_active_battle.set_settlement_committed()
		_model.set_surface_blocked(true)
		_gold_panel.present(battle_id, int(receipt.earned_gold))
		_apply_snapshot(_model.get_snapshot())
		return
	_fail_integration()


func acknowledge_gold_reward(battle_id: String) -> Dictionary:
	if _integration_failed or _terminal_phase != TerminalPhase.PLAYING or is_autosave_blocked() or not _session_applied:
		return {"ok": false, "value": null, "error": "reward_blocked"}
	var built: Dictionary = ACKNOWLEDGEMENT_RULES.build_candidate(_durable_run_state, _runtime_plan, battle_id)
	if not built.get("ok", false) or built.get("duplicate", false):
		return built
	_pending_ack_id = battle_id
	_gold_panel.set_saving(true)
	var saved: Dictionary = _save_coordinator.commit_candidate(
		built.value, Callable(self, "_publish_reward_acknowledgement").bind(_session_generation, battle_id),
		"battle_reward_acknowledgement", true
	)
	if not saved.get("ok", false):
		if not is_autosave_blocked():
			_fail_integration()
		else:
			autosave_failed.emit(saved.get("error") as RefCounted)
	return saved


func _publish_reward_acknowledgement(state: RefCounted, generation: int, battle_id: String) -> void:
	if generation != _session_generation or battle_id != _pending_ack_id or not has_pending_gold_reward():
		return
	if _durable_run_state.pending_reward_battle_id != battle_id or not is_instance_valid(state):
		return
	var expected: Dictionary = _durable_run_state.to_dictionary()
	expected["pending_reward_battle_id"] = ""
	if state.to_dictionary() != expected:
		_fail_integration()
		return
	_durable_run_state = state
	_pending_ack_id = ""
	_gold_panel.dismiss()
	if has_active_battle():
		_active_battle.queue_free()
		_active_battle = null
	_close_recruitment_party()
	_pending_battle_receipt = {}
	_battle_settled = false
	_active_battle_recovery_handled = false
	_model.restore_run_state(state)
	_model.set_surface_blocked(has_active_encounter() or has_active_party_management())
	_apply_snapshot(_model.get_snapshot())


func _invalidate_gold_callbacks() -> void:
	_session_generation += 1
	if is_instance_valid(_gold_panel) and _gold_ack_callback.is_valid() and _gold_panel.acknowledgement_requested.is_connected(_gold_ack_callback):
		_gold_panel.acknowledgement_requested.disconnect(_gold_ack_callback)
	_gold_ack_callback = Callable()
	_pending_ack_id = ""


func _exit_tree() -> void:
	_invalidate_gold_callbacks()
