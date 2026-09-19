class_name AC82TerminalLauncherTests
extends SceneTree

const SLOT: String = "user://ac82-terminal-launcher-test.json"
const EVIDENCE: String = "res://Docs/Specs/AC8/Evidence/AC8.2"
var failures: int = 0
var sessions: int = 0
var capture: bool = false

class Repository:
	extends RefCounted
	var inner: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(SLOT)
	var fail_next: bool = false
	func has_save() -> bool:
		return inner.has_save()
	func inspect_slot() -> Dictionary:
		return inner.inspect_slot()
	func load_validated() -> Dictionary:
		return inner.load_validated()
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		if fail_next:
			fail_next = false
			return {"ok": false, "error": load("res://Scripts/Save/world_save_error.gd").new("SAVE_ENVELOPE_INVALID", "terminal_test_failure")}
		return inner.replace_atomic(bytes)

class InvalidStartService:
	extends RefCounted
	var session: Dictionary
	func start(_seed: String, _config: Dictionary, _policy: String, _commander: StringName) -> Dictionary:
		return session

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	capture = args.has("capture")
	if args.has("reader"):
		await _reader()
	else:
		await _writer()
	if failures == 0:
		print("PASS test_ac8_2_terminal_launcher " + ("reader" if args.has("reader") else "writer"))
	quit(0 if failures == 0 else 1)

func _launcher(repository: Repository) -> WorldProductionLauncher:
	var launcher: WorldProductionLauncher = load("res://Scenes/world_run_start.tscn").instantiate()
	launcher.set("_repository", repository)
	root.add_child(launcher)
	await process_frame
	launcher.session_ready.connect(func(_session: Dictionary) -> void: sessions += 1)
	return launcher

func _session(kind: String) -> Dictionary:
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
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
	return session

func _bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes(SLOT)

func _writer() -> void:
	for kind: String in ["combat", "boss"]:
		var repository := Repository.new()
		var session: Dictionary = _session(kind)
		var codec: Script = load("res://Scripts/Save/world_run_save_codec_v4.gd")
		_expect(repository.replace_atomic(codec.encode(session.plan, session.resolved_seed, session.run_state)).get("ok", false), "test active bytes saved")
		var before: PackedByteArray = _bytes()
		var launcher: WorldProductionLauncher = await _launcher(repository)
		_expect(launcher.get_screen() == WorldProductionLauncher.Screen.MAIN, "launcher remains MAIN during Continue")
		_expect(launcher.continue_saved_run().get("ok", false), "active slot continues")
		await process_frame
		var host: Control = launcher.get_node("%WorldHost")
		_expect(host.get_child_count() == 1, "continued session opens world")
		if host.get_child_count() != 1:
			launcher.free()
			return
		var world: WorldRuntimeController = host.get_child(0)
		world.call("_on_battle_requested", session.run_state.player_coord, kind)
		await process_frame
		var arena: BattleArena = world.get_node("BattleHost").get_child(0)
		arena.set("_auto_enemy_turns", false)
		var units: Array = arena.get("_units")
		var actor: BattleUnitState = arena.get_current_unit()
		var enemies: Array[BattleUnitState] = []
		for unit: BattleUnitState in units:
			if unit.side == BattleUnitState.Side.ENEMY:
				enemies.append(unit)
		if is_instance_valid(actor) and actor.side == BattleUnitState.Side.PLAYER and enemies.size() > 1:
			actor.power = 1000
			_expect(arena.confirm_default_attack(actor.unit_id, enemies[0].unit_id, arena.get_battle_revision()), "prior enemy kill commits before defeat")
		for unit: BattleUnitState in units:
			if unit.side == BattleUnitState.Side.PLAYER:
				unit.current_hp = 0
		repository.fail_next = true
		arena.call("_complete_battle", BattleOutcome.Type.DEFEAT)
		arena.call("_refresh_turn_ui")
		await process_frame
		_expect(world.is_run_termination_pending() and world.is_autosave_blocked(), "failed loss retains pending world")
		_expect(_bytes() == before, "failed terminal save preserves bytes")
		var overlay: Control = world.get_node("%AutosaveFailureOverlay")
		_expect(overlay.visible and not overlay.get_node("%ReturnButton").visible and overlay.get_node("%ReturnButton").disabled, "loss failure exposes retry-only return flow")
		var count_before: int = sessions
		_expect(not launcher.continue_saved_run().get("ok", true), "Continue blocked during loss")
		_expect(not launcher.request_start("blocked-new").get("ok", true), "new run blocked during loss")
		_expect(not launcher.confirm_overwrite().get("ok", true), "overwrite blocked during loss")
		launcher.call("_on_session_ready", _session("combat"))
		launcher.call("_on_world_launcher_return_requested")
		await process_frame
		_expect(sessions == count_before, "no early session_ready")
		_expect(host.get_child_count() == 1 and host.get_child(0) == world, "direct session callback cannot replace loss")
		_expect(_bytes() == before, "blocked replacement leaves old bytes intact")
		if kind == "combat":
			await _capture("terminal-save-failure-retry-only.png")
		var retry_button: Button = overlay.get_node("%RetryButton")
		retry_button.grab_focus()
		var press := InputEventKey.new()
		press.keycode = KEY_ENTER
		press.physical_keycode = KEY_ENTER
		press.pressed = true
		root.push_input(press)
		var release: InputEventKey = press.duplicate()
		release.pressed = false
		root.push_input(release)
		await process_frame
		_expect(host.get_child_count() == 0, "successful loss returns menu")
		_expect(launcher.get_node("%ContinueButton").disabled, "Continue refreshed disabled on MAIN")
		_expect(not repository.load_validated().get("ok", true), "real repository rejects terminal Continue")
		_expect(repository.inspect_slot().get("ok", false), "real repository retains valid lost slot")
		_expect(repository.inspect_slot().value.run_state.gold == 100, "loss awards zero even after a prior enemy kill")
		if kind == "combat":
			await _capture("terminal-menu-continue-disabled.png")
		launcher.free()
		await process_frame

