class_name Ac83RewardPresentationTests
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
			var error: RefCounted = load("res://Scripts/Save/world_save_error.gd").new("WRITE_FAILED", "injected")
			return {"ok": false, "value": null, "error": error}
		return {"ok": true, "value": null, "error": null}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe: Node = load("res://Scenes/world_map_runtime.tscn").instantiate()
	_expect(probe.has_method("acknowledge_gold_reward"), "durable acknowledgement API exists")
	probe.free()
	if failures > 0:
		quit(1)
		return
	for kind: String in ["combat", "boss"]:
		await _case(kind)
		await _case(kind, true)
	if failures == 0:
		print("PASS test_ac8_3_reward_presentation")
	quit(0 if failures == 0 else 1)

func _case(kind: String, discard_settlement: bool = false) -> void:
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
	var repo := Repository.new()
	var world: WorldRuntimeController = await _world(session, repo)
	world.call("_on_battle_requested", coord, kind)
	await process_frame
	var arena: BattleArena = world.get_node("BattleHost").get_child(0)
	var units: Array[BattleUnitState] = []
	for unit: BattleUnitState in arena.get("_units"):
		if unit.side == BattleUnitState.Side.PLAYER:
			unit.speed = 100
			unit.current_hp = maxi(1, unit.max_hp - 2)
			units.append(unit)
	for i: int in 3:
		units.append(BattleUnitState.new(StringName("enemy_%d" % i), "Enemy", 1, i, 1, 1))
	arena.configure_units(units)
	repo.fail_next = true
	var before_health: Dictionary = world.get_durable_run_state().get_character_hp_snapshot()
	for i: int in 3:
		arena.perform_debug_damage()
	var panel: Control = world.get_node("GoldRewardHost/BattleGoldRewardPanel")
	_expect(world.is_autosave_blocked() and not panel.visible, "failed settlement no presentation")
	_expect(world.get_durable_run_state().gold == 100, "failed settlement no gold publication")
	_expect(world.get_durable_run_state().get_character_hp_snapshot() == before_health, "failed settlement no recovery")
	var settlement_bytes: PackedByteArray = repo.writes.back()
	var old_settlement_callback: Callable = world.get("_save_coordinator").get("_pending_publish")
	arena.battle_completed.emit(BattleOutcome.Type.VICTORY)
	_expect(repo.writes.size() == 1, "duplicate pending result no write")
	repo.fail_next = true
	_expect(not world.retry_autosave().get("ok", false), "settlement retry fails again")
	_expect(repo.writes.back() == settlement_bytes and not panel.visible and world.get_durable_run_state().gold == 100, "failed settlement retry retains frozen candidate")
	if discard_settlement:
		var returns: Array[bool] = []
		world.launcher_return_requested.connect(func() -> void: returns.append(true))
		world.call("_on_autosave_return_requested")
		_expect(returns.size() == 1, "uncommitted settlement may Return")
		_expect(world.get_durable_run_state().gold == 100 and not world.has_pending_gold_reward() and not panel.visible, "discard cannot invent award or acknowledgement")
		world.free()
		await process_frame
		return
	_expect(world.retry_autosave().get("ok", false), "settlement retry succeeds")
	_expect(repo.writes.back() == settlement_bytes, "settlement retry frozen bytes")
	_expect(panel.visible and panel.get_node("%AmountLabel").text == "Gold received: 150g", "exact gold panel")
	_expect(not arena.get_node("%RewardOverlay").visible, "production legacy choices absent")
	var committed: RefCounted = world.get_durable_run_state()
	var before: Dictionary = committed.to_dictionary()
	var id: String = before.pending_reward_battle_id
	_expect(before.gold == 250 and not id.is_empty(), "gold and pending committed together")
	var count: int = repo.writes.size()
	world.call("_on_battle_closed")
	arena.call("_emit_exit_requested")
	world.open_party_management()
	world.call("_on_battle_requested", coord, kind)
	world.call("_on_party_move_requested", 0, 1, &"player_1")
	var option: BattleRewardOption = BattleRewardCatalog.get_options_for("combat")[0]
	for reward: BattleRewardOption in BattleRewardCatalog.get_options_for("combat"):
		if reward.kind == BattleRewardOption.Kind.RECRUITMENT:
			option = reward
	arena.select_reward(option.reward_id)
	arena.confirm_reward_selection()
	world.call("_on_reward_selected", option)
	world.call("_on_reward_confirmed", option)
	world.call("_on_recruitment_placement_requested", option)
	_expect(world.has_active_battle() and not world.has_active_party_management(), "direct close and Scout blocked")
	_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.size() == count, "bypass calls no mutation")
	_expect(world.get_valid_destinations().is_empty(), "pending blocks world")
	_expect(not world.apply_session(session, repo), "pending cannot replace session")
	_expect(not world.acknowledge_gold_reward("unknown").get("ok", false), "unknown ack rejected")
	repo.fail_next = true
	panel.get_node("%ContinueButton").pressed.emit()
	_expect(world.is_autosave_blocked() and panel.visible, "failed ack remains visible")
	_expect(world.get_durable_run_state().to_dictionary() == before, "failed ack preserves durable state")
	var ack_bytes: PackedByteArray = repo.writes.back()
	count = repo.writes.size()
	world.acknowledge_gold_reward(id)
	_expect(repo.writes.size() == count, "duplicate while saving no write")
	repo.fail_next = true
	_expect(not world.retry_autosave().get("ok", false), "repeated retry failure")
	_expect(repo.writes.back() == ack_bytes and panel.visible, "failed retry still pending")
	_expect(world.discard_pending_autosave(), "discard failed ack candidate")
	_expect(world.get_durable_run_state().to_dictionary() == before and panel.visible, "discard preserves pending presentation")
	_expect(not panel.get_node("%ContinueButton").disabled, "discard re-enables Continue")
	_expect(world.get_valid_destinations().is_empty(), "discard cannot unblock world")
	_expect(world.acknowledge_gold_reward(id).get("ok", false), "live arena acknowledgement succeeds")
	_expect(not world.has_active_battle() and not panel.visible, "live arena removed exactly once")
	_expect(world.get_durable_run_state().get_character_hp_snapshot() == committed.get_character_hp_snapshot(), "live ack no recovery replay")
	_expect(not world.get_valid_destinations().is_empty(), "live ack restores world")
	count = repo.writes.size()
	world.acknowledge_gold_reward(id)
	_expect(repo.writes.size() == count, "live duplicate ack no save")
	_expect(world.apply_session(session, repo), "replace after live acknowledgement")
	var live_replacement: Dictionary = world.get_durable_run_state().to_dictionary()
	old_settlement_callback.call(committed)
	_expect(world.get_durable_run_state().to_dictionary() == live_replacement, "captured old settlement cannot publish into replacement")
	var old_battle_generation: int = world.get("_battle_generation")
	world.free()
	await process_frame
	# Reload through codec, with no arena and no additional award.
	var codec: Script = load("res://Scripts/Save/world_run_save_codec_v5.gd")
	var decoded: Dictionary = codec.decode_any(settlement_bytes)
	_expect(decoded.get("ok", false), "pending save decodes")
	world = await _world(decoded.value, repo)
	panel = world.get_node("GoldRewardHost/BattleGoldRewardPanel")
	_expect(panel.visible and not world.has_active_battle(), "reload panel without arena")
	_expect(JSON.parse_string(world.get_durable_run_state().canonical_key()) == JSON.parse_string(JSON.stringify(before)), "reload no second award or recovery")
	_expect(world.get_valid_destinations().is_empty(), "restored panel blocks gameplay")
	world.call("_on_bound_gold_acknowledgement", id, int(world.get("_session_generation")) - 1, panel)
	_expect(world.has_pending_gold_reward(), "stale UI generation ignored")
	repo.fail_next = true
	world.acknowledge_gold_reward(id)
	var returned: Array[bool] = []
	world.launcher_return_requested.connect(func() -> void: returned.append(true))
	world.call("_on_autosave_return_requested")
	_expect(returned.size() == 1 and world.get_durable_run_state().pending_reward_battle_id == id, "Return retains durable pending")
	world.free()
	await process_frame
	world = await _world(decoded.value, repo)
	panel = world.get_node("GoldRewardHost/BattleGoldRewardPanel")
	repo.fail_next = true
	world.acknowledge_gold_reward(id)
	ack_bytes = repo.writes.back()
	_expect(world.retry_autosave().get("ok", false), "ack retry succeeds")
	_expect(repo.writes.back() == ack_bytes, "ack retry frozen bytes")
	var expected: Dictionary = before.duplicate(true)
	expected.pending_reward_battle_id = ""
	_expect(JSON.parse_string(world.get_durable_run_state().canonical_key()) == JSON.parse_string(JSON.stringify(expected)), "ack changes only pending ID")
	_expect(not panel.visible and not world.has_active_battle(), "ack dismisses and cleans arena")
	_expect(not world.get_valid_destinations().is_empty(), "ack restores input")
	count = repo.writes.size()
	world.acknowledge_gold_reward(id)
	_expect(repo.writes.size() == count and not panel.visible, "duplicate ack no write/routing")
	var acknowledged: RefCounted = world.get_durable_run_state()
	var generation: int = world.get("_session_generation")
	_expect(world.apply_session(session, repo), "acknowledged session can replace")
	var replacement: Dictionary = world.get_durable_run_state().to_dictionary()
	world.call("_publish_battle_settlement", committed, generation, old_battle_generation, null)
	world.call("_publish_reward_acknowledgement", acknowledged, generation, id)
	world.call("_on_bound_gold_acknowledgement", id, generation, panel)
	_expect(world.get_durable_run_state().to_dictionary() == replacement, "old callbacks cannot mutate replacement")
	world.free()
	await process_frame

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
