extends SceneTree
var failures: int = 0

class Repository:
	extends RefCounted
	var writes: Array[PackedByteArray] = []
	var fail_next: bool = false
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes.append(bytes.duplicate())
		if fail_next:
			fail_next = false
			return {"ok":false,"value":null,"error":null}
		return {"ok":true,"value":null,"error":null}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for kind: String in ["combat", "boss"]:
		await _case(kind)
	await _case("combat", true)
	if failures == 0:
		print("PASS test_ac8_2_victory_settlement")
	quit(0 if failures == 0 else 1)

func _case(kind: String, mismatch: bool = false) -> void:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass).start("golden-alpha")
	var state: RefCounted = session.run_state
	var plan: WorldPlan = session.plan
	var coord: Vector2i = plan.get_boss_coord()
	if kind == "combat":
		for key: Vector2i in plan.get_cells():
			if plan.get_cells()[key].get("encounter") == "combat":
				coord = key
				break
	state.player_coord = coord
	state.boss_engaged = kind == "boss"
	var world: WorldRuntimeController = load("res://Scenes/world_map_runtime.tscn").instantiate()
	world.auto_initialize_runtime = false
	root.add_child(world)
	await process_frame
	var repo := Repository.new()
	_expect(world.apply_session({"plan":plan,"resolved_seed":"golden-alpha","run_state":state},repo),"session applies")
	world.call("_on_battle_requested",coord,kind)
	await process_frame
	var arena: BattleArena = world.get_node("BattleHost").get_child(0)
	var players: Array[BattleUnitState] = []
	for unit: BattleUnitState in arena.get("_units"):
		if unit.side == BattleUnitState.Side.PLAYER:
			unit.speed = 100
			unit.current_hp = maxi(1, unit.max_hp - 2)
			players.append(unit)
	var units: Array[BattleUnitState] = players.duplicate()
	for i: int in 3:
		units.append(BattleUnitState.new(StringName("enemy_%d" % i),"Enemy",1,i,1,1))
	arena.configure_units(units)
	repo.fail_next = true
	var before_health: Dictionary = world.get_durable_run_state().get_character_hp_snapshot()
	for i: int in 3:
		arena.perform_debug_damage()
	_expect(arena.get_battle_outcome() == BattleOutcome.Type.VICTORY, "real damage wins")
	_expect(world.get_durable_run_state().gold == 100, "failed award not published")
	_expect(world.get_durable_run_state().get_character_hp_snapshot() == before_health, "failed recovery not published")
	_expect(world.is_autosave_blocked(), "failed victory retained")
	_expect(not arena.get_node("%RewardOverlay").visible, "choices wait for commit")
	if mismatch:
		world.call("_on_battle_completed", BattleOutcome.Type.DEFEAT)
		_expect(world.has_integration_failed(), "mismatched callback rejects")
		_expect(not world.discard_pending_autosave(), "integration failure cannot discard")
		var count_before: int = repo.writes.size()
		world.call("_on_battle_closed")
		world.call("_on_autosave_return_requested")
		_expect(repo.writes.size() == count_before and world.has_active_battle(), "integration failure cannot close or write")
		world.free()
		await process_frame
		return
	var bytes: PackedByteArray = repo.writes.back()
	arena.battle_completed.emit(BattleOutcome.Type.VICTORY)
	_expect(repo.writes.size() == 1, "duplicate pending result no write")
	_expect(world.retry_autosave().get("ok", false), "victory retry succeeds")
	_expect(repo.writes.back() == bytes, "victory retry identical")
	_expect(world.get_durable_run_state().gold == 250, "three enemies pay 150")
	_expect(arena.get_node("%RewardOverlay").visible, "choices after commit")
	_expect(world.get_valid_destinations().is_empty(), "retry keeps world blocked while arena open")
	var count: int = repo.writes.size()
	arena.battle_completed.emit(BattleOutcome.Type.VICTORY)
	world.call("_on_battle_closed")
	_expect(repo.writes.size() == count, "duplicate and close no second settlement save")
	var committed: RefCounted = world.get_durable_run_state()
	world.free()
	var restored: WorldRuntimeController = load("res://Scenes/world_map_runtime.tscn").instantiate()
	restored.auto_initialize_runtime = false
	root.add_child(restored)
	await process_frame
	_expect(restored.apply_session({"plan":plan,"resolved_seed":"golden-alpha","run_state":committed},repo),"settled reload applies")
	_expect(restored.get_durable_run_state().gold == 250, "reload no second award")
	_expect(not restored.get_valid_destinations().is_empty(), "completed checkpoint reload usable")
	restored.free()
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
