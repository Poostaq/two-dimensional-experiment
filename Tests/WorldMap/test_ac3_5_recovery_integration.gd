class_name AC35RecoveryIntegrationTests
extends SceneTree

const WORLD_SCENE := "res://Scenes/world_map_runtime.tscn"
const RUN_STATE_SCRIPT: GDScript = preload("res://Scripts/Run/world_run_state.gd")

var _failures: Array[String] = []
var _assertions: int = 0


class FakeRepository:
	extends RefCounted

	var writes: Array[PackedByteArray] = []
	var fail_next: bool = false

	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes.append(bytes.duplicate())
		if fail_next:
			fail_next = false
			return {"ok": false, "value": null, "error": null}
		return {"ok": true, "value": null, "error": null}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var generated := HexWorldGeneratorV1.new().generate("ac3-5-recovery-integration")
	_expect(bool(generated.get("ok", false)), "fixture world generates")
	if not bool(generated.get("ok", false)):
		_finish()
		return
	var plan := generated.get("plan") as WorldPlan
	await _verify_missing_and_present_empty_health(plan)
	await _verify_legacy_initialization_and_victory(plan)
	await _verify_non_victory_and_autosave_recovery(plan)
	await _verify_recruitment_identity_health(plan)
	_finish()


func _verify_missing_and_present_empty_health(plan: WorldPlan) -> void:
	var missing_data: Dictionary = _create_legacy_state(plan).call("to_dictionary")
	missing_data.erase("character_hp")
	var missing_decoded: Dictionary = RUN_STATE_SCRIPT.from_dictionary(missing_data, plan)
	var missing_state := missing_decoded.get("value") as RefCounted
	_expect(
		bool(missing_decoded.get("ok", false))
		and not bool(missing_state.call("has_character_hp_snapshot")),
		"missing legacy health preserves absent-field provenance"
	)
	var migrated := await _create_world(plan, FakeRepository.new(), missing_state)
	_expect(is_instance_valid(migrated), "missing legacy health initializes successfully")
	if is_instance_valid(migrated):
		_expect(
			bool(migrated.get_durable_run_state().call("has_character_hp_snapshot")),
			"migration publishes present full health in durable state"
		)
		migrated.free()

	var present_data: Dictionary = _create_legacy_state(plan).call("to_dictionary")
	present_data["character_hp"] = {}
	var present_decoded: Dictionary = RUN_STATE_SCRIPT.from_dictionary(present_data, plan)
	var present_state := present_decoded.get("value") as RefCounted
	_expect(
		bool(present_decoded.get("ok", false))
		and bool(present_state.call("has_character_hp_snapshot")),
		"present empty health preserves present-field provenance"
	)
	var rejected := await _create_world(plan, FakeRepository.new(), present_state)
	_expect(not is_instance_valid(rejected), "present empty health rejects a nonempty roster")


