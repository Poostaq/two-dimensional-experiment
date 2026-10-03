extends SceneTree
var failures: int = 0
var checks: int = 0

class Repository:
	extends RefCounted
	var writes: Array[PackedByteArray] = []
	var fail_next: bool = false
	var failures_remaining: int = 0
	var successful_writes: int = 0
	var checkpoint: PackedByteArray = PackedByteArray()
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes.append(bytes.duplicate())
		if fail_next or failures_remaining > 0:
			fail_next = false
			failures_remaining = maxi(0, failures_remaining - 1)
			return {"ok": false, "value": null, "error": null}
		checkpoint = bytes.duplicate()
		successful_writes += 1
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
	await _v2_recruitment_case()
	await _empty_catalog_recruitment_case()
	await _contract_case()
	await _replacement_case()
	await _arrival_case()
	await _dismissal_case()
	await _dismissal_callback_case()
	await _dismissal_guard_case()
	await _dismissal_failure_case(false)
	await _dismissal_failure_case(true)
	await _eligibility_matrix_case()
	await _stale_eligibility_case(false)
	await _stale_eligibility_case(true)
	for replace: bool in [false, true]:
		for slot: int in 6:
			for gold: int in [0, 499, 500, 750]:
				await _placement_matrix_case(replace, slot, gold)
		await _selection_lifetime_case(replace)
		for change: String in ["funds", "town", "blocked"]:
			await _commit_revalidation_case(replace, change)
		await _repeated_failure_case(replace, false)
		await _repeated_failure_case(replace, true)
	for slot: int in 6:
		await _last_empty_slot_case(slot)
	print("AC8.7 town integration checks: %d; failures: %d" % [checks, failures])
	if failures == 0:
		print("PASS test_ac8_town_recruitment")
	quit(0 if failures == 0 else 1)

func _session(gold: int) -> Dictionary:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(
		func(_p: RefCounted) -> void: pass,
		HexWorldGeneratorV1.new()
	).start("golden-alpha")
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
		var loaded: Dictionary = load("res://Scripts/Save/world_run_save_codec_v8.gd").decode_any(repo.writes.back())
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

func _v2_recruitment_case() -> void:
	var cases: Array[Dictionary] = [
		{
			"seed": "town-v2-a",
			"main_clan_id": &"goblin",
			"commander_id": &"brakka_rustbanner",
			"allied_clan_ids": [&"orc", &"werewolf"],
		},
		{
			"seed": "town-v2-b",
			"main_clan_id": &"lizardman",
			"commander_id": &"sszek_still_mire",
			"allied_clan_ids": [&"goblin", &"harpy"],
		},
	]
	var covered: Dictionary = {}
	var transaction_session: Dictionary = {}
	for case: Dictionary in cases:
		var allied_clan_ids: Array[StringName] = []
		for allied_clan_id: Variant in case.allied_clan_ids:
			allied_clan_ids.append(StringName(allied_clan_id))
		var coalition_result: Dictionary = RunClanCoalition.create(
			case.main_clan_id, allied_clan_ids
		)
		_expect(coalition_result.get("ok", false), "v2 recruitment coalition is valid")
		if not coalition_result.get("ok", false):
			continue
		var session: Dictionary = WorldRunStartService.new(
			func(_p: RefCounted) -> void: pass
		).start(
			case.seed, {}, WorldRunStartService.RETURN_RESULT, case.commander_id,
			case.main_clan_id, null, coalition_result.value
		)
		_expect(session.get("ok", false), "identity-consistent v2 recruitment session starts")
		if not session.get("ok", false):
			continue
		var plan: WorldPlan = session.plan
		if case.main_clan_id == &"goblin":
			transaction_session = session
		var bytes_before: PackedByteArray = WorldPlanCodec.serialize(plan)
		var habitats_before: Array = plan.get_habitats()
		var towns_before: Array = plan.get_towns()
		var cells_before: Dictionary = plan.get_cells()
		_expect_session_plan_identities(session)
		for town_value: Variant in plan.get_towns():
			var town: Dictionary = town_value
			var owner: Dictionary = TownOwnershipRules.resolve(plan, town.coord)
			var clan_id: StringName = owner.get("clan_id", &"")
			if covered.has(clan_id):
				continue
			session.run_state.player_coord = town.coord
			var repo := Repository.new()
			var world := await _open(session, repo)
			var context: Dictionary = world.get_town_recruitment_context()
			var catalog: Array[StringName] = RunCharacterCatalog.get_recruitable_class_ids(clan_id)
			var options_valid: bool = not context.get("class_ids", []).is_empty()
			for class_id: StringName in context.get("class_ids", []):
				options_valid = options_valid and catalog.has(class_id)
			_expect(context.get("ok", false) and context.get("clan_id", &"") == clan_id,
				"v2 allied town resolves recruitment owner")
			_expect(not catalog.is_empty() and options_valid,
				"v2 offers are nonempty and belong to owning clan")
			_expect(world.open_town_recruitment(), "v2 allied town opens recruitment")
			world.close_town_recruitment()
			world.free()
			await process_frame
			covered[clan_id] = true
		_expect(WorldPlanCodec.serialize(plan) == bytes_before and
			plan.get_habitats() == habitats_before and plan.get_towns() == towns_before and
			plan.get_cells() == cells_before,
			"v2 recruitment query and open do not mutate plan")
	for clan_id: StringName in [&"goblin", &"orc", &"werewolf", &"lizardman", &"harpy"]:
		_expect(covered.has(clan_id), "v2 recruitment covers %s catalog" % String(clan_id))
	_expect(not transaction_session.is_empty(),
		"v2 non-Goblin transaction reuses a real identity-consistent session")
	if not transaction_session.is_empty():
		await _v2_non_goblin_transaction_case(transaction_session)

