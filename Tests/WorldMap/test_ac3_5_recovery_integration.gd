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
	await _verify_legacy_initialization_and_victory(plan)
	await _verify_non_victory_and_autosave_recovery(plan)
	await _verify_recruitment_identity_health(plan)
	_finish()


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

	world.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
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
	var reloaded := await _create_world(plan, FakeRepository.new(), persisted)
	_expect(is_instance_valid(reloaded), "committed recovery reloads")
	if is_instance_valid(reloaded):
		reloaded.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
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
	world.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
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
	world.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
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
	world.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
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
	var world := await _create_world(plan, repository, _create_legacy_state(plan))
	var recruit := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	var add_candidate := RunRoster.new(world.get("_roster").get_slot_snapshot())
	_expect(
		add_candidate.try_add_at(recruit, 3) == RunRoster.AddResult.ADDED,
		"recruitment add fixture is valid"
	)
	world.set("_pending_recruit", recruit)
	world.call("_commit_recruitment_candidate", add_candidate)
	await process_frame
	var added: Dictionary[StringName, int] = world.get_durable_run_state().call(
		"get_character_hp_snapshot"
	)
	_expect(added.get(recruit.character_id, -1) == recruit.max_hp, "recruitment adds new ID at max HP")
	var move_id := recruit.character_id
	world.call("_on_party_move_requested", 3, 4, move_id)
	await process_frame
	_expect(
		world.get_durable_run_state().call("get_character_hp_snapshot") == added,
		"formation moves do not change identity health"
	)
	world.free()

	var full_formation := RunCharacterCatalog.get_goblin_class_ids()
	var full_state := _create_state(plan, full_formation)
	repository = FakeRepository.new()
	world = await _create_world(plan, repository, full_state)
	var replacement := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	var replace_candidate := RunRoster.new(world.get("_roster").get_slot_snapshot())
	var dismissed: RunCharacter = replace_candidate.get_character_at(0)
	_expect(
		replace_candidate.try_replace_at(replacement, 0, dismissed.character_id)
		== RunRoster.ReplaceResult.REPLACED,
		"replacement fixture is valid"
	)
	world.set("_pending_recruit", replacement)
	world.call("_commit_recruitment_candidate", replace_candidate)
	await process_frame
	var replaced: Dictionary[StringName, int] = world.get_durable_run_state().call(
		"get_character_hp_snapshot"
	)
	_expect(not replaced.has(dismissed.character_id), "replacement removes dismissed identity health")
	_expect(
		replaced.get(replacement.character_id, -1) == replacement.max_hp,
		"replacement adds recruit at max HP"
	)
	world.free()

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
		plan.get_start_coord(),
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
