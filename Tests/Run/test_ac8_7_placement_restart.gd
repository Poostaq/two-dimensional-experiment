class_name AC87PlacementRestartTests
extends SceneTree

var failures: int = 0
var scenario: String
var save_path: String

class CountingRepository:
	extends RefCounted
	var inner: RefCounted
	var writes: int = 0
	var fail_next: bool = false
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes += 1
		if fail_next:
			fail_next = false
			return {"ok": false, "value": null, "error": null}
		return inner.replace_atomic(bytes)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var mode: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--mode="):
			mode = argument.trim_prefix("--mode=")
		if argument.begins_with("--case="):
			scenario = argument.trim_prefix("--case=")
	if mode not in ["writer", "reader"] or scenario not in [
		"add", "replace", "failed_add", "failed_replace",
		"retry_add", "retry_replace", "discard_add", "discard_replace",
	]:
		push_error("Expected --mode=writer|reader and valid --case")
		quit(1)
		return
	save_path = "user://ac8-7-placement-%s.json" % scenario
	var repository: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(save_path)
	if mode == "writer":
		await _write(repository)
	else:
		await _read(repository)
	if failures == 0:
		print("PASS test_ac8_7_placement_restart ", mode, " ", scenario)
	quit(0 if failures == 0 else 1)

func _fixture() -> Dictionary:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass).start("golden-alpha")
	for coord: Vector2i in session.plan.get_cells():
		if session.plan.get_cells()[coord].town_index >= 0 and coord != session.plan.get_boss_coord():
			session.run_state.player_coord = coord
			break
	var ids: Array[StringName] = [&"player_0", &"", &"player_1", &"", &"", &"player_2"]
	if scenario.ends_with("replace"):
		ids = [&"player_0", &"player_1", &"player_2", &"scout", &"champion", &"shivrunner"]
	var data: Dictionary = session.run_state.to_dictionary()
	data.gold = 500
	data.formation = []
	data.character_hp = {}
	for id: StringName in ids:
		data.formation.append(String(id))
		if id.is_empty():
			continue
		var character: RunCharacter
		for starter: RunCharacter in RunCharacterCatalog.create_starters():
			if starter.character_id == id:
				character = starter
		if id == &"scout":
			character = RunCharacterCatalog.create_for_reward(RunCharacterCatalog.COMBAT_SCOUT_REWARD_ID)
		elif id == &"champion":
			character = RunCharacterCatalog.create_for_reward(RunCharacterCatalog.BOSS_CHAMPION_REWARD_ID)
		elif not is_instance_valid(character):
			character = RunCharacterCatalog.create_by_class_id(id)
		data.character_hp[String(id)] = character.max_hp - 1
	var decoded: Dictionary = load("res://Scripts/Run/world_run_state.gd").from_dictionary(data, session.plan)
	_expect(decoded.ok, "fixture validates")
	session.run_state = decoded.value
	return session

func _expected_state() -> Dictionary:
	var data: Dictionary = _fixture().run_state.to_dictionary()
	if scenario.begins_with("failed_") or scenario.begins_with("discard_"):
		return data
	var old_id: String = data.formation[4]
	if not old_id.is_empty():
		data.character_hp.erase(old_id)
	data.formation[4] = "scrapbroker"
	data.character_hp["scrapbroker"] = RunCharacterCatalog.create_by_class_id(&"scrapbroker").max_hp
	data.gold = 0
	return data

func _write(repository: RefCounted) -> void:
	var session: Dictionary = _fixture()
	var bytes: PackedByteArray = load("res://Scripts/Save/world_run_save_codec_v5.gd").encode(session.plan, session.resolved_seed, session.run_state)
	_expect(repository.replace_atomic(bytes).ok, "baseline persists")
	var counted := CountingRepository.new()
	counted.inner = repository
	var world: WorldRuntimeController = await _open(session, counted)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	_expect(world.open_town_recruitment(), "writer opens town")
	_expect(world.request_town_recruitment(&"scrapbroker").ok, "writer selects")
	var party: PartyManagement = world.get("_active_party")
	counted.fail_next = scenario.contains("_")
	if scenario.ends_with("replace"):
		party.request_replacement(4, &"champion", &"scrapbroker")
	else:
		party.request_placement(4, &"scrapbroker")
	if scenario.contains("_"):
		_expect(world.is_autosave_blocked(), "failed transaction blocks")
		_expect(world.get_durable_run_state().to_dictionary() == before, "failed state unchanged")
		_expect(FileAccess.get_file_as_bytes(save_path) == bytes, "failed disk checkpoint unchanged")
	if scenario.begins_with("retry_"):
		_expect(world.retry_autosave().ok, "retry publishes")
	elif scenario.begins_with("discard_"):
		_expect(world.discard_pending_autosave(), "discard restores")
	_expect(counted.writes == (2 if scenario.begins_with("retry_") else 1), "exact attempts")
	_expect(world.get_durable_run_state().to_dictionary() == _expected_state(), "writer exact state")
	world.free()
	await process_frame

func _read(repository: RefCounted) -> void:
	var loaded: Dictionary = repository.load_validated()
	_expect(loaded.ok, "independent reader loads")
	if not loaded.ok:
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	var counted := CountingRepository.new()
	counted.inner = repository
	var world: WorldRuntimeController = await _open(loaded.value, counted)
	_expect(world.get_durable_run_state().to_dictionary() == _expected_state(), "reader exact formation HP wallet world state")
	_expect(not world.is_autosave_blocked() and not world.has_active_party_management(), "no phantom pending UI")
	for attempt: int in 2:
		_expect(world.open_town_recruitment(), "reader opens town")
		world.close_town_recruitment()
	_expect(counted.writes == 0 and FileAccess.get_file_as_bytes(save_path) == bytes, "Continue browsing never charges or writes")
	world.free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

func _open(session: Dictionary, repository: RefCounted) -> WorldRuntimeController:
	var world: WorldRuntimeController = load("res://Scenes/world_map_runtime.tscn").instantiate()
	world.auto_initialize_runtime = false
	root.add_child(world)
	await process_frame
	_expect(world.apply_session(session, repository), "production session applies")
	return world

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
