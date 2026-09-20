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
			return {"ok": false, "value": null, "error": null}
		return {"ok": true, "value": null, "error": null}

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var script: Script = load("res://Scripts/WorldMap/world_runtime_controller.gd")
	if not script.has_method("new"):
		quit(1)
		return
	var probe: Node = script.new()
	if not probe.has_method("get_town_recruitment_context"):
		probe.free()
		print("FAIL: missing production town recruitment API")
		quit(1)
		return
	probe.free()
	for gold: int in [499, 500, 750]:
		await _purchase_case(gold)
	await _retry_case(false)
	await _retry_case(true)
	await _availability_case()
	await _contract_case()
	await _replacement_case()
	await _arrival_case()
	if failures == 0:
		print("PASS test_ac8_town_recruitment")
	quit(0 if failures == 0 else 1)

func _session(gold: int) -> Dictionary:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass).start("golden-alpha")
	var plan: WorldPlan = session.plan
	for coord: Vector2i in plan.get_cells():
		if plan.get_cells()[coord].town_index >= 0 and coord != plan.get_boss_coord():
			session.run_state.player_coord = coord
			break
	session.run_state.gold = gold
	return session

func _open(session: Dictionary, repo: Repository) -> WorldRuntimeController:
	var world: WorldRuntimeController = load("res://Scenes/world_map_runtime.tscn").instantiate()
	world.auto_initialize_runtime = false
	root.add_child(world)
	await process_frame
	_expect(world.apply_session(session, repo), "production session applies")
	return world

func _purchase_case(gold: int) -> void:
	var repo := Repository.new()
	var session := _session(gold)
	var world := await _open(session, repo)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var context: Dictionary = world.call("get_town_recruitment_context")
	_expect(context.ok and context.clan_id == &"goblin", "available Goblin town")
	_expect(not context.class_ids.has(&"scrapshield_bruiser") and context.class_ids.has(&"scrapbroker"), "canonical starter exclusion")
	_expect(world.call("open_town_recruitment"), "open town")
	_expect(not world.request_move(world.get_runtime_snapshot().player_coord + Vector2i(1, 0)).is_accepted(), "town modal blocks movement")
	world.open_party_management()
	_expect(not world.has_active_party_management(), "town blocks unrelated party")
	world.call("close_town_recruitment")
	world.call("close_town_recruitment")
	_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.is_empty(), "close twice is a domain no-op")
	_expect(world.call("open_town_recruitment"), "reopen without move")
	var result: Dictionary = world.call("request_town_recruitment", &"scrapbroker")
	if gold < 500:
		_expect(not result.ok and result.error == &"insufficient_gold", "499g rejects")
		_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.is_empty(), "poor purchase unchanged")
	else:
		_expect(result.ok and world.has_active_party_management(), "selection opens placement")
		var party: PartyManagement = world.get("_active_party")
		party.request_placement_cancel()
		_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.is_empty(), "cancel no mutation/write")
		_expect(world.call("request_town_recruitment", &"scrapbroker").ok, "selection after cancel")
		party = world.get("_active_party")
		party.request_placement(5, &"scrapbroker")
		party.placement_requested.emit(5, &"scrapbroker")
		var after: Dictionary = world.get_durable_run_state().to_dictionary()
		_expect(after.gold == gold - 500 and after.formation[5] == "scrapbroker", "exact price and chosen slot")
		_expect(repo.writes.size() == 1, "duplicate placement only one write")
		var expected: Dictionary = before.duplicate(true)
		expected.gold = gold - 500
		expected.formation[5] = "scrapbroker"
		expected.character_hp["scrapbroker"] = RunCharacterCatalog.create_by_class_id(&"scrapbroker").max_hp
		_expect(after == expected, "purchase changes only gold formation and recruit HP")
		_expect(not world.call("get_town_recruitment_context").class_ids.has(&"scrapbroker"), "offers refresh")
		var loaded: Dictionary = load("res://Scripts/Save/world_run_save_codec_v5.gd").decode_any(repo.writes.back())
		_expect(loaded.ok, "purchase bytes decode")
		world.free()
		await process_frame
		world = await _open(loaded.value, repo)
		_expect(world.call("open_town_recruitment"), "reopen after Continue")
		_expect(world.get_durable_run_state().to_dictionary() == after and repo.writes.size() == 1, "Continue no second charge")
	world.free()
	await process_frame

