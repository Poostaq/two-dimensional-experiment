class_name CaptureAC87Placement
extends SceneTree

var width: int = 1280
var save_path: String
var launcher: Control
var world: WorldRuntimeController

class FailingRepository:
	extends RefCounted
	var inner: RefCounted
	var fail_next: bool = false
	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		if fail_next:
			fail_next = false
			return {"ok": false, "value": null, "error": load("res://Scripts/Save/world_save_error.gd").new("SAVE_WRITE_FAILED", "AC8.7 injected failure")}
		return inner.replace_atomic(bytes)

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--width="):
			width = argument.trim_prefix("--width=").to_int()
	save_path = "user://ac8-7-rendered-%d.json" % width
	var repository: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(save_path)
	await _seed_and_launch(repository, false, 499)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	await _open()
	var offer: Button = _panel().get_node("%Offers/scrapbroker")
	assert(offer.disabled)
	_click(offer)
	await process_frame
	assert(not world.has_active_party_management() and world.get_durable_run_state().to_dictionary() == before)
	await _capture("insufficient")
	launcher.queue_free()
	await process_frame
	for replacement: bool in [false, true]:
		var tag: String = "replacement" if replacement else "placement"
		await _seed_and_launch(repository, replacement, 500)
		before = world.get_durable_run_state().to_dictionary()
		var expected: Dictionary = before.duplicate(true)
		expected.gold = 0
		var displaced: String = expected.formation[4]
		if not displaced.is_empty():
			expected.character_hp.erase(displaced)
		expected.formation[4] = "scrapbroker"
		expected.character_hp["scrapbroker"] = RunCharacterCatalog.create_by_class_id(&"scrapbroker").max_hp
		await _open()
		await _select()
		var party: PartyManagement = world.get("_active_party")
		await _capture(tag)
		var camera: Camera2D = world.find_children("*", "Camera2D", true, false)[0]
		var position_before: Vector2 = camera.position
		var zoom_before: Vector2 = camera.zoom
		_key(KEY_RIGHT)
		_mouse(Vector2(10, 350), MOUSE_BUTTON_WHEEL_UP, true)
		await process_frame
		assert(camera.position == position_before and camera.zoom == zoom_before)
		_key(KEY_ESCAPE)
		await process_frame
		assert(not world.has_active_party_management())
		assert(world.get_durable_run_state().to_dictionary() == before)
		await _select()
		party = world.get("_active_party")
		_click(party.get_node("%CancelPlacementButton"))
		await process_frame
		assert(not world.has_active_party_management())
		assert(world.get_durable_run_state().to_dictionary() == before)
		await _capture(tag + "-cancelled")
		await _select()
		party = world.get("_active_party")
		var failed := FailingRepository.new()
		failed.inner = repository
		failed.fail_next = true
		world.get("_save_coordinator").set("_repository", failed)
		await _drag_recruit(party, 4)
		assert(world.is_autosave_blocked())
		assert(world.get_durable_run_state().to_dictionary() == before)
		await _capture(tag + "-failed")
		var overlay: Control = _failure_overlay()
		_click(overlay.get_node("%RetryButton"))
		await process_frame
		await process_frame
		assert(not world.is_autosave_blocked() and not world.has_active_party_management())
		assert(world.get_durable_run_state().to_dictionary() == expected)
		await _capture(tag + "-retry")
		launcher.queue_free()
		await process_frame
		await _launch(repository)
		assert(world.get_durable_run_state().to_dictionary() == expected)
		_click(world.find_child("ManagePartyButton", true, false) as Control)
		await process_frame
		await _capture(tag + "-continued")
		launcher.queue_free()
		await process_frame
		# A separate failed transaction returns to launcher without publishing.
		await _seed_and_launch(repository, replacement, 500)
		await _open()
		await _select()
		party = world.get("_active_party")
		failed = FailingRepository.new()
		failed.inner = repository
		failed.fail_next = true
		world.get("_save_coordinator").set("_repository", failed)
		await _drag_recruit(party, 4)
		assert(world.is_autosave_blocked())
		overlay = _failure_overlay()
		_click(overlay.get_node("%ReturnButton"))
		await process_frame
		await process_frame
		assert(launcher.get_node("%WorldHost").get_child_count() == 0)
		_click(launcher.get_node("%ContinueButton"))
		await process_frame
		await process_frame
		world = launcher.get_node("%WorldHost").get_child(0) as WorldRuntimeController
		assert(world.get_durable_run_state().to_dictionary() == before)
		await _open()
		await _capture(tag + "-discard-continued")
		launcher.queue_free()
		await process_frame
	print("PASS capture_ac8_7_placement width=", width, " actual_continue/offer/drag/escape/cancel/retry/return=true exact_state=true")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit(0)

