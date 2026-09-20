class_name ClearedBattleHexRevisitTests
extends SceneTree

var failures: int = 0

class Repository:
	extends RefCounted
	var bytes: PackedByteArray = []
	func replace_atomic(value: PackedByteArray) -> Dictionary:
		bytes = value.duplicate()
		return {"ok": true, "value": null, "error": null}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass).start("golden-alpha")
	var plan: WorldPlan = session.plan
	var coord := Vector2i.ZERO
	for key: Vector2i in plan.get_cells():
		if plan.get_cells()[key].get("encounter") == "combat":
			coord = key
			break
	session.run_state.player_coord = coord
	var repo := Repository.new()
	var world: WorldRuntimeController = await _world(session, repo)
	world.call("_on_battle_requested", coord, "combat")
	await process_frame
	var arena: BattleArena = world.get_node("BattleHost").get_child(0)
	var units: Array[BattleUnitState] = []
	for unit: BattleUnitState in arena.get("_units"):
		if unit.side == BattleUnitState.Side.PLAYER:
			unit.speed = 100
			units.append(unit)
	for i: int in 3:
		units.append(BattleUnitState.new(StringName("enemy_%d" % i), "Enemy", 1, i, 1, 1))
	arena.configure_units(units)
	for i: int in 3:
		arena.perform_debug_damage()
	_expect(world.has_pending_gold_reward(), "first victory presents reward")
	_expect(world.acknowledge_gold_reward(world.get_durable_run_state().pending_reward_battle_id).get("ok", false), "first reward acknowledged")
	_expect(world.get_durable_run_state().consumed_encounters.has(coord), "victory durably consumes combat")
	_expect(not world.has_active_battle(), "first battle closes")
	var gold: int = world.get_durable_run_state().gold
	var exit_coord: Vector2i = coord
	for neighbor: Vector2i in HexWorldGeometry.get_neighbors(coord):
		if plan.get_cells().has(neighbor) and neighbor != plan.get_boss_coord():
			exit_coord = neighbor
			break
	_expect(world.request_move(exit_coord).is_accepted(), "leave cleared combat")
	world.close_active_encounter()
	await process_frame
	_expect(world.request_move(coord).is_accepted(), "return to cleared combat")
	_expect(world.get_debug_snapshot().effective_encounter == "safe", "cleared combat resolves as safe on return")
	_expect(world.get("_active_encounter").encounter_type == "safe", "return overlay offers safe encounter")
	world.close_active_encounter()
	await process_frame
	# Stale/direct battle requests must not reopen a durable victory.
	world.call("_on_battle_requested", coord, "combat")
	_expect(not world.has_active_battle(), "cleared combat rejects stale battle request")
	_expect(world.get_durable_run_state().gold == gold and not world.has_pending_gold_reward(), "revisit never awards twice")
	var decoded: Dictionary = load("res://Scripts/Save/world_run_save_codec_v5.gd").decode_any(repo.bytes)
	_expect(decoded.get("ok", false), "saved revisit decodes")
	world.free()
	await process_frame
	world = await _world(decoded.value, repo)
	_expect(world.get_debug_snapshot().effective_encounter == "safe", "Continue remembers cleared combat")
	world.call("_on_battle_requested", coord, "combat")
	_expect(not world.has_active_battle(), "Continue rejects replay")
	world.free()
	await process_frame
	# Candidate copies retain completion; reset/new plan must clear it.
	var model := WorldRuntimeModel.new()
	_expect(model.configure(plan) and model.restore_run_state(decoded.value.run_state), "model restores")
	_expect(model.duplicate_model().get_runtime_encounter_type(coord) == "safe", "candidate copy remembers completion")
	model.reset()
	_expect(model.get_runtime_encounter_type(coord) == "combat", "reset removes previous run completion")
	# Closing an encounter without victory must not clear its battle.
	var unplayed: RefCounted = session.run_state
	unplayed.consumed_encounters.append(coord)
	_expect(model.restore_run_state(unplayed), "unplayed encounter state restores")
	_expect(model.get_runtime_encounter_type(coord) == "combat", "closing without victory does not clear combat")
	if failures == 0:
		print("PASS test_cleared_battle_hex_revisit")
	quit(0 if failures == 0 else 1)

func _world(session: Dictionary, repo: RefCounted) -> WorldRuntimeController:
	var world: WorldRuntimeController = load("res://Scenes/world_map_runtime.tscn").instantiate()
	world.auto_initialize_runtime = false
	root.add_child(world)
	await process_frame
	_expect(world.apply_session(session, repo), "session applies")
	return world

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