func _v2_non_goblin_transaction_case(session: Dictionary) -> void:
	var plan: WorldPlan = session.plan
	var town_coord: Vector2i = Vector2i(999, 999)
	for town_value: Variant in plan.get_towns():
		var town: Dictionary = town_value
		var ownership: Dictionary = TownOwnershipRules.resolve(plan, town.coord)
		if ownership.get("clan_id", &"") == &"orc":
			town_coord = town.coord
			break
	_expect(plan.get_cells().has(town_coord), "v2 Orc transaction has a generated town")
	if not plan.get_cells().has(town_coord):
		return
	session.run_state.player_coord = town_coord
	session.run_state.gold = 500
	var before: Dictionary = session.run_state.to_dictionary()
	_expect(before.gold == 500 and String(before.formation[5]).is_empty(),
		"v2 Orc transaction fixture has exact wallet and empty placement slot")
	var plan_bytes_before: PackedByteArray = WorldPlanCodec.serialize(plan)
	var repo := Repository.new()
	var world := await _open(session, repo)
	var context: Dictionary = world.get_town_recruitment_context()
	_expect(context.get("ok", false) and context.get("clan_id", &"") == &"orc",
		"v2 Orc town exposes recruitment context")
	var class_ids: Array = context.get("class_ids", [])
	_expect(not class_ids.is_empty(), "v2 Orc town offers a recruit")
	if class_ids.is_empty():
		world.free()
		await process_frame
		return
	var recruit_id: StringName = StringName(class_ids[0])
	var recruit: RunCharacter = RunCharacterCatalog.create_by_class_id(recruit_id)
	_expect(is_instance_valid(recruit) and recruit.race_id == &"orc",
		"v2 offered recruit belongs to Orc town owner")
	_expect(world.open_town_recruitment(), "v2 Orc transaction opens town service")
	_expect(world.request_town_recruitment(recruit_id).get("ok", false),
		"v2 Orc offer opens real placement flow")
	var party: PartyManagement = world.get("_active_party")
	var live_roster: RunRoster = world.get("_roster")
	repo.fail_next = true
	party.request_placement(5, recruit_id)
	_expect(repo.writes.size() == 1 and repo.successful_writes == 0,
		"v2 failed commit captures one V8 candidate without publishing")
	if repo.writes.is_empty():
		world.free()
		await process_frame
		return
	var candidate_bytes: PackedByteArray = repo.writes[0].duplicate()
	_expect(world.is_autosave_blocked() and
		world.get_town_recruitment_context().get("error", &"") == &"service_blocked",
		"v2 failed commit blocks world and town input")
	_expect(world.get_durable_run_state().to_dictionary() == before and
		world.get("_roster") == live_roster and not live_roster.has_character(recruit_id),
		"v2 failed commit does not prematurely publish runtime or durable state")
	var expected: Dictionary = before.duplicate(true)
	expected.gold = 0
	expected.formation[5] = String(recruit_id)
	expected.character_hp[String(recruit_id)] = recruit.max_hp
	var candidate: Dictionary = load(
		"res://Scripts/Save/world_run_save_codec_v8.gd").decode_any(candidate_bytes)
	_expect(candidate.get("ok", false) and
		candidate.value.plan.get_version() == 2 and
		candidate.value.run_state.to_dictionary() == expected,
		"v2 failed candidate bytes contain complete pending transaction")
	if candidate.get("ok", false):
		_expect_session_plan_identities(candidate.value)
	_expect(world.retry_autosave().get("ok", false), "v2 failed commit retries successfully")
	_expect(repo.writes.size() == 2 and repo.writes[0] == repo.writes[1] and
		repo.checkpoint == candidate_bytes and repo.successful_writes == 1,
		"v2 retry writes byte-identical V8 candidate exactly once")
	_expect(world.get_durable_run_state().to_dictionary() == expected and
		(world.get("_roster") as RunRoster).has_character(recruit_id),
		"v2 retry publishes recruited member and durable formation")
	var decoded: Dictionary = load(
		"res://Scripts/Save/world_run_save_codec_v8.gd").decode_any(repo.checkpoint)
	_expect(decoded.get("ok", false) and decoded.value.plan.get_version() == 2 and
		decoded.value.run_state.to_dictionary() == expected,
		"v2 successful checkpoint decodes with recruited formation")
	if decoded.get("ok", false):
		_expect_session_plan_identities(decoded.value)
		var decoded_owner: Dictionary = TownOwnershipRules.resolve(
			decoded.value.plan, decoded.value.run_state.player_coord)
		_expect(decoded_owner.get("ok", false) and decoded_owner.get("clan_id", &"") == &"orc",
			"v2 decoded checkpoint preserves Orc town ownership")
	world.free()
	await process_frame
	if not decoded.get("ok", false):
		return
	var reload_repo := Repository.new()
	world = await _open(decoded.value, reload_repo)
	var reload_context: Dictionary = world.get_town_recruitment_context()
	var reloaded_recruit: RunCharacter = (world.get("_roster") as RunRoster).get_character_at(5)
	_expect(reload_context.get("ok", false) and
		reload_context.get("clan_id", &"") == &"orc" and
		not reload_context.get("class_ids", []).has(recruit_id),
		"v2 reload retains Orc owner and excludes recruited offer")
	_expect(is_instance_valid(reloaded_recruit) and reloaded_recruit.race_id == &"orc" and
		world.get_durable_run_state().formation[5] == recruit_id,
		"v2 reload reconstructs Orc recruit in durable formation")
	_expect(WorldPlanCodec.serialize(plan) == plan_bytes_before,
		"v2 non-Goblin transaction never mutates generated plan")
	world.free()
	await process_frame

