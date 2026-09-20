extends SceneTree
const SAVE_PATH: String = "user://ac8-5-recruitment-verification.json"
var failures: int = 0

class FaultRepository:
	extends RefCounted
	var inner: RefCounted
	var fail_next: bool = false
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		if fail_next:
			fail_next = false
			return {"ok": false, "value": null, "error": null}
		return inner.replace_atomic(bytes)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["writer", "reader"] or args[1] not in ["success", "retry", "discard"]:
		print("FAIL: pass -- writer|reader success|retry|discard")
		quit(1)
		return
	var repository: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(SAVE_PATH)
	if args[0] == "writer":
		await _write(repository, args[1])
	else:
		await _read(repository, args[1])
	if failures == 0:
		print("PASS test_ac8_5_recruitment_restart ", args[0], " ", args[1])
	quit(0 if failures == 0 else 1)

func _write(repository: RefCounted, scenario: String) -> void:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass).start("golden-alpha")
	for coord: Vector2i in session.plan.get_cells():
		if session.plan.get_cells()[coord].town_index >= 0:
			session.run_state.player_coord = coord
			break
	session.run_state.gold = 500
	var bytes: PackedByteArray = load("res://Scripts/Save/world_run_save_codec_v5.gd").encode(session.plan, session.resolved_seed, session.run_state)
	_expect(repository.replace_atomic(bytes).ok, "write isolated baseline")
	var fault := FaultRepository.new()
	fault.inner = repository
	var world: WorldRuntimeController = await _open(session, fault)
	_expect(world.call("open_town_recruitment"), "writer opens town")
	_expect(world.call("request_town_recruitment", &"scrapbroker").ok, "writer selects class")
	fault.fail_next = scenario != "success"
	var party: PartyManagement = world.get("_active_party")
	party.request_placement(5, &"scrapbroker")
	if scenario != "success":
		_expect(world.is_autosave_blocked() and world.get_durable_run_state().gold == 500, "failure is unpublished")
		if scenario == "retry":
			_expect(world.retry_autosave().ok, "writer retry succeeds")
		else:
			_expect(world.discard_pending_autosave(), "writer discard succeeds")
	_expect(world.get_durable_run_state().gold == (500 if scenario == "discard" else 0), "writer final balance")
	world.free()
	await process_frame

func _read(repository: RefCounted, scenario: String) -> void:
	var loaded: Dictionary = repository.load_validated()
	_expect(loaded.ok, "reader loads isolated run")
	if not loaded.ok:
		return
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(SAVE_PATH)
	var world: WorldRuntimeController = await _open(loaded.value, repository)
	var state: RefCounted = world.get_durable_run_state()
	var purchased: bool = scenario != "discard"
	_expect(state.gold == (0 if purchased else 500), "reader exact gold")
	_expect(state.formation[5] == (&"scrapbroker" if purchased else &""), "reader chosen slot")
	_expect(world.call("open_town_recruitment"), "reader reopens town")
	var context: Dictionary = world.call("get_town_recruitment_context")
	_expect(context.class_ids.has(&"scrapbroker") != purchased, "reader fresh class eligibility")
	if purchased:
		_expect(state.get_character_hp_snapshot()[&"scrapbroker"] == RunCharacterCatalog.create_by_class_id(&"scrapbroker").max_hp, "reader recruit health")
	world.call("close_town_recruitment")
	_expect(FileAccess.get_file_as_bytes(SAVE_PATH) == bytes, "Continue browsing does not rewrite purchase")
	world.free()
	await process_frame

func _open(session: Dictionary, repository: RefCounted) -> WorldRuntimeController:
	var world: WorldRuntimeController = load("res://Scenes/world_map_runtime.tscn").instantiate()
	world.auto_initialize_runtime = false
	root.add_child(world)
	await process_frame
	_expect(world.apply_session(session, repository), "production apply_session")
	return world

func _expect(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
