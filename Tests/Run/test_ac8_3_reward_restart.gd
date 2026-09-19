class_name AC83RewardRestartTests
extends SceneTree

const SLOT: String = "user://ac83-reward-restart-test.json"
const EVIDENCE: String = "res://Docs/Specs/AC8/Evidence/AC8.3/"
var failures: int = 0
var capture: bool = false

class Repository:
	extends RefCounted
	var inner: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(SLOT)
	var fail_next: bool = false
	var writes: Array[PackedByteArray] = []
	func has_save() -> bool:
		return inner.has_save()
	func inspect_slot() -> Dictionary:
		return inner.inspect_slot()
	func load_validated() -> Dictionary:
		return inner.load_validated()
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes.append(bytes.duplicate())
		if fail_next:
			fail_next = false
			return {"ok":false,"error":load("res://Scripts/Save/world_save_error.gd").new("WRITE_FAILED","restart_test_failure")}
		return inner.replace_atomic(bytes)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	capture = args.has("capture")
	var mode: String = args[0] if not args.is_empty() else ""
	var kind: String = args[1] if args.size() > 1 else ""
	if mode not in ["writer", "reader", "acknowledged-reader"] or kind not in ["combat", "boss"]:
		_expect(false, "requires writer/reader/acknowledged-reader combat/boss")
	elif mode == "writer":
		await _writer(kind)
	else:
		await _reader(kind, mode == "acknowledged-reader")
	if failures == 0:
		print("PASS test_ac8_3_reward_restart " + mode + " " + kind)
	quit(0 if failures == 0 else 1)

func _launcher(repository: Repository) -> WorldProductionLauncher:
	var launcher: WorldProductionLauncher = load("res://Scenes/world_run_start.tscn").instantiate()
	launcher.set("_repository", repository)
	root.add_child(launcher)
	await process_frame
	return launcher

func _writer(kind: String) -> void:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass).start("golden-alpha")
	var plan: WorldPlan = session.plan
	var state: RefCounted = session.run_state
	var coord: Vector2i = plan.get_boss_coord()
	if kind == "combat":
		for cell: Vector2i in plan.get_cells():
			if plan.get_cells()[cell].get("encounter") == "combat":
				coord = cell
				break
	state.player_coord = coord
	state.boss_engaged = kind == "boss"
	var repository := Repository.new()
	var codec: Script = load("res://Scripts/Save/world_run_save_codec_v5.gd")
	_expect(repository.replace_atomic(codec.encode(plan, session.resolved_seed, state)).get("ok", false), "private active fixture persisted")
	var launcher: WorldProductionLauncher = await _launcher(repository)
	_expect(launcher.continue_saved_run().get("ok", false), "production launcher continues fixture")
	await process_frame
	var host: Control = launcher.get_node("%WorldHost")
	if host.get_child_count() != 1:
		_expect(false, "production world opened")
		launcher.free()
		return
	var world: WorldRuntimeController = host.get_child(0)
	world.call("_on_battle_requested", coord, kind)
	await process_frame
	var arena: BattleArena = world.get_node("BattleHost").get_child(0)
	var units: Array[BattleUnitState] = []
	for unit: BattleUnitState in arena.get("_units"):
		if unit.side == BattleUnitState.Side.PLAYER:
			unit.speed = 100
			unit.current_hp = maxi(1, unit.max_hp - 2)
			units.append(unit)
	for index: int in 3:
		units.append(BattleUnitState.new(StringName("restart_enemy_%d" % index), "Enemy", 1, index, 1, 1))
	arena.configure_units(units)
	for index: int in 3:
		arena.perform_debug_damage()
	_expect(arena.is_battle_complete(), "three real enemy defeats end battle")
	var durable: RefCounted = world.get_durable_run_state()
	_expect(durable.gold == 250 and durable.battle_settlements.size() == 1, "one 150g settlement")
	var receipt: Dictionary = durable.battle_settlements[0]
	_expect(receipt.defeated_enemy_ids.size() == 3 and receipt.earned_gold == 150, "receipt records actual three kills")
	_expect(world.has_pending_gold_reward(), "writer retains pending reward")
	var panel: Control = world.get_node("GoldRewardHost/BattleGoldRewardPanel")
	_check_panel(world, panel, true)
	var baseline: FileAccess = FileAccess.open(EVIDENCE + "restart-" + kind + "-baseline.json", FileAccess.WRITE)
	baseline.store_string(durable.canonical_key())
	baseline.close()
	await _capture_sizes(kind + "-victory")
	var pending_bytes: PackedByteArray = FileAccess.get_file_as_bytes(SLOT)
	repository.fail_next = true
	panel.get_node("%ContinueButton").pressed.emit()
	_expect(world.is_autosave_blocked() and panel.visible, "writer acknowledgement fails and remains visible")
	_expect(FileAccess.get_file_as_bytes(SLOT) == pending_bytes, "failed ack leaves pending disk checkpoint intact")
	await _capture_sizes(kind + "-ack-failure")
	world.call("_on_autosave_return_requested")
	await process_frame
	_expect(host.get_child_count() == 0, "failed acknowledgement Return reaches launcher")
	_expect(FileAccess.get_file_as_bytes(SLOT) == pending_bytes, "Return preserves pending checkpoint")
	launcher.free()
	await process_frame