func _empty_catalog_recruitment_case() -> void:
	_expect(RunCharacterCatalog.get_recruitable_class_ids(&"empty_clan").is_empty(),
		"empty-clan fixture has no recruitable catalog")
	var allies: Array[StringName] = [&"orc", &"werewolf"]
	var coalition_result: Dictionary = RunClanCoalition.create(&"goblin", allies)
	_expect(coalition_result.get("ok", false), "empty-catalog base coalition is valid")
	if not coalition_result.get("ok", false):
		return
	var session: Dictionary = WorldRunStartService.new(
		func(_p: RefCounted) -> void: pass
	).start(
		"town-v2-empty-catalog", {}, WorldRunStartService.RETURN_RESULT,
		&"brakka_rustbanner", &"goblin", null, coalition_result.value
	)
	_expect(session.get("ok", false), "empty-catalog base session starts")
	if not session.get("ok", false):
		return
	_expect_session_plan_identities(session)
	var base_plan: WorldPlan = session.plan
	var habitats: Array = base_plan.get_habitats()
	for habitat_value: Variant in habitats:
		var habitat: Dictionary = habitat_value
		if String(habitat.get("habitat_id", "")) == "ally_0":
			habitat.clan_id = &"empty_clan"
	var empty_plan: WorldPlan = WorldPlan.new(
		2, base_plan.get_seed_hex(), base_plan.get_start_coord(), base_plan.get_boss_coord(),
		base_plan.get_cells(), base_plan.get_roads(), base_plan.get_forest_clusters(),
		habitats, base_plan.get_towns()
	)
	_expect(WorldPlanCodec.validate(empty_plan) == null,
		"empty-clan plan remains structurally valid v2")
	var empty_town_coord: Vector2i = Vector2i(999, 999)
	for town_value: Variant in empty_plan.get_towns():
		var town: Dictionary = town_value
		if String(town.get("habitat_id", "")) == "ally_0":
			empty_town_coord = town.coord
			break
	_expect(empty_plan.get_cells().has(empty_town_coord),
		"empty-clan allied town is present")
	var bytes_before: PackedByteArray = WorldPlanCodec.serialize(empty_plan)
	var habitats_before: Array = empty_plan.get_habitats()
	var towns_before: Array = empty_plan.get_towns()
	var cells_before: Dictionary = empty_plan.get_cells()
	var repo := Repository.new()
	var world := await _open(session, repo)
	# Exercise the existing runtime configuration seam so the durable session remains real
	# while the ownership/catalog boundary receives the synthetic, codec-valid plan.
	_expect(world.configure_runtime(empty_plan), "empty-clan plan configures real runtime")
	world.get_durable_run_state().player_coord = empty_town_coord
	var context: Dictionary = world.get_town_recruitment_context()
	_expect(not context.get("ok", false) and
		context.get("error", &"") == &"unsupported_town_owner",
		"empty recruitable catalog rejects town context")
	_expect(context.get("class_ids", []).is_empty() and context.get("clan_id", &"") == &"",
		"empty recruitable catalog exposes no options or owner")
	_expect(not world.open_town_recruitment(),
		"empty recruitable catalog cannot open recruitment")
	_expect(WorldPlanCodec.serialize(empty_plan) == bytes_before and
		empty_plan.get_habitats() == habitats_before and
		empty_plan.get_towns() == towns_before and empty_plan.get_cells() == cells_before,
		"empty-catalog context query does not mutate plan")
	world.free()
	await process_frame

func _expect_session_plan_identities(session: Dictionary) -> void:
	var habitats: Array = session.plan.get_habitats()
	var allies: Array[StringName] = session.coalition.allied_clan_ids
	_expect(habitats.size() == 4, "v2 session plan has four identity habitats")
	if habitats.size() != 4:
		return
	_expect(StringName(habitats[0].clan_id) == session.selection.main_clan_id,
		"v2 plan main clan matches durable selection")
	_expect(allies.size() == 2 and StringName(habitats[1].clan_id) == allies[0] and
		StringName(habitats[2].clan_id) == allies[1],
		"v2 plan allies match durable ordered coalition")
	_expect(StringName(habitats[3].clan_id) == session.enemy_boss_selection.enemy_clan_id,
		"v2 plan enemy matches durable boss selection")

func _expect(condition: bool, message: String) -> void:
	checks += 1
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
		var expected_offers: Array[StringName] = [&"scrapbroker", &"shivrunner", &"mobcaller"]
		_expect(context.class_ids == expected_offers, "every town excludes present classes from fixed Brakka race roster")
		var save_codec: Script = load("res://Scripts/Save/world_run_save_codec_v8.gd")
		var town_save: PackedByteArray = save_codec.encode(
			plan, session.resolved_seed, world.get_durable_run_state(), session.selection,
			session.coalition, session.enemy_boss_selection
		)
		var continued: Dictionary = save_codec.decode_any(town_save)
		_expect(continued.ok and world.apply_session(continued.value, repo), "every town Continues")
		_expect(world.get_town_recruitment_context().class_ids == expected_offers, "every town retains filtered offers after Continue")
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
	for version: int in [0, 3, 99]:
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
	party.request_replacement(0, &"player_0", &"scrapbroker")
	var state: RefCounted = world.get_durable_run_state()
	_expect(state.gold == 250 and state.formation.size() == 6 and state.formation[0] == &"scrapbroker", "replacement preserves six slots and cost")
	_expect(not state.get_character_hp_snapshot().has(&"player_0") and state.get_character_hp_snapshot().has(&"scrapbroker"), "replacement reconciles HP")
	var offers: Array = world.get_town_recruitment_context().class_ids
	_expect(offers.has(&"scrapshield_bruiser") and not offers.has(&"scrapbroker"), "replacement releases old canonical class and excludes recruit")
	var panel: Control = world.get("_town_panel")
	_expect(panel.get_node("%Offers").has_node("scrapshield_bruiser") and not panel.get_node("%Offers").has_node("scrapbroker"), "replacement actual panel refresh")
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

