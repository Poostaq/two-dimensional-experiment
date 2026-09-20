class_name AC86EligibilityRestartTests
extends SceneTree

var failures: int = 0
var save_path: String
var scenario: String

class CountingRepository:
	extends RefCounted
	var inner: RefCounted
	var writes: int = 0
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes += 1
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
	if mode not in ["writer", "reader"] or scenario not in ["dismissal", "replacement", "empty", "duplicate"]:
		push_error("Use --mode=writer|reader --case=dismissal|replacement|empty|duplicate")
		quit(1)
		return
	save_path = "user://ac8-6-eligibility-%s.json" % scenario
	var repository: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(save_path)
	if mode == "writer":
		await _write(repository)
	else:
		await _read(repository)
	if failures == 0:
		print("PASS test_ac8_6_eligibility_restart ", mode, " ", scenario)
	quit(0 if failures == 0 else 1)

func _fixture() -> Dictionary:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass).start("golden-alpha")
	for coord: Vector2i in session.plan.get_cells():
		if session.plan.get_cells()[coord].town_index >= 0 and coord != session.plan.get_boss_coord():
			session.run_state.player_coord = coord
			break
	var ids: Array[StringName] = [&"scrapshield_bruiser", &"wirefang_skirmisher", &"snarewright"]
	if scenario == "empty":
		ids = RunCharacterCatalog.get_goblin_class_ids()
	elif scenario == "replacement":
		ids = [&"scrapshield_bruiser", &"wirefang_skirmisher", &"snarewright", &"shivrunner", &"mobcaller", &"player_0"]
	elif scenario == "duplicate":
		ids = [&"player_0", &"scrapshield_bruiser", &"snarewright"]
	var data: Dictionary = session.run_state.to_dictionary()
	data.gold = 1500
	data.formation = []
	data.character_hp = {}
	for id: StringName in ids:
		var character: RunCharacter = RunCharacterCatalog.create_starters()[0] if id == &"player_0" else RunCharacterCatalog.create_by_class_id(id)
		data.formation.append(String(id))
		data.character_hp[String(id)] = character.max_hp
	while data.formation.size() < 6:
		data.formation.append("")
	var decoded: Dictionary = load("res://Scripts/Run/world_run_state.gd").from_dictionary(data, session.plan)
	_expect(decoded.ok, "fixture validates")
	session.run_state = decoded.value
	return session

func _expected_state() -> Dictionary:
	var data: Dictionary = _fixture().run_state.to_dictionary()
	if scenario in ["dismissal", "duplicate"]:
		data.character_hp.erase(data.formation[0])
		data.formation[0] = ""
	elif scenario == "replacement":
		data.formation[1] = "scrapbroker"
		data.character_hp.erase("wirefang_skirmisher")
		data.character_hp["scrapbroker"] = RunCharacterCatalog.create_by_class_id(&"scrapbroker").max_hp
		data.gold = 1000
	return data

func _expected_offers() -> Array[StringName]:
	match scenario:
		"dismissal":
			return [&"scrapshield_bruiser", &"scrapbroker", &"shivrunner", &"mobcaller"]
		"replacement":
			return [&"wirefang_skirmisher"]
		"duplicate":
			return [&"wirefang_skirmisher", &"scrapbroker", &"shivrunner", &"mobcaller"]
	return []

func _write(repository: RefCounted) -> void:
	var session: Dictionary = _fixture()
	var bytes: PackedByteArray = load("res://Scripts/Save/world_run_save_codec_v5.gd").encode(session.plan, session.resolved_seed, session.run_state)
	_expect(repository.replace_atomic(bytes).ok, "isolated baseline persists")
	var counted := CountingRepository.new()
	counted.inner = repository
	var world: WorldRuntimeController = await _open(session, counted)
	if scenario in ["dismissal", "duplicate"]:
		world.open_party_management()
		var id: StringName = world.get_durable_run_state().formation[0]
		_expect(world.request_party_dismissal(0, id).ok, "writer production dismissal")
		world.call("_on_party_close_requested")
	elif scenario == "replacement":
		_expect(world.open_town_recruitment(), "writer opens town")
		_expect(world.request_town_recruitment(&"scrapbroker").ok, "writer selects absent recruit")
		var party: PartyManagement = world.get("_active_party")
		party.request_replacement(1, &"wirefang_skirmisher", &"scrapbroker")
		world.close_town_recruitment()
	_expect(counted.writes == (0 if scenario == "empty" else 1), "writer exact transaction count")
	_expect(world.get_durable_run_state().to_dictionary() == _expected_state(), "writer exact state")
	_expect(world.get_town_recruitment_context().class_ids == _expected_offers(), "writer ordered eligibility")
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
	_expect(world.get_durable_run_state().to_dictionary() == _expected_state(), "reader exact formation HP gold and world state")
	for attempt: int in 2:
		_expect(world.open_town_recruitment(), "reader opens and reopens")
		_expect(world.get_town_recruitment_context().class_ids == _expected_offers(), "reader derives exact ordered offers")
		var panel: Control = world.get("_town_panel")
		_expect(panel.get_node("%Offers").get_child_count() == _expected_offers().size(), "reader actual offer controls")
		if scenario == "empty":
			_expect(panel.get_node("%EmptyLabel").visible, "reader actual empty state")
		world.close_town_recruitment()
	_expect(counted.writes == 0 and FileAccess.get_file_as_bytes(save_path) == bytes, "Continue browsing never writes or charges")
	world.free()
	await process_frame

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