func _reader(kind: String, acknowledged: bool) -> void:
	var baseline_path: String = EVIDENCE + "restart-" + kind + "-baseline.json"
	_expect(FileAccess.file_exists(baseline_path), "writer baseline exists")
	if not FileAccess.file_exists(baseline_path):
		return
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(baseline_path))
	if acknowledged:
		expected.pending_reward_battle_id = ""
	var repository := Repository.new()
	var disk_before: PackedByteArray = FileAccess.get_file_as_bytes(SLOT)
	var launcher: WorldProductionLauncher = await _launcher(repository)
	_expect(launcher.continue_saved_run().get("ok", false), "new process production Continue")
	await process_frame
	var host: Control = launcher.get_node("%WorldHost")
	if host.get_child_count() != 1:
		_expect(false, "new process world opened")
		launcher.free()
		return
	var world: WorldRuntimeController = host.get_child(0)
	var panel: Control = world.get_node("GoldRewardHost/BattleGoldRewardPanel")
	_expect(JSON.parse_string(world.get_durable_run_state().canonical_key()) == expected, "restart preserves full wallet health roster receipt and moves")
	_expect(not world.has_active_battle(), "restart creates no arena or consumed enemies")
	_expect(repository.writes.is_empty() and FileAccess.get_file_as_bytes(SLOT) == disk_before, "Continue performs no reaward recovery or save")
	_check_panel(world, panel, not acknowledged)
	if not acknowledged:
		await _capture_sizes(kind + "-restored")
		var id: String = expected.pending_reward_battle_id
		var button: Button = panel.get_node("%ContinueButton")
		button.grab_focus()
		var press := InputEventKey.new()
		press.keycode = KEY_ENTER
		press.physical_keycode = KEY_ENTER
		press.pressed = true
		root.push_input(press)
		var release: InputEventKey = press.duplicate()
		release.pressed = false
		root.push_input(release)
		await process_frame
		_expect(repository.writes.size() == 1, "keyboard Continue saves exactly one acknowledgement")
		expected.pending_reward_battle_id = ""
		_expect(JSON.parse_string(world.get_durable_run_state().canonical_key()) == expected, "ack only clears pending")
		_check_panel(world, panel, false)
		world.acknowledge_gold_reward(id)
		_expect(repository.writes.size() == 1, "duplicate Continue does not write")
		var saved: Dictionary = repository.load_validated()
		_expect(saved.get("ok", false) and JSON.parse_string(saved.value.run_state.canonical_key()) == expected, "ack durably preserves full state")
	launcher.free()
	await process_frame

func _check_panel(world: WorldRuntimeController, panel: Control, pending: bool) -> void:
	_expect(panel.visible == pending and world.has_pending_gold_reward() == pending, "panel visibility matches durable pending")
	_expect(world.get_durable_run_state().gold == 250, "wallet stays 250g")
	_expect(world.get_node("%WorldMapHud").get_node("%GoldLabel").text == "250g", "HUD shows wallet total")
	if pending:
		_expect(panel.get_node("%AmountLabel").text == "Gold received: 150g", "panel shows receipt award not wallet")
		_expect(world.get_valid_destinations().is_empty(), "pending blocks world input")
	else:
		_expect(not world.get_valid_destinations().is_empty(), "acknowledged world accepts input")

func _capture_sizes(label: String) -> void:
	if not capture:
		return
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		root.size = resolution
		root.content_scale_size = resolution
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var rendered: Image = root.get_texture().get_image()
		_expect(rendered.get_size() == resolution, "capture has requested dimensions")
		var filename: String = "%s%s-%dx%d.png" % [EVIDENCE, label, resolution.x, resolution.y]
		_expect(rendered.save_png(filename) == OK, "capture saved")
		print("CAPTURE ", filename)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