# D1 is the user-requested dismissal extension; offer assertions cover base AC8.6.
func _dismissal_case() -> void:
	var repo := Repository.new()
	var world := await _open(_session(750), repo)
	if not world.has_method("request_party_dismissal"):
		_expect(false, "missing D1 production dismissal API")
		world.free()
		return
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	_expect(not world.call("request_party_dismissal", 0, &"wirefang_skirmisher").ok, "dismissal needs normal party")
	world.open_party_management()
	for invalid: Array in [[-1, &"wirefang_skirmisher"], [5, &"wirefang_skirmisher"], [0, &"wrong"]]:
		_expect(not world.call("request_party_dismissal", invalid[0], invalid[1]).ok, "invalid dismissal rejects")
	_expect(repo.writes.is_empty(), "invalid dismissal writes nothing")
	_expect(world.call("request_party_dismissal", 0, &"wirefang_skirmisher").ok, "dismissal commits")
	var expected: Dictionary = before.duplicate(true)
	expected.formation[0] = ""
	expected.character_hp.erase("wirefang_skirmisher")
	_expect(world.get_durable_run_state().to_dictionary() == expected, "D1 changes only target formation and HP; no refund or world turn")
	_expect(repo.writes.size() == 1, "dismissal one write")
	_expect(not world.call("request_party_dismissal", 0, &"wirefang_skirmisher").ok, "repeat rejects")
	_expect(world.get_valid_destinations().is_empty(), "dismissal retains party movement lock")
	world.call("_on_party_close_requested")
	_expect(world.open_town_recruitment(), "reopen after dismissal")
	_expect(world.get_town_recruitment_context().class_ids.has(&"wirefang_skirmisher"), "dismissal refreshes class")
	world.close_town_recruitment()
	var decoded: Dictionary = load("res://Scripts/Save/world_run_save_codec_v8.gd").decode_any(repo.writes.back())
	_expect(decoded.ok, "dismissal save decodes")
	_expect(world.apply_session(decoded.value, repo), "dismissal reload applies")
	_expect(world.get_town_recruitment_context().class_ids.has(&"wirefang_skirmisher"), "dismissal eligibility survives reload")
	world.open_party_management()
	var second_id: StringName = world.get_durable_run_state().formation[1]
	_expect(world.call("request_party_dismissal", 1, second_id).ok, "second member can leave")
	var last_before: Dictionary = world.get_durable_run_state().to_dictionary()
	var writes: int = repo.writes.size()
	var rejected: Dictionary = world.call("request_party_dismissal", 2, &"snarewright")
	_expect(not rejected.ok and rejected.error == &"last_member", "D1 domain rejects final member")
	_expect(world.get_durable_run_state().to_dictionary() == last_before and repo.writes.size() == writes, "last-member rejection no-op")
	world.free()
	await process_frame

func _dismissal_failure_case(discard: bool) -> void:
	var repo := Repository.new()
	var world := await _open(_session(750), repo)
	if not world.has_method("request_party_dismissal"):
		world.free()
		return
	world.open_party_management()
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var original: RunRoster = world.get("_roster")
	repo.fail_next = true
	_expect(not world.call("request_party_dismissal", 0, &"wirefang_skirmisher").ok, "dismissal save failure surfaced")
	_expect(world.is_autosave_blocked(), "dismissal failed save blocks input")
	_expect(original.has_character(&"wirefang_skirmisher") and world.get_durable_run_state().to_dictionary() == before, "failure preserves live roster and state")
	_expect(not world.call("request_party_dismissal", 1, &"brakka_rustbanner").ok, "blocked save rejects another dismissal")
	_expect(not world.request_town_recruitment(&"scrapbroker").ok, "blocked save rejects purchase")
	world.call("_on_party_close_requested")
	_expect(world.has_active_party_management(), "cannot close during pending save")
	if discard:
		_expect(world.discard_pending_autosave(), "dismissal discard succeeds")
		_expect(world.get_durable_run_state().to_dictionary() == before and (world.get("_roster") as RunRoster).has_character(&"wirefang_skirmisher"), "discard preserves roster and eligibility")
		_expect(not world.has_active_party_management(), "discard invalidates abandoned dismissal panel")
		_expect(not world.get_town_recruitment_context().class_ids.has(&"wirefang_skirmisher"), "discard keeps class excluded")
	else:
		_expect(world.retry_autosave().ok, "dismissal retry succeeds")
		_expect(repo.writes.size() == 2 and repo.writes[0] == repo.writes[1], "dismissal retry exact bytes")
		_expect(not (world.get("_roster") as RunRoster).has_character(&"wirefang_skirmisher"), "retry publishes removal")
		_expect(world.get_durable_run_state().gold == 750 and world.get_valid_destinations().is_empty(), "retry no refund and modal lock")
		_expect(not world.retry_autosave().ok and repo.writes.size() == 2, "retry cannot repeat")
	world.free()
	await process_frame

func _session_with_members(ids: Array[StringName], gold: int = 1500) -> Dictionary:
	var session: Dictionary = _session(gold)
	var data: Dictionary = session.run_state.to_dictionary()
	data.formation = []
	data.character_hp = {}
	var starters: Array[RunCharacter] = RunCharacterCatalog.create_starters()
	for id: StringName in ids:
		var character: RunCharacter
		for starter: RunCharacter in starters:
			if starter.character_id == id:
				character = starter
		if not is_instance_valid(character):
			character = RunCharacterCatalog.create_by_class_id(id)
		data.formation.append(String(id))
		data.character_hp[String(id)] = character.max_hp
	while data.formation.size() < 6:
		data.formation.append("")
	var decoded: Dictionary = load("res://Scripts/Run/world_run_state.gd").from_dictionary(data, session.plan)
	_expect(decoded.ok, "member fixture valid")
	session.run_state = decoded.value
	return session

