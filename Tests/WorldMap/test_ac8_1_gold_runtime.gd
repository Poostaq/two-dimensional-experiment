class_name AC81GoldRuntimeTests
extends SceneTree

var _failures: int = 0


class MemoryRepository:
	extends RefCounted

	var bytes: PackedByteArray
	var fail_next: bool = false
	var writes: int = 0

	func replace_atomic(candidate: PackedByteArray) -> Dictionary:
		writes += 1
		if fail_next:
			fail_next = false
			return {"ok": false, "error": null}
		bytes = candidate.duplicate()
		return {"ok": true, "error": null}

	func load_validated() -> Dictionary:
		var codec: GDScript = load("res://Scripts/Save/world_run_save_codec_v4.gd")
		return codec.decode_any(bytes)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
	var repository := MemoryRepository.new()
	var world: WorldRuntimeController = await _open(session, repository)
	_expect(is_instance_valid(world), "new session applies")
	if not is_instance_valid(world):
		_finish()
		return
	_check_balance(world, 100, "new run")
	var coordinator: RefCounted = world.get("_save_coordinator")
	var candidate_data: Dictionary = world.get_durable_run_state().to_dictionary()
	candidate_data["gold"] = 375
	var state_script: GDScript = load("res://Scripts/Run/world_run_state.gd")
	var candidate: RefCounted = state_script.from_dictionary(candidate_data, session["plan"])["value"]
	repository.fail_next = true
	var failed: Dictionary = coordinator.commit_candidate(candidate, Callable(world, "_publish_current_state"), "wallet_fixture")
	_expect(not failed.get("ok", true), "fixture save failure reported")
	_check_balance(world, 100, "failed save")
	_expect(world.retry_autosave().get("ok", false), "retry succeeds")
	_check_balance(world, 375, "retry publication")
	var loaded: Dictionary = repository.load_validated()
	_expect(loaded.get("ok", false) and loaded["value"]["run_state"].gold == 375, "retry saves 375g")
	var writes_before: int = repository.writes
	_expect(not world.retry_autosave().get("ok", true), "second retry has no pending transaction")
	_expect(repository.writes == writes_before, "second retry does not write")
	world.open_party_management()
	world.call("_on_party_move_requested", 0, 3, &"player_0")
	world.call("_on_party_close_requested")
	_check_balance(world, 375, "formation save")
	_expect(repository.load_validated()["value"]["run_state"].gold == 375, "formation save retains gold")
	var destinations: Array[Vector2i] = world.get_valid_destinations()
	_expect(not destinations.is_empty(), "movement available")
	if not destinations.is_empty():
		world.request_move(destinations[0])
		_check_balance(world, 375, "accepted move")
		world.close_active_encounter()
		_check_balance(world, 375, "encounter close")
	var preparation: RefCounted = load("res://Scripts/Battle/battle_preparation_record.gd").none()
	var preparation_candidate: RefCounted = world.call("_build_preparation_candidate", preparation, false)
	_expect(is_instance_valid(preparation_candidate) and preparation_candidate.gold == 375, "preparation candidate retains gold")
	var health: Dictionary[StringName, int] = world.get_durable_run_state().get_character_hp_snapshot()
	var recovery_candidate: RefCounted = world.call("_build_candidate_state", world.get("_model"), false, null, false, health)
	_expect(is_instance_valid(recovery_candidate) and recovery_candidate.gold == 375, "recovery candidate retains gold")
	loaded = repository.load_validated()
	world.free()
	await process_frame
	world = await _open(loaded["value"], repository)
	_check_balance(world, 375, "reload")
	coordinator = world.get("_save_coordinator")
	candidate_data = world.get_durable_run_state().to_dictionary()
	candidate_data["gold"] = 0
	candidate = state_script.from_dictionary(candidate_data, session["plan"])["value"]
	_expect(coordinator.commit_candidate(candidate, Callable(world, "_publish_current_state"), "zero_wallet_fixture").get("ok", false), "zero candidate commits")
	_check_balance(world, 0, "zero publication")
	loaded = repository.load_validated()
	world.free()
	await process_frame
	world = await _open(loaded["value"], repository)
	_check_balance(world, 0, "zero reload")
	world.free()
	await process_frame
	world = await _open(service.start("golden-beta"), MemoryRepository.new())
	_check_balance(world, 100, "replacement run")
	world.free()
	await process_frame
	_finish()


func _open(session: Dictionary, repository: MemoryRepository) -> WorldRuntimeController:
	var packed: PackedScene = load("res://Scenes/world_map_runtime.tscn")
	var world := packed.instantiate() as WorldRuntimeController
	root.add_child(world)
	await process_frame
	if not world.apply_session(session, repository):
		world.free()
		return null
	return world


func _check_balance(world: WorldRuntimeController, amount: int, label: String) -> void:
	_expect(world.get_durable_run_state().get("gold") == amount, label + " durable gold")
	var hud: Node = world.get_node("%WorldMapHud")
	var gold: Label = hud.get_node_or_null("%GoldLabel")
	_expect(is_instance_valid(gold) and gold.text == "%dg" % amount, label + " HUD gold")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _finish() -> void:
	if _failures == 0:
		print("PASS test_ac8_1_gold_runtime")
	quit(0 if _failures == 0 else 1)