func _verify_legacy_initialization_and_victory(plan: WorldPlan) -> void:
	var repository := FakeRepository.new()
	var world := await _create_world(plan, repository, _create_legacy_state(plan))
	_expect(is_instance_valid(world), "legacy session applies")
	if not is_instance_valid(world):
		return
	var initial_hp: Dictionary[StringName, int] = world.get_durable_run_state().call(
		"get_character_hp_snapshot"
	)
	var expected_initial := _catalog_health_for_formation(
		world.get_durable_run_state().get("formation") as Array[StringName]
	)
	_expect(initial_hp == expected_initial, "empty legacy health initializes every roster identity at catalog max")
	_expect(repository.writes.is_empty(), "legacy initialization avoids a gratuitous save")

	world.call("_on_battle_requested", world.get_durable_run_state().get("player_coord"), WorldEncounterType.COMBAT)
	await process_frame
	var arena := _get_arena(world)
	_expect(is_instance_valid(arena), "battle opens from initialized durable health")
	if not is_instance_valid(arena):
		world.free()
		return
	var players := _player_units(arena)
	var battle_matches := players.size() == expected_initial.size()
	for unit: BattleUnitState in players:
		battle_matches = battle_matches and unit.current_hp == expected_initial.get(unit.unit_id, -1)
	_expect(battle_matches, "battle creation passes durable health into RunRoster")

	players[0].current_hp = 0
	players[1].current_hp = max(1, players[1].max_hp - 3)
	var expected_recovery := expected_initial.duplicate()
	expected_recovery[players[0].unit_id] = PostBattleRecoveryRules.calculate_next_hp(
		players[0].unit_id, 0, players[0].max_hp
	)
	expected_recovery[players[1].unit_id] = players[1].max_hp
	arena.call("_complete_battle", BattleOutcome.Type.VICTORY)
	await process_frame
	_expect(
		world.get_durable_run_state().call("get_character_hp_snapshot") == expected_recovery,
		"victory commits full survivors and ceil-half defeated from terminal snapshot"
	)
	_expect(repository.writes.size() == 1, "victory recovery autosaves exactly once")
	world.call("_on_battle_completed", BattleOutcome.Type.VICTORY)
	world.call("_on_battle_completed", BattleOutcome.Type.VICTORY)
	await process_frame
	_expect(repository.writes.size() == 1, "duplicate completion events cannot autosave recovery twice")

	var persisted := world.get_durable_run_state()
	world.free()
	persisted.set("player_coord", _combat_coord(plan, persisted.get("consumed_encounters")))
	var reloaded := await _create_world(plan, FakeRepository.new(), persisted)
	_expect(is_instance_valid(reloaded), "committed recovery reloads")
	if is_instance_valid(reloaded):
		_expect(reloaded.has_pending_gold_reward(), "reload retains reward before next battle")
		var acknowledgement: Dictionary = reloaded.acknowledge_gold_reward(reloaded.get_durable_run_state().pending_reward_battle_id)
		_expect(acknowledgement.get("ok", false), "reward acknowledgement allows next battle")
		_expect(reloaded.get_durable_run_state().get_character_hp_snapshot() == expected_recovery, "acknowledgement preserves recovered health")
		reloaded.call("_on_battle_requested", reloaded.get_durable_run_state().get("player_coord"), WorldEncounterType.COMBAT)
		await process_frame
		var next_arena := _get_arena(reloaded)
		var next_matches := is_instance_valid(next_arena)
		if is_instance_valid(next_arena):
			for unit: BattleUnitState in _player_units(next_arena):
				next_matches = next_matches and unit.current_hp == expected_recovery.get(unit.unit_id, -1)
		_expect(next_matches, "next battle after save/reload uses committed recovery values")
		reloaded.free()