func _eligibility_matrix_case() -> void:
	var repo := Repository.new()
	var world := await _open(_session_with_members([&"player_0", &"scrapshield_bruiser", &"player_1"]), repo)
	if not world.has_method("request_party_dismissal"):
		world.free()
		return
	world.open_party_management()
	_expect(world.call("request_party_dismissal", 0, &"player_0").ok, "remove one representative")
	world.call("_on_party_close_requested")
	_expect(not world.get_town_recruitment_context().class_ids.has(&"scrapshield_bruiser"), "remaining representative excludes class")
	var decoded: Dictionary = load("res://Scripts/Save/world_run_save_codec_v8.gd").decode_any(repo.writes.back())
	_expect(decoded.ok and world.apply_session(decoded.value, repo), "duplicate-class identity restores")
	_expect(not world.get_town_recruitment_context().class_ids.has(&"scrapshield_bruiser"), "restored remaining representative excludes")
	world.open_party_management()
	_expect(world.call("request_party_dismissal", 1, &"scrapshield_bruiser").ok, "remove final representative")
	world.call("_on_party_close_requested")
	_expect(world.get_town_recruitment_context().class_ids.has(&"scrapshield_bruiser"), "final representative enables")
	world.free()
	await process_frame
	repo = Repository.new()
	world = await _open(_session_with_members(RunCharacterCatalog.get_goblin_class_ids()), repo)
	var context: Dictionary = world.get_town_recruitment_context()
	_expect(context.ok and context.class_ids.is_empty(), "real six-class roster has zero eligibility")
	for attempt: int in 2:
		_expect(world.open_town_recruitment(), "empty town browsable")
		var panel: Control = world.get("_town_panel")
		_expect(panel.get_node("%Offers").get_child_count() == 0 and panel.get_node("%EmptyLabel").visible, "actual empty panel has no offer buttons")
		for id: StringName in RunCharacterCatalog.get_goblin_class_ids():
			_expect(not world.request_town_recruitment(id).ok, "direct present class rejects")
		world.close_town_recruitment()
	_expect(repo.writes.is_empty(), "empty browsing and rejected purchases never write")
	world.open_party_management()
	_expect(world.call("request_party_dismissal", 3, &"scrapbroker").ok, "dismiss from exhausted roster")
	world.call("_on_party_close_requested")
	_expect(world.get_town_recruitment_context().class_ids == [&"scrapbroker"], "one exact offer returns")
	world.free()
	await process_frame

func _stale_eligibility_case(replace: bool) -> void:
	var repo := Repository.new()
	var world := await _open(_session(1500), repo)
	world.open_town_recruitment()
	_expect(not world.request_town_recruitment(&"scrapshield_bruiser").ok, "present class cannot replace itself")
	_expect(world.request_town_recruitment(&"scrapbroker").ok, "absent class selection begins")
	var party: PartyManagement = world.get("_active_party")
	# Deliberate adversarial fixture: simulate a roster change after selection.
	# No world save with zero HP or fabricated concurrent gameplay is claimed.
	var changed: RunRoster = world.get("_roster")
	_expect(changed.try_add_at(RunCharacterCatalog.create_by_class_id(&"scrapbroker"), 3) == RunRoster.AddResult.ADDED, "fixture acquires selected class")
	if replace:
		changed.try_add_at(RunCharacterCatalog.create_by_class_id(&"shivrunner"), 4)
		changed.try_add_at(RunCharacterCatalog.create_by_class_id(&"mobcaller"), 5)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var slots: Array[RunCharacter] = changed.get_slot_snapshot()
	if replace:
		party.replacement_requested.emit(0, &"wirefang_skirmisher", &"scrapbroker")
	else:
		party.placement_requested.emit(5, &"scrapbroker")
	_expect(repo.writes.is_empty() and world.get_durable_run_state().to_dictionary() == before, "stale eligibility confirmation cannot charge or save")
	_expect((world.get("_roster") as RunRoster).get_slot_snapshot() == slots, "stale eligibility does not mutate current roster")
	_expect(not world.get_town_recruitment_context().class_ids.has(&"scrapbroker"), "stale selection refreshes exclusions")
	world.free()
	await process_frame

func _dismissal_callback_case() -> void:
	var repo := Repository.new()
	var session: Dictionary = _session(750)
	var world := await _open(session, repo)
	world.open_party_management()
	var old: PartyManagement = world.get("_active_party")
	world.call("_on_party_close_requested")
	world.open_party_management()
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	old.dismissal_requested.emit(0, &"wirefang_skirmisher")
	_expect(repo.writes.is_empty() and world.get_durable_run_state().to_dictionary() == before, "old panel dismissal callback rejects")
	var current: PartyManagement = world.get("_active_party")
	_expect(world.apply_session(session, repo), "replace session with normal party open")
	current.dismissal_requested.emit(0, &"wirefang_skirmisher")
	_expect(repo.writes.is_empty() and world.get_durable_run_state().to_dictionary() == before, "old session dismissal callback rejects")
	world.open_party_management()
	current = world.get("_active_party")
	current.request_dismissal(0, &"wirefang_skirmisher")
	var dialog: ConfirmationDialog = current.get_node("%DismissConfirmation")
	_expect(dialog.visible, "production dismissal opens confirmation")
	dialog.confirmed.emit()
	dialog.confirmed.emit()
	_expect(repo.writes.size() == 1 and world.get_durable_run_state().formation[0] == &"", "wired confirmation publishes once")
	world.free()
	await process_frame

