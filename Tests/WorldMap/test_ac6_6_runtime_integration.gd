class_name AC66RuntimeIntegrationTests
extends SceneTree

const WORLD_SCENE := "res://Scenes/world_map_runtime.tscn"
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")
const BRAKKA_ID := &"brakka_rustbanner"
const EXPECTED_ASSERTIONS := 18

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
	var generated := HexWorldGeneratorV1.new().generate("ac6-6-runtime")
	_expect(bool(generated.get("ok", false)), "fixture world generates")
	if not bool(generated.get("ok", false)):
		_finish()
		return
	var plan := generated.get("plan") as WorldPlan
	await _verify_atomic_combat_flow(plan)
	await _verify_excluded_encounter(plan, WorldEncounterType.SAFE)
	await _verify_excluded_encounter(plan, WorldEncounterType.BOSS)
	_finish()


func _verify_atomic_combat_flow(plan: WorldPlan) -> void:
	var repository := FakeRepository.new()
	var world := await _create_world(plan, repository)
	_expect(is_instance_valid(world), "ready Brakka session applies")
	if not is_instance_valid(world):
		return
	world.call("_on_battle_requested", plan.get_start_coord(), WorldEncounterType.COMBAT)
	await process_frame
	var arena := _get_arena(world)
	var offered := world.get_durable_run_state().get("battle_preparation") as RefCounted
	_expect(is_instance_valid(arena) and arena.is_preparation_required(), "Combat opens locked")
	_expect(
		is_instance_valid(offered) and offered.state == BattlePreparationRecord.State.OFFERED,
		"offered preparation is durable before selection"
	)
	_expect(repository.writes.size() == 1, "opening eligible Combat writes one offer")
	var identity := arena.get_setup_identity() as RefCounted
	repository.fail_next = true
	world.call(
		"_on_preparation_commit_requested",
		BattlePreparationRecord.Choice.SPARE_PLATING,
		&"",
		identity.canonical_key
	)
	await process_frame
	var failed_state := world.get_durable_run_state()
	_expect(bool(failed_state.get("cache_ready")), "failed commit keeps Cache ready")
	_expect(
		(failed_state.get("battle_preparation") as RefCounted).state
		== BattlePreparationRecord.State.OFFERED,
		"failed commit keeps offered preparation durable"
	)
	_expect(arena.is_preparation_required(), "failed commit keeps battle locked")
	_expect(world.is_autosave_blocked(), "failed commit blocks authoritative input")
	var retry: Dictionary = world.retry_autosave()
	await process_frame
	_expect(bool(retry.get("ok", false)), "retry persists retained commit")
	_expect(not bool(world.get_durable_run_state().get("cache_ready")), "retry consumes Cache")
	_expect(not arena.is_preparation_required(), "retry applies preparation and unlocks battle")
	var committed_state := world.get_durable_run_state() as RefCounted
	world.free()
	await process_frame
	var restored_world := await _create_world_from_state(plan, FakeRepository.new(), committed_state)
	_expect(restored_world.has_active_battle(), "committed preparation restores its exact battle")
	var restored_arena := _get_arena(restored_world)
	_expect(
		is_instance_valid(restored_arena) and not restored_arena.is_preparation_required(),
		"committed preparation reapplies once without relocking"
	)
	restored_world.free()


func _verify_excluded_encounter(plan: WorldPlan, encounter_type: String) -> void:
	var repository := FakeRepository.new()
	var world := await _create_world(plan, repository)
	if not is_instance_valid(world):
		_expect(false, "%s session applies" % encounter_type)
		return
	world.call("_on_battle_requested", plan.get_start_coord(), encounter_type)
	await process_frame
	var arena := _get_arena(world)
	_expect(
		is_instance_valid(arena) and not arena.is_preparation_required(),
		"%s never enters preparation" % encounter_type
	)
	_expect(repository.writes.is_empty(), "%s creates no preparation record" % encounter_type)
	world.free()


func _create_world(plan: WorldPlan, repository: FakeRepository) -> WorldRuntimeController:
	var packed := load(WORLD_SCENE) as PackedScene
	var world := packed.instantiate() as WorldRuntimeController
	root.add_child(world)
	await process_frame
	var consumed: Array[Vector2i] = []
	var formation: Array[StringName] = [BRAKKA_ID, &"", &"", &"", &"", &""]
	var state: RefCounted = RUN_STATE_SCRIPT.create(
		plan.get_start_coord(),
		plan.get_boss_coord(),
		0,
		false,
		false,
		consumed,
		formation,
		0,
		true
	)
	return await _create_world_from_state(plan, repository, state, world)


func _create_world_from_state(
	plan: WorldPlan,
	repository: FakeRepository,
	state: RefCounted,
	existing_world: WorldRuntimeController = null
) -> WorldRuntimeController:
	var world: WorldRuntimeController = existing_world
	if not is_instance_valid(world):
		var packed: PackedScene = load(WORLD_SCENE) as PackedScene
		world = packed.instantiate() as WorldRuntimeController
		root.add_child(world)
		await process_frame
	var session: Dictionary = {"plan": plan, "resolved_seed": "ac6-6-runtime", "run_state": state}
	if not world.apply_session(session, repository):
		world.free()
		return null
	return world


func _get_arena(world: WorldRuntimeController) -> BattleArena:
	var host := world.get_node("BattleHost")
	return host.get_child(0) as BattleArena if host.get_child_count() > 0 else null


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_ASSERTIONS:
		_failures.append(
			"expected %d assertions, ran %d" % [EXPECTED_ASSERTIONS, _assertions]
		)
	if _failures.is_empty():
		print("PASS test_ac6_6_runtime_integration (%d/%d)" % [_assertions, EXPECTED_ASSERTIONS])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