func _verify_non_victory_and_autosave_recovery(plan: WorldPlan) -> void:
	var repository := FakeRepository.new()
	var state := _create_legacy_state(plan)
	var world := await _create_world(plan, repository, state)
	var baseline: Dictionary[StringName, int] = world.get_durable_run_state().call(
		"get_character_hp_snapshot"
	)
	world.call("_on_battle_requested", world.get_durable_run_state().get("player_coord"), WorldEncounterType.COMBAT)
	await process_frame
	world.call("_on_battle_completed", BattleOutcome.Type.DEFEAT)
	_expect(
		world.get_durable_run_state().call("get_character_hp_snapshot") == baseline,
		"defeat does not mutate durable health"
	)
	world.call("_on_battle_closed")
	await process_frame
	_expect(
		world.get_durable_run_state().call("get_character_hp_snapshot") == baseline,
		"debug close does not mutate durable health"
	)
	world.free()

	repository = FakeRepository.new()
	world = await _create_world(plan, repository, _create_legacy_state(plan))
	baseline = world.get_durable_run_state().call("get_character_hp_snapshot")
	world.call("_on_battle_requested", world.get_durable_run_state().get("player_coord"), WorldEncounterType.COMBAT)
	await process_frame
	var arena := _get_arena(world)
	var defeated := _player_units(arena)[0]
	defeated.current_hp = 0
	var expected := baseline.duplicate()
	expected[defeated.unit_id] = PostBattleRecoveryRules.calculate_next_hp(
		defeated.unit_id, 0, defeated.max_hp
	)
	repository.fail_next = true
	arena.call("_complete_battle", BattleOutcome.Type.VICTORY)
	await process_frame
	_expect(
		world.get_durable_run_state().call("get_character_hp_snapshot") == baseline,
		"autosave failure keeps prior durable recovery state"
	)
	_expect(world.is_autosave_blocked(), "failed recovery retains a blocked candidate")
	var retried: Dictionary = world.retry_autosave()
	_expect(bool(retried.get("ok", false)), "recovery retry succeeds")
	_expect(
		world.get_durable_run_state().call("get_character_hp_snapshot") == expected,
		"retry publishes the retained recovery candidate"
	)
	world.free()

	repository = FakeRepository.new()
	world = await _create_world(plan, repository, _create_legacy_state(plan))
	baseline = world.get_durable_run_state().call("get_character_hp_snapshot")
	world.call("_on_battle_requested", world.get_durable_run_state().get("player_coord"), WorldEncounterType.COMBAT)
	await process_frame
	arena = _get_arena(world)
	defeated = _player_units(arena)[0]
	defeated.current_hp = 0
	repository.fail_next = true
	arena.call("_complete_battle", BattleOutcome.Type.VICTORY)
	await process_frame
	_expect(world.discard_pending_autosave(), "failed recovery candidate can be discarded")
	_expect(
		world.get_durable_run_state().call("get_character_hp_snapshot") == baseline,
		"discard drops candidate recovery"
	)
	world.free()


func _verify_recruitment_identity_health(plan: WorldPlan) -> void:
	var repository := FakeRepository.new()
	var world := await _create_legacy_preview_world(plan, repository, _create_legacy_state(plan))
	world.call("_on_battle_requested", world.get_durable_run_state().get("player_coord"), WorldEncounterType.COMBAT)
	await process_frame
	var arena := _get_arena(world)
	arena.call("_complete_battle", BattleOutcome.Type.VICTORY)
	await process_frame
	arena.select_reward(&"combat_recruit_scout")
	arena.confirm_reward_selection()
	await process_frame
	_expect(world.has_active_party_management(), "legacy recruit preview opens placement UI")
	var party := world.get_node("PartyHost").get_child(0) as PartyManagement
	party.request_placement(3, &"scout")
	await process_frame
	var added: Dictionary[StringName, int] = world.get_durable_run_state().call(
		"get_character_hp_snapshot"
	)
	var recruit := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	_expect(added.get(recruit.character_id, -1) == recruit.max_hp, "public recruitment adds new ID at max HP")
	world.open_party_management()
	await process_frame
	var normal_party := world.get_node("PartyHost").get_child(0) as PartyManagement
	normal_party.move_requested.emit(3, 4, recruit.character_id)
	await process_frame
	_expect(
		world.get_durable_run_state().call("get_character_hp_snapshot") == added,
		"public formation move does not change identity health"
	)
	normal_party.close_requested.emit()
	await process_frame
	world.free()

	var full_formation := RunCharacterCatalog.get_goblin_class_ids()
	var full_state := _create_state(plan, full_formation)
	repository = FakeRepository.new()
	world = await _create_legacy_preview_world(plan, repository, full_state)
	world.call("_on_battle_requested", world.get_durable_run_state().get("player_coord"), WorldEncounterType.COMBAT)
	await process_frame
	arena = _get_arena(world)
	arena.call("_complete_battle", BattleOutcome.Type.VICTORY)
	await process_frame
	arena.select_reward(&"combat_recruit_scout")
	arena.confirm_reward_selection()
	await process_frame
	_expect(world.has_active_party_management(), "legacy full roster preview opens replacement UI")
	party = world.get_node("PartyHost").get_child(0) as PartyManagement
	var dismissed_id: StringName = world.get_durable_run_state().get("formation")[0]
	party.request_replacement(0, dismissed_id, &"scout")
	await process_frame
	var replaced: Dictionary[StringName, int] = world.get_durable_run_state().call(
		"get_character_hp_snapshot"
	)
	_expect(not replaced.has(dismissed_id), "public replacement removes dismissed identity health")
	_expect(
		replaced.get(recruit.character_id, -1) == recruit.max_hp,
		"public replacement adds recruit at max HP"
	)
	world.free()