func _dismissal_guard_case() -> void:
	var repo := Repository.new()
	var world := await _open(_session(750), repo)
	world.open_party_management()
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	world.set("_terminal_phase", WorldRuntimeController.TerminalPhase.LOSS_COMMITTING)
	_expect(not world.request_party_dismissal(0, &"wirefang_skirmisher").ok, "terminal dismissal denied")
	world.set("_terminal_phase", WorldRuntimeController.TerminalPhase.PLAYING)
	world.get_durable_run_state().pending_reward_battle_id = "unacknowledged"
	_expect(not world.request_party_dismissal(0, &"wirefang_skirmisher").ok, "reward dismissal denied")
	world.get_durable_run_state().pending_reward_battle_id = ""
	var battle: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	world.set("_active_battle", battle)
	_expect(not world.request_party_dismissal(0, &"wirefang_skirmisher").ok, "battle dismissal denied")
	world.set("_active_battle", null)
	battle.free()
	var encounter: EncounterOverlay = load("res://Scenes/encounter_overlay.tscn").instantiate()
	world.set("_active_encounter", encounter)
	_expect(not world.request_party_dismissal(0, &"wirefang_skirmisher").ok, "encounter dismissal denied")
	world.set("_active_encounter", null)
	encounter.free()
	var party: PartyManagement = world.get("_active_party")
	party.configure_placement((world.get("_roster") as RunRoster).get_slot_snapshot(), RunCharacterCatalog.create_by_class_id(&"scrapbroker"))
	_expect(not world.request_party_dismissal(0, &"wirefang_skirmisher").ok, "placement dismissal denied")
	party.configure_replacement((world.get("_roster") as RunRoster).get_slot_snapshot(), RunCharacterCatalog.create_by_class_id(&"scrapbroker"))
	_expect(not world.request_party_dismissal(0, &"wirefang_skirmisher").ok, "replacement dismissal denied")
	_expect(repo.writes.is_empty() and world.get_durable_run_state().to_dictionary() == before, "dismissal guard matrix no writes or state changes")
	world.free()
	await process_frame

# AC8.7: each destination, both transaction modes, and exact durable state.
func _matrix_session(replace: bool, slot: int, gold: int) -> Dictionary:
	var session: Dictionary = _session(gold)
	var data: Dictionary = session.run_state.to_dictionary()
	var members: Array[RunCharacter] = RunCharacterCatalog.create_starters()
	members.append(RunCharacterCatalog.create_for_reward(RunCharacterCatalog.COMBAT_SCOUT_REWARD_ID))
	members.append(RunCharacterCatalog.create_for_reward(RunCharacterCatalog.BOSS_CHAMPION_REWARD_ID))
	members.append(RunCharacterCatalog.create_by_class_id(&"shivrunner"))
	data.formation = ["", "", "", "", "", ""]
	data.character_hp = {}
	for index: int in 6:
		if not replace and index % 2 == slot % 2:
			continue
		var member: RunCharacter = members[index]
		data.formation[index] = String(member.character_id)
		data.character_hp[String(member.character_id)] = maxi(1, member.max_hp - index - 2)
	var decoded: Dictionary = load("res://Scripts/Run/world_run_state.gd").from_dictionary(data, session.plan)
	_expect(decoded.ok, "AC8.7 sparse/full wounded fixture valid")
	session.run_state = decoded.value
	return session

func _confirm_matrix(party: PartyManagement, replace: bool, slot: int, target: StringName) -> void:
	if replace:
		party.replacement_requested.emit(slot, target, &"scrapbroker")
	else:
		party.placement_requested.emit(slot, &"scrapbroker")

func _purchase_expected(before: Dictionary, slot: int) -> Dictionary:
	var expected: Dictionary = before.duplicate(true)
	expected.gold -= 500
	if not String(expected.formation[slot]).is_empty():
		expected.character_hp.erase(expected.formation[slot])
	expected.formation[slot] = "scrapbroker"
	expected.character_hp["scrapbroker"] = RunCharacterCatalog.create_by_class_id(&"scrapbroker").max_hp
	return expected

func _placement_matrix_case(replace: bool, slot: int, gold: int) -> void:
	var repo := Repository.new()
	var world := await _open(_matrix_session(replace, slot, gold), repo)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var identities: Array[RunCharacter] = (world.get("_roster") as RunRoster).get_slot_snapshot()
	_expect(world.open_town_recruitment(), "AC8.7 matrix town opens")
	var selected: Dictionary = world.request_town_recruitment(&"scrapbroker")
	if gold < 500:
		_expect(not selected.ok and selected.error == &"insufficient_gold", "AC8.7 0/499 rejected in both modes")
		_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.is_empty(), "AC8.7 unaffordable state exact")
	else:
		_expect(selected.ok, "AC8.7 affordable selection")
		var party: PartyManagement = world.get("_active_party")
		_expect(not world.request_town_recruitment(&"shivrunner").ok, "AC8.7 duplicate selection rejected")
		for bad_slot: int in [-1, 6]:
			_confirm_matrix(party, replace, bad_slot, &"wrong")
		if replace:
			party.replacement_requested.emit(slot, &"wrong", &"scrapbroker")
			party.replacement_requested.emit(slot, StringName(before.formation[slot]), &"wrong")
			party.placement_requested.emit(slot, &"scrapbroker")
		else:
			party.placement_requested.emit((slot + 1) % 6, &"scrapbroker")
			party.placement_requested.emit(slot, &"wrong")
			party.replacement_requested.emit((slot + 1) % 6, StringName(before.formation[(slot + 1) % 6]), &"scrapbroker")
		_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.is_empty(), "AC8.7 invalid slots IDs targets and cross-mode signals reject")
		_confirm_matrix(party, replace, slot, StringName(before.formation[slot]))
		_confirm_matrix(party, replace, slot, StringName(before.formation[slot]))
		var expected: Dictionary = _purchase_expected(before, slot)
		_expect(world.get_durable_run_state().to_dictionary() == expected, "AC8.7 all slots preserve every unrelated field and wounded survivor HP")
		_expect(repo.writes.size() == 1 and repo.successful_writes == 1, "AC8.7 duplicate confirmation publishes once")
		_expect_live_formation(world, expected)
		var current: Array[RunCharacter] = (world.get("_roster") as RunRoster).get_slot_snapshot()
		for index: int in 6:
			if index != slot:
				_expect(current[index] == identities[index], "AC8.7 survivor live identity preserved")
		var decoded: Dictionary = load("res://Scripts/Save/world_run_save_codec_v8.gd").decode_any(repo.checkpoint)
		_expect(decoded.ok and decoded.value.run_state.to_dictionary() == expected, "AC8.7 durable checkpoint exact")
	world.free()
	await process_frame

