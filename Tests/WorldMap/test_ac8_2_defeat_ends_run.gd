extends SceneTree

var failures: int = 0
var returns: int = 0

class Repository:
	extends RefCounted
	var writes: Array[PackedByteArray] = []
	var fail_count: int = 0
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes.append(bytes.duplicate())
		if fail_count > 0:
			fail_count -= 1
			return {"ok":false,"value":null,"error":load("res://Scripts/Save/world_save_error.gd").new("SAVE_ENVELOPE_INVALID","injected")}
		return {"ok":true,"value":null,"error":null}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for kind: String in ["combat", "boss"]:
		await _case(kind, false)
		await _case(kind, true)
	if failures == 0:
		print("PASS test_ac8_2_defeat_ends_run")
	quit(0 if failures == 0 else 1)

func _case(kind: String, fail: bool) -> void:
	returns = 0
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass).start("golden-alpha")
	var plan: WorldPlan = session.plan
	var state: RefCounted = session.run_state
	var coord: Vector2i = plan.get_boss_coord()
	if kind == "combat":
		for key: Vector2i in plan.get_cells():
			if plan.get_cells()[key].get("encounter") == "combat":
				coord = key
				break
	state.player_coord = coord
	state.boss_engaged = kind == "boss"
	var repository := Repository.new()
	var world: WorldRuntimeController = load("res://Scenes/world_map_runtime.tscn").instantiate()
	world.auto_initialize_runtime = false
	root.add_child(world)
	await process_frame
	_expect(world.apply_session({"plan":plan,"run_state":state,"resolved_seed":"golden-alpha"},repository),"apply session")
	world.launcher_return_requested.connect(func() -> void: returns += 1)
	world.call("_on_battle_requested", coord, kind)
	await process_frame
	var arena: BattleArena = world.get_node("BattleHost").get_child(0)
	var health: Dictionary = world.get_durable_run_state().get_character_hp_snapshot()
	var units: Array[BattleUnitState] = arena.get("_units")
	if fail:
		var partial_units: Array[BattleUnitState] = []
		for unit: BattleUnitState in units:
			if unit.side == BattleUnitState.Side.PLAYER:
				unit.speed = 100
				partial_units.append(unit)
		partial_units.append(BattleUnitState.new(&"partial_enemy", "Enemy", 1, 0, 1, 1))
		partial_units.append(BattleUnitState.new(&"surviving_enemy", "Enemy", 1, 1, 1, 100))
		units = partial_units
		arena.configure_units(units)
		var row: int = arena.get_current_unit().slot_index % 3
		arena.get_unit_by_id(&"partial_enemy").slot_index = row
		arena.get_unit_by_id(&"surviving_enemy").slot_index = (row + 1) % 3
		arena.perform_debug_damage()
		_expect(not arena.is_battle_complete(), "partial enemy kill does not end fight")
	for unit: BattleUnitState in units:
		if unit.side == BattleUnitState.Side.PLAYER:
			unit.current_hp = 0
	repository.fail_count = 2 if fail else 0
	arena.call("_complete_battle", BattleOutcome.Type.DEFEAT)
	await process_frame
	if fail:
		_expect(world.is_autosave_blocked(), "loss save failure blocks")
		_expect(returns == 0, "no early menu return")
		_expect(not world.discard_pending_autosave(), "loss cannot discard")
		world.call("_on_autosave_return_requested")
		world.call("_on_battle_closed")
		_expect(returns == 0 and world.has_active_battle(), "direct exits cannot bypass")
		_expect(not world.configure_runtime(plan), "pending loss rejects runtime replacement")
		_expect(not world.configure_persistence("other", state, Repository.new()), "pending loss retains repository binding")
		var before: PackedByteArray = repository.writes.back()
		var write_count: int = repository.writes.size()
		world.call("_on_battle_completed", BattleOutcome.Type.DEFEAT, 999, 999, arena)
		_expect(repository.writes.size() == write_count, "stale callback ignored")
		_expect(not world.retry_autosave().get("ok", true), "first retry fails")
		_expect(world.retry_autosave().get("ok", false), "second retry succeeds")
		_expect(repository.writes.back() == before, "retry identical bytes")
	_expect(returns == 1, "one menu return")
	if fail:
		_expect(world.get_durable_run_state().battle_settlements.back().defeated_enemy_ids.size() == 1, "loss records partial kill without award")
	_expect(world.get_durable_run_state().gold == 100, "loss no gold")
	_expect(world.get_durable_run_state().run_status == "lost", "durable terminal state")
	_expect(world.get_durable_run_state().get_character_hp_snapshot() == health, "no loss recovery")
	world.call("_on_battle_completed", BattleOutcome.Type.DEFEAT)
	world.call("_on_battle_closed")
	_expect(returns == 1, "duplicate callbacks no return")
	var codec: Script = load("res://Scripts/Save/world_run_save_codec_v4.gd")
	var loaded: Dictionary = codec.decode_any(repository.writes.back())
	_expect(loaded.get("ok", false) and not loaded.value.run_state.is_playable(), "disk lost is not playable")
	world.free()
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