func _combat_coord(plan: WorldPlan, excluded: Array = []) -> Vector2i:
	for coord: Vector2i in plan.get_cells():
		if plan.get_cells()[coord].get("encounter") == WorldEncounterType.COMBAT and not excluded.has(coord):
			return coord
	_expect(false, "fixture has an unconsumed combat cell")
	return plan.get_start_coord()


func _create_legacy_state(plan: WorldPlan) -> RefCounted:
	var formation: Array[StringName] = []
	for character: RunCharacter in RunCharacterCatalog.create_starters():
		formation.append(character.character_id)
	return _create_state(plan, formation)


func _create_state(plan: WorldPlan, source_formation: Array[StringName]) -> RefCounted:
	var formation: Array[StringName] = source_formation.duplicate()
	while formation.size() < RunRoster.MAX_ROSTER_SIZE:
		formation.append(&"")
	var consumed: Array[Vector2i] = []
	return RUN_STATE_SCRIPT.create(
		_combat_coord(plan),
		plan.get_boss_coord(),
		0,
		false,
		false,
		consumed,
		formation
	)


func _create_world(
	plan: WorldPlan,
	repository: FakeRepository,
	state: RefCounted
) -> WorldRuntimeController:
	var packed: PackedScene = load(WORLD_SCENE) as PackedScene
	var world: WorldRuntimeController = (
		packed.instantiate() as WorldRuntimeController if is_instance_valid(packed) else null
	)
	if not is_instance_valid(world):
		return null
	root.add_child(world)
	await process_frame
	var session: Dictionary = {
		"plan": plan,
		"resolved_seed": "ac3-5-recovery-integration",
		"run_state": state,
	}
	if not world.apply_session(session, repository):
		world.free()
		return null
	return world

	
func _create_legacy_preview_world(
	plan: WorldPlan,
	repository: FakeRepository,
	state: RefCounted
) -> WorldRuntimeController:
	var world: WorldRuntimeController = load(WORLD_SCENE).instantiate()
	world.auto_initialize_runtime = false
	root.add_child(world)
	await process_frame
	# Isolate legacy recruitment infrastructure from the production gold flow.
	_expect(world.configure_runtime(plan), "legacy preview runtime configures")
	_expect(world.call("_restore_roster", state), "legacy preview restores roster identities")
	_expect(world.call("_initialize_or_validate_durable_health", state), "legacy preview initializes durable health")
	_expect(world.configure_persistence("ac3-5-recovery-integration", state, repository), "legacy preview configures persistence")
	_expect(not world.is_session_applied(), "recruitment health fixture is explicitly nonproduction")
	return world


func _catalog_health_for_formation(
	formation: Array[StringName]
) -> Dictionary[StringName, int]:
	var result: Dictionary[StringName, int] = {}
	for character: RunCharacter in RunCharacterCatalog.create_starters():
		if formation.has(character.character_id):
			result[character.character_id] = character.max_hp
	return result


func _get_arena(world: WorldRuntimeController) -> BattleArena:
	var host := world.get_node("BattleHost")
	return host.get_child(0) as BattleArena if host.get_child_count() > 0 else null


func _player_units(arena: BattleArena) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for unit: BattleUnitState in arena.get_turn_queue():
		if unit.side == BattleUnitState.Side.PLAYER:
			result.append(unit)
	return result


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS test_ac3_5_recovery_integration (%d/%d)" % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