func _selection_lifetime_case(replace: bool) -> void:
	var repo := Repository.new()
	var session: Dictionary = _matrix_session(replace, 5, 750)
	var world := await _open(session, repo)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	world.open_town_recruitment()
	world.request_town_recruitment(&"scrapbroker")
	var old: PartyManagement = world.get("_active_party")
	old.request_placement_cancel()
	_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.is_empty(), "AC8.7 cancellation preserves complete state without a write")
	_expect(world.has_active_town_recruitment() and not world.has_active_party_management(), "AC8.7 cancel returns to town")
	world.request_town_recruitment(&"scrapbroker")
	_confirm_matrix(old, replace, 5, StringName(before.formation[5]))
	old.close_requested.emit()
	_expect(world.has_active_party_management() and repo.writes.is_empty(), "AC8.7 old cancel and confirm cannot affect reopened selection")
	var current: PartyManagement = world.get("_active_party")
	current.close_requested.emit()
	_expect(world.get_durable_run_state().to_dictionary() == before and repo.writes.is_empty(), "AC8.7 close cancellation preserves complete state")
	var old_panel: Control = world.get("_town_panel")
	world.close_town_recruitment()
	world.open_town_recruitment()
	old_panel.emit_signal("recruit_requested", &"scrapbroker")
	old_panel.emit_signal("close_requested")
	_expect(world.has_active_town_recruitment() and not world.has_active_party_management() and repo.writes.is_empty(), "AC8.7 old town panel cannot select or close reopened town")
	world.request_town_recruitment(&"scrapbroker")
	current = world.get("_active_party")
	_expect(world.apply_session(session, repo), "AC8.7 new session replaces open selection")
	_confirm_matrix(current, replace, 5, StringName(before.formation[5]))
	_expect(repo.writes.is_empty() and world.get_durable_run_state().to_dictionary() == before, "AC8.7 cancelled and old-session callbacks no-op")
	world.free()
	await process_frame

func _commit_revalidation_case(replace: bool, change: String) -> void:
	var repo := Repository.new()
	var session: Dictionary = _matrix_session(replace, 5, 750)
	var world := await _open(session, repo)
	world.open_town_recruitment()
	world.request_town_recruitment(&"scrapbroker")
	var party: PartyManagement = world.get("_active_party")
	# Adversarial fixture changes occur after selection; snapshot is taken afterwards.
	if change == "funds":
		world.get_durable_run_state().gold = 499
	elif change == "town":
		for coord: Vector2i in session.plan.get_cells():
			if session.plan.get_cells()[coord].town_index >= 0 and coord != world.get_durable_run_state().player_coord and coord != session.plan.get_boss_coord():
				world.get_durable_run_state().player_coord = coord
				break
	else:
		world.set("_terminal_phase", WorldRuntimeController.TerminalPhase.LOSS_COMMITTING)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var roster: RunRoster = world.get("_roster")
	var identities: Array[RunCharacter] = roster.get_slot_snapshot()
	_confirm_matrix(party, replace, 5, StringName(before.formation[5]))
	_expect(repo.writes.is_empty() and world.get_durable_run_state().to_dictionary() == before, "AC8.7 commit revalidates " + change)
	_expect(world.get("_roster") == roster and roster.get_slot_snapshot() == identities, "AC8.7 rejected commit preserves live roster")
	world.free()
	await process_frame