func _retry_case(discard: bool) -> void:
	var repo := Repository.new()
	var world := await _open(_session(500), repo)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	world.call("open_town_recruitment")
	world.call("request_town_recruitment", &"scrapbroker")
	var party: PartyManagement = world.get("_active_party")
	repo.fail_next = true
	party.request_placement(5, &"scrapbroker")
	_expect(world.is_autosave_blocked(), "failed save blocked")
	world.call("close_town_recruitment")
	party.request_placement_cancel()
	_expect(world.get_durable_run_state().to_dictionary() == before, "failed save/cancel leaves live state unchanged")
	_expect(world.has_active_party_management(), "pending save cannot cancel")
	if discard:
		_expect(world.discard_pending_autosave(), "discard succeeds")
		_expect(world.get_durable_run_state().to_dictionary() == before, "discard restores old state")
		party.placement_requested.emit(5, &"scrapbroker")
		_expect(repo.writes.size() == 1, "discard invalidates old callback")
	else:
		_expect(world.retry_autosave().ok, "retry succeeds")
		_expect(repo.writes.size() == 2 and repo.writes[0] == repo.writes[1], "retry exact candidate bytes")
		_expect(world.get_durable_run_state().gold == 0, "retry charge once")
		_expect(world.get_valid_destinations().is_empty(), "retry retains town modal movement lock")
	world.free()
	await process_frame

func _availability_case() -> void:
	var repo := Repository.new()
	var session := _session(500)
	var world := await _open(session, repo)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var plan: WorldPlan = session.plan
	for coord: Vector2i in plan.get_cells():
		if plan.get_cells()[coord].town_index == -1 and plan.get_cells()[coord].encounter == "safe":
			session.run_state.player_coord = coord
			break
	_expect(world.apply_session(session, repo), "safe-cell session applies")
	var context: Dictionary = world.call("get_town_recruitment_context")
	_expect(not context.ok and context.error == &"not_a_town" and context.class_ids.is_empty() and context.clan_id == &"", "generic safe cell rejects")
	_expect(not world.call("open_town_recruitment"), "safe cell cannot open")
	session.run_state.player_coord = Vector2i(before.player_coord[0], before.player_coord[1])
	_expect(world.apply_session(session, repo), "town session reapplies")
	world.call("open_town_recruitment")
	world.call("request_town_recruitment", &"scrapbroker")
	var old_party: PartyManagement = world.get("_active_party")
	_expect(world.apply_session(session, repo), "new session invalidates selection")
	old_party.placement_requested.emit(5, &"scrapbroker")
	_expect(repo.writes.is_empty() and world.get_durable_run_state().gold == 500, "stale session callback rejects")
	world.free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _contract_case() -> void:
	var repo := Repository.new()
	var session := _session(500)
	var world := await _open(session, repo)
	var plan: WorldPlan = session.plan
	var codec: Script = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
	var bytes: PackedByteArray = codec.serialize(plan)
	var tested: int = 0
	for coord: Vector2i in plan.get_cells():
		if plan.get_cells()[coord].town_index < 0:
			continue
		session.run_state.player_coord = coord
		_expect(world.apply_session(session, repo), "all-town session applies")
		var before: Dictionary = world.get_durable_run_state().to_dictionary()
		var context: Dictionary = world.call("get_town_recruitment_context")
		_expect(context.ok and context.clan_id == &"goblin", "every v1 town available")
		world.call("open_town_recruitment")
		world.call("close_town_recruitment")
		_expect(world.get_durable_run_state().to_dictionary() == before and codec.serialize(plan) == bytes and repo.writes.is_empty(), "town close preserves all durable domain state and topology")
		tested += 1
	_expect(tested == 7, "seven town services checked")
	world.set("_terminal_phase", WorldRuntimeController.TerminalPhase.LOSS_COMMITTING)
	_expect(world.call("get_town_recruitment_context").error == &"service_blocked", "terminal transition denies service")
	world.set("_terminal_phase", WorldRuntimeController.TerminalPhase.PLAYING)
	world.get_durable_run_state().pending_reward_battle_id = "unacknowledged"
	_expect(world.call("get_town_recruitment_context").error == &"service_blocked", "pending reward denies service")
	world.get_durable_run_state().pending_reward_battle_id = ""
	var encounter: EncounterOverlay = load("res://Scenes/encounter_overlay.tscn").instantiate()
	world.set("_active_encounter", encounter)
	_expect(world.call("get_town_recruitment_context").error == &"service_blocked", "ordinary encounter denies service")
	world.set("_active_encounter", null)
	encounter.free()
	var battle: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	world.set("_active_battle", battle)
	_expect(world.call("get_town_recruitment_context").error == &"service_blocked", "active battle denies service")
	world.set("_active_battle", null)
	battle.free()
	var model: WorldRuntimeModel = world.get("_model")
	var coord: Vector2i = world.get_durable_run_state().player_coord
	for version: int in [0, 2, 99]:
		var unsupported: WorldPlan = load("res://Scripts/WorldMap/world_plan.gd").new(version, plan.get_seed_hex(), plan.get_start_coord(), plan.get_boss_coord(), plan.get_cells(), plan.get_roads(), plan.get_forest_clusters())
		model.set("_plan", unsupported)
		world.set("_runtime_plan", unsupported)
		_expect(world.call("get_town_recruitment_context").error == &"unsupported_world_version", "unknown version fails closed")
	model.set("_plan", plan)
	world.set("_runtime_plan", plan)
	world.get_durable_run_state().player_coord = Vector2i(999, 999)
	_expect(world.call("get_town_recruitment_context").error == &"invalid_coordinate", "off-map service fails")
	world.get_durable_run_state().player_coord = coord
	model.set("_boss_coord", coord)
	_expect(world.call("get_town_recruitment_context").error == &"service_blocked", "boss collision overrides town")
	model.set("_boss_coord", session.run_state.boss_coord)
	world.open_party_management()
	_expect(world.call("get_town_recruitment_context").error == &"service_blocked", "unrelated party blocks service")
	world.call("_on_party_close_requested")
	await process_frame
	world.call("_open_encounter", coord, "safe")
	_expect(world.call("has_active_town_recruitment"), "town routing uses API")
	world.call("close_town_recruitment")
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	world.call("open_town_recruitment")
	world.call("request_town_recruitment", &"scrapbroker")
	var party: PartyManagement = world.get("_active_party")
	_expect(world.call("get_town_recruitment_context").ok, "matching town placement permits revalidation")
	party.placement_requested.emit(-1, &"scrapbroker")
	party.placement_requested.emit(0, &"scrapbroker")
	party.placement_requested.emit(5, &"wrong")
	_expect(world.get_durable_run_state().to_dictionary() == before, "invalid slots/recruit leave state unchanged")
	party.close_requested.emit()
	_expect(world.get_durable_run_state().to_dictionary() == before, "placement dismissal leaves domain unchanged")
	_expect(repo.writes.is_empty(), "availability and rejection checks write nothing")
	world.free()
	await process_frame