func _reader() -> void:
	var repository := Repository.new()
	var inspected: Dictionary = repository.inspect_slot()
	_expect(inspected.get("ok", false), "second process reads valid slot")
	if not inspected.get("ok", false):
		return
	_expect(inspected.value.run_state.run_status == "lost", "second process sees persisted lost status")
	var old_bytes: PackedByteArray = _bytes()
	var launcher: WorldProductionLauncher = await _launcher(repository)
	_expect(launcher.get_node("%ContinueButton").disabled, "second process Continue disabled")
	_expect(not launcher.continue_saved_run().get("ok", true), "direct Continue cannot resume lost")
	_expect(sessions == 0, "lost Continue emits no session")
	var invalid := InvalidStartService.new()
	invalid.session = _session("combat")
	invalid.session.run_state.gold = -1
	launcher.set("_start_service", invalid)
	_expect(not launcher.request_start("invalid-new").get("ok", true), "invalid new run encoding rejected")
	_expect(_bytes() == old_bytes and sessions == 0, "invalid encoding never overwrites terminal bytes")
	invalid.session["run_state"] = null
	_expect(not launcher.request_start("missing-state").get("ok", true), "missing new run state rejected")
	_expect(_bytes() == old_bytes and sessions == 0, "empty encoding preserves terminal bytes")
	launcher.set("_start_service", load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass))
	_expect(launcher.request_start("golden-beta").get("ok", false), "fresh new run replaces terminal slot without overwrite confirmation")
	await process_frame
	_expect(launcher.get_node("%WorldHost").get_child_count() == 1, "new session opens world")
	if launcher.get_node("%WorldHost").get_child_count() != 1:
		launcher.free()
		return
	var world: WorldRuntimeController = launcher.get_node("%WorldHost").get_child(0)
	_expect(world.get_durable_run_state().gold == 100, "replacement run starts with 100 gold")
	_expect(world.get_durable_run_state().battle_settlements.is_empty(), "replacement clears receipts")
	_expect(repository.load_validated().get("ok", false), "replacement is playable from disk")
	if capture:
		await _victory_capture(world)
	launcher.free()
	await process_frame

func _victory_capture(world: WorldRuntimeController) -> void:
	var plan: WorldPlan = world.get("_runtime_plan")
	var state: RefCounted = world.get_durable_run_state()
	for coord: Vector2i in plan.get_cells():
		if plan.get_cells()[coord].get("encounter") == "combat":
			state.player_coord = coord
			break
	world.call("_on_battle_requested", state.player_coord, "combat")
	await process_frame
	var arena: BattleArena = world.get_node("BattleHost").get_child(0)
	var units: Array[BattleUnitState] = []
	for player: BattleUnitState in arena.get("_configured_player_units"):
		player.power = 100
		units.append(player)
	var enemy: BattleUnitState = BattleUnitState.new(&"capture_enemy", "Evidence Enemy", BattleUnitState.Side.ENEMY, 0, 1, 1)
	units.append(enemy)
	arena.configure_units(units)
	var actor: BattleUnitState = arena.get_current_unit()
	_expect(arena.confirm_default_attack(actor.unit_id, enemy.unit_id, arena.get_battle_revision()), "capture victory action commits")
	_expect(world.get_durable_run_state().gold == 150, "capture victory publishes 150g")
	world.call("_on_battle_closed")
	await process_frame
	await _capture("victory-published-wallet-150g.png")

func _capture(filename: String) -> void:
	if not capture:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(EVIDENCE))
	var ignore: FileAccess = FileAccess.open(EVIDENCE + "/.gdignore", FileAccess.WRITE)
	ignore.close()
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_expect(image.save_png(EVIDENCE + "/" + filename) == OK, "capture saved " + filename)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