func _repeated_failure_case(replace: bool, discard: bool) -> void:
	var repo := Repository.new()
	var session: Dictionary = _matrix_session(replace, 5, 750)
	var world := await _open(session, repo)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var checkpoint: PackedByteArray = load("res://Scripts/Save/world_run_save_codec_v8.gd").encode(
		session.plan, session.resolved_seed, world.get_durable_run_state(), session.selection,
		session.coalition, session.enemy_boss_selection
	)
	repo.checkpoint = checkpoint.duplicate()
	var roster: RunRoster = world.get("_roster")
	var identities: Array[RunCharacter] = roster.get_slot_snapshot()
	var gold_label: Label = world.get_node("%WorldMapHud").get_node("%GoldLabel")
	var gold_text: String = gold_label.text
	world.open_town_recruitment()
	world.request_town_recruitment(&"scrapbroker")
	var party: PartyManagement = world.get("_active_party")
	repo.failures_remaining = 2
	_confirm_matrix(party, replace, 5, StringName(before.formation[5]))
	_expect(world.is_autosave_blocked(), "AC8.7 first failure blocks")
	_expect(world.get_durable_run_state().to_dictionary() == before and world.get("_roster") == roster and roster.get_slot_snapshot() == identities and gold_label.text == gold_text and repo.checkpoint == checkpoint, "AC8.7 first failure preserves complete state live identities HUD and checkpoint")
	_expect(repo.writes.size() == 1 and repo.successful_writes == 0, "AC8.7 first failure attempts once without publication")
	_expect_checkpoint(repo.writes[0], _purchase_expected(before, 5), "AC8.7 first attempted candidate contains exact purchase state")
	_expect(not world.retry_autosave().ok and world.is_autosave_blocked(), "AC8.7 second failure stays blocked")
	_expect(repo.writes.size() == 2 and repo.writes[0] == repo.writes[1], "AC8.7 repeated failure retries exact bytes")
	_expect(repo.checkpoint == checkpoint and repo.successful_writes == 0, "AC8.7 attempted writes never replace successful checkpoint")
	world.close_town_recruitment()
	party.request_placement_cancel()
	party.close_requested.emit()
	_confirm_matrix(party, replace, 5, StringName(before.formation[5]))
	_expect(not world.request_town_recruitment(&"scrapbroker").ok, "AC8.7 pending save blocks purchase")
	_expect(not world.request_party_dismissal(0, &"player_0").ok, "AC8.7 pending save blocks dismissal")
	_expect(not world.apply_session(_session(500), repo), "AC8.7 pending save blocks session replacement")
	_expect(not world.request_move(world.get_runtime_snapshot().player_coord + Vector2i(1, 0)).is_accepted(), "AC8.7 pending save blocks map movement")
	_expect(world.get_valid_destinations().is_empty() and world.has_active_party_management() and world.has_active_town_recruitment(), "AC8.7 pending modal cannot close")
	_expect(world.get_durable_run_state().to_dictionary() == before and world.get("_roster") == roster and roster.get_slot_snapshot() == identities and gold_label.text == gold_text, "AC8.7 failure preserves live identities complete state HP and HUD gold")
	_expect(repo.writes.size() == 2, "AC8.7 blocked actions do not write")
	if discard:
		_expect(world.discard_pending_autosave(), "AC8.7 discard succeeds after repeated failure")
		_expect(repo.checkpoint == checkpoint and world.get_durable_run_state().to_dictionary() == before and world.get("_roster") == roster and roster.get_slot_snapshot() == identities and gold_label.text == gold_text, "AC8.7 discard retains original checkpoint complete state live identities and HUD")
		_expect_live_formation(world, before)
		_confirm_matrix(party, replace, 5, StringName(before.formation[5]))
		_expect(repo.writes.size() == 2, "AC8.7 discard invalidates abandoned callback")
		_expect(world.open_town_recruitment() and world.request_town_recruitment(&"scrapbroker").ok, "AC8.7 discard allows fresh purchase")
		party = world.get("_active_party")
		_confirm_matrix(party, replace, 5, StringName(before.formation[5]))
	else:
		_expect(world.retry_autosave().ok, "AC8.7 third attempt succeeds")
		_expect(repo.writes[2] == repo.writes[0], "AC8.7 successful retry exact candidate bytes")
	_expect(repo.writes.size() == 3 and repo.successful_writes == 1, "AC8.7 only one checkpoint publication")
	_expect(world.get_durable_run_state().to_dictionary() == _purchase_expected(before, 5) and gold_label.text == "250g", "AC8.7 success charges once and updates HUD")
	_expect_live_formation(world, _purchase_expected(before, 5))
	_expect_checkpoint(repo.checkpoint, _purchase_expected(before, 5), "AC8.7 successful retry or fresh purchase checkpoint exact")
	var current: Array[RunCharacter] = (world.get("_roster") as RunRoster).get_slot_snapshot()
	for index: int in 5:
		_expect(current[index] == identities[index], "AC8.7 retry or fresh purchase preserves live survivor identities")
	_expect(not world.retry_autosave().ok and repo.writes.size() == 3, "AC8.7 duplicate retry no-op")
	world.free()
	await process_frame

func _expect_live_formation(world: WorldRuntimeController, expected: Dictionary) -> void:
	var roster: RunRoster = world.get("_roster")
	var slots: Array[RunCharacter] = roster.get_slot_snapshot()
	var ids: Array[String] = []
	var occupied: int = 0
	for character: RunCharacter in slots:
		ids.append(String(character.character_id) if is_instance_valid(character) else "")
		if is_instance_valid(character):
			occupied += 1
	_expect(slots.size() == 6 and ids == expected.formation, "AC8.7 complete live slot IDs equal expected formation including recruit")
	_expect(roster.size() == occupied and occupied == 6 - expected.formation.count(""), "AC8.7 live roster count matches occupied expected slots")

func _expect_checkpoint(bytes: PackedByteArray, expected: Dictionary, message: String) -> void:
	var decoded: Dictionary = load("res://Scripts/Save/world_run_save_codec_v8.gd").decode_any(bytes)
	_expect(decoded.ok and decoded.value.run_state.to_dictionary() == expected, message)

func _last_empty_slot_case(slot: int) -> void:
	var repo := Repository.new()
	var session: Dictionary = _matrix_session(true, slot, 750)
	var data: Dictionary = session.run_state.to_dictionary()
	data.character_hp.erase(data.formation[slot])
	data.formation[slot] = ""
	var decoded: Dictionary = load("res://Scripts/Run/world_run_state.gd").from_dictionary(data, session.plan)
	_expect(decoded.ok, "AC8.7 five-member wounded fixture valid")
	session.run_state = decoded.value
	var world := await _open(session, repo)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var roster: RunRoster = world.get("_roster")
	var identities: Array[RunCharacter] = roster.get_slot_snapshot()
	_expect(roster.size() == 5, "AC8.7 final empty-slot fixture has five members")
	_expect(world.open_town_recruitment() and world.request_town_recruitment(&"scrapbroker").ok, "AC8.7 five-member purchase opens placement")
	var party: PartyManagement = world.get("_active_party")
	party.request_placement(slot, &"scrapbroker")
	party.placement_requested.emit(slot, &"scrapbroker")
	var expected: Dictionary = _purchase_expected(before, slot)
	_expect(world.get_durable_run_state().to_dictionary() == expected, "AC8.7 five-to-six purchase preserves exact wounded state")
	_expect_live_formation(world, expected)
	_expect((world.get("_roster") as RunRoster).is_full() and repo.writes.size() == 1 and repo.successful_writes == 1, "AC8.7 fifth-to-sixth addition fills roster once")
	var current: Array[RunCharacter] = (world.get("_roster") as RunRoster).get_slot_snapshot()
	for index: int in 6:
		if index != slot:
			_expect(current[index] == identities[index], "AC8.7 boundary preserves survivor identities")
	_expect_checkpoint(repo.checkpoint, expected, "AC8.7 boundary checkpoint exact")
	world.free()
	await process_frame