func _select() -> void:
	_click(_panel().get_node("%Offers/scrapbroker"))
	await process_frame
	await process_frame
	assert(world.has_active_party_management())

func _failure_overlay() -> Control:
	for control: Node in world.find_children("*", "Control", true, false):
		if control is WorldAutosaveFailureOverlay and control.visible:
			return control as Control
	assert(false, "Missing autosave overlay")
	return null

func _seed_and_launch(repository: RefCounted, replacement: bool, gold: int) -> void:
	var session: Dictionary = _fixture(replacement)
	session.run_state.gold = gold
	var bytes: PackedByteArray = load("res://Scripts/Save/world_run_save_codec_v5.gd").encode(session.plan, session.resolved_seed, session.run_state)
	assert(repository.replace_atomic(bytes).ok)
	await _launch(repository)

func _fixture(replacement: bool) -> Dictionary:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass).start("golden-alpha")
	for coord: Vector2i in session.plan.get_cells():
		if session.plan.get_cells()[coord].town_index >= 0 and coord != session.plan.get_boss_coord():
			session.run_state.player_coord = coord
			break
	var ids: Array[StringName] = [&"player_0", &"", &"player_1", &"", &"", &"player_2"]
	if replacement:
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
	assert(decoded.ok)
	session.run_state = decoded.value
	return session

func _drag_recruit(party: PartyManagement, slot_index: int) -> void:
	var source: Vector2 = (party.get_node("%PendingRecruitCard") as Control).get_global_rect().get_center()
	var target: Vector2 = (party.get_node("%%Slot%d" % slot_index) as Control).get_global_rect().get_center()
	_motion(source, Vector2.ZERO, 0)
	_mouse(source, MOUSE_BUTTON_LEFT, true)
	await process_frame
	_motion(source + Vector2(20, 0), Vector2(20, 0), MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_motion(target, target - source - Vector2(20, 0), MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_mouse(target, MOUSE_BUTTON_LEFT, false)
	await process_frame
	await process_frame


func _dialog_click(dialog: Window, button: Control) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = Vector2(dialog.position) + button.get_global_rect().get_center()
		event.global_position = event.position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func _dialog_key(_dialog: Window, code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)

func _launch(repository: RefCounted) -> void:
	launcher = load("res://Scenes/world_run_start.tscn").instantiate()
	launcher.set("_repository", repository)
	root.add_child(launcher)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i.ZERO
	root.size = Vector2i(width, 720 if width == 1280 else 1080)
	await process_frame
	await process_frame
	var continue_button: Button = launcher.get_node("%ContinueButton")
	assert(not continue_button.disabled)
	_click(continue_button)
	await process_frame
	await process_frame
	world = launcher.get_node("%WorldHost").get_child(0) as WorldRuntimeController
	assert(is_instance_valid(world))

func _open() -> void:
	var recruit: Button = world.find_child("RecruitButton", true, false) as Button
	assert(is_instance_valid(recruit) and recruit.visible and not recruit.disabled)
	_click(recruit)
	await process_frame
	await process_frame
	assert(world.has_active_town_recruitment())

func _panel() -> TownRecruitmentPanel:
	for control: Node in world.find_children("*", "Control", true, false):
		if control is TownRecruitmentPanel and control.is_visible_in_tree():
			return control
	assert(false, "Visible town panel missing")
	return null

func _capture(state: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://Docs/Specs/AC8/Evidence/AC8.7/rendered-%s-%d.png" % [state, width]) == OK)

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	_mouse(point, MOUSE_BUTTON_LEFT, true)
	_mouse(point, MOUSE_BUTTON_LEFT, false)

func _mouse(point: Vector2, button: MouseButton, pressed: bool) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = button
	event.pressed = pressed
	root.push_input(event, true)

func _motion(point: Vector2, relative: Vector2, mask: int) -> void:
	var event: InputEventMouseMotion = InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = relative
	event.button_mask = mask
	root.push_input(event, true)

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event: InputEventKey = InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		root.push_input(event, true)