func _replacement_case() -> void:
	var repo := Repository.new()
	var session := _session(750)
	var data: Dictionary = session.run_state.to_dictionary()
	data.formation = ["player_0", "player_1", "player_2", "scout", "champion", "shivrunner"]
	var all: Array[RunCharacter] = RunCharacterCatalog.create_starters()
	all.append(RunCharacterCatalog.create_for_reward(RunCharacterCatalog.COMBAT_SCOUT_REWARD_ID))
	all.append(RunCharacterCatalog.create_for_reward(RunCharacterCatalog.BOSS_CHAMPION_REWARD_ID))
	all.append(RunCharacterCatalog.create_by_class_id(&"shivrunner"))
	data.character_hp = {}
	for character: RunCharacter in all:
		data.character_hp[String(character.character_id)] = character.max_hp
	session.run_state = load("res://Scripts/Run/world_run_state.gd").from_dictionary(data, session.plan).value
	var world := await _open(session, repo)
	world.call("open_town_recruitment")
	_expect(world.call("request_town_recruitment", &"scrapbroker").ok, "full roster can select absent class")
	var party: PartyManagement = world.get("_active_party")
	party.replacement_requested.emit(3, &"wrong_target", &"scrapbroker")
	_expect(repo.writes.is_empty(), "stale replacement target rejects")
	party.request_replacement(3, &"scout", &"scrapbroker")
	var state: RefCounted = world.get_durable_run_state()
	_expect(state.gold == 250 and state.formation.size() == 6 and state.formation[3] == &"scrapbroker", "replacement preserves six slots and cost")
	_expect(not state.get_character_hp_snapshot().has(&"scout") and state.get_character_hp_snapshot().has(&"scrapbroker"), "replacement reconciles HP")
	world.free()
	await process_frame

func _arrival_case() -> void:
	var repo := Repository.new()
	var session := _session(500)
	var plan: WorldPlan = session.plan
	var town: Vector2i = session.run_state.player_coord
	for neighbor: Vector2i in HexWorldGeometry.get_neighbors(town):
		if plan.get_cells().has(neighbor) and neighbor != plan.get_boss_coord():
			session.run_state.player_coord = neighbor
			break
	var world := await _open(session, repo)
	_expect(world.request_move(town).is_accepted(), "accepted move enters town")
	_expect(world.call("has_active_town_recruitment") and not world.has_active_encounter(), "committed arrival opens town instead of safe encounter")
	var count: int = repo.writes.size()
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	world.call("close_town_recruitment")
	_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.size() == count, "arrival close adds no encounter resolution")
	world.free()
	await process_frame
