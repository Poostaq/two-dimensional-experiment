class_name CaptureAC85TownRecruitment
extends SceneTree

var width: int = 1280
var save_path: String
var launcher: Control
var world: WorldRuntimeController

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--width="):
			width = argument.trim_prefix("--width=").to_int()
	save_path = "user://ac8-5-rendered-%d.json" % width
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass).start("golden-alpha")
	for coord: Vector2i in session.plan.get_cells():
		if session.plan.get_cells()[coord].town_index >= 0 and coord != session.plan.get_boss_coord():
			session.run_state.player_coord = coord
			break
	session.run_state.gold = 500
	var repository: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(save_path)
	var bytes: PackedByteArray = load("res://Scripts/Save/world_run_save_codec_v5.gd").encode(session.plan, session.resolved_seed, session.run_state)
	assert(repository.replace_atomic(bytes).ok)
	await _launch(repository)
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	var initial_bytes: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	await _capture("hud")
	await _open()
	var panel: TownRecruitmentPanel = _panel()
	var card: Control = panel.get_node("Card")
	assert(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(card.get_global_rect()))
	await _capture("rich")
	var camera: Camera2D = world.find_children("*", "Camera2D", true, false)[0]
	var camera_position: Vector2 = camera.position
	var camera_zoom: Vector2 = camera.zoom
	_mouse(Vector2(10, 350), MOUSE_BUTTON_WHEEL_UP, true)
	_key(KEY_RIGHT)
	_mouse(Vector2(10, 350), MOUSE_BUTTON_LEFT, true)
	_motion(Vector2(150, 400), Vector2(140, 50), MOUSE_BUTTON_MASK_LEFT)
	_mouse(Vector2(150, 400), MOUSE_BUTTON_LEFT, false)
	await process_frame
	assert(camera.position == camera_position and camera.zoom == camera_zoom)
	_key(KEY_ESCAPE)
	await process_frame
	assert(not world.has_active_town_recruitment())
	assert(world.get_durable_run_state().to_dictionary() == before)
	await _open()
	panel = _panel()
	_click(panel.get_node("%CloseButton"))
	await process_frame
	assert(not world.has_active_town_recruitment())
	assert(FileAccess.get_file_as_bytes(save_path) == initial_bytes)
	await _open()
	panel = _panel()
	var initial_focus: Control = root.gui_get_focus_owner()
	_key(KEY_TAB)
	await process_frame
	assert(root.gui_get_focus_owner() != initial_focus and panel.is_ancestor_of(root.gui_get_focus_owner()))
	_key(KEY_ENTER)
	await process_frame
	assert(world.has_active_party_management())
	var party: PartyManagement = world.get("_active_party")
	_click(party.get_node("%CancelPlacementButton"))
	await process_frame
	assert(not world.has_active_party_management())
	assert(world.get_durable_run_state().to_dictionary() == before)
	assert(FileAccess.get_file_as_bytes(save_path) == initial_bytes)
	panel = _panel()
	_click(panel.get_node("%Offers").get_node("scrapbroker"))
	await process_frame
	party = world.get("_active_party")
	assert(is_instance_valid(party))
	await _capture("placement")
	var source: Vector2 = (party.get_node("%PendingRecruitCard") as Control).get_global_rect().get_center()
	var target: Vector2 = (party.get_node("%Slot5") as Control).get_global_rect().get_center()
	_motion(source, Vector2.ZERO, 0)
	_mouse(source, MOUSE_BUTTON_LEFT, true)
	await process_frame
	_motion(source + Vector2(24, 0), Vector2(24, 0), MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	_motion(target, target - source - Vector2(24, 0), MOUSE_BUTTON_MASK_LEFT)
	await process_frame
	assert(root.gui_is_dragging())
	_mouse(target, MOUSE_BUTTON_LEFT, false)
	await process_frame
	await process_frame
	var after: Dictionary = world.get_durable_run_state().to_dictionary()
	var expected: Dictionary = before.duplicate(true)
	expected.gold = 0
	expected.formation[5] = "scrapbroker"
	expected.character_hp["scrapbroker"] = RunCharacterCatalog.create_by_class_id(&"scrapbroker").max_hp
	assert(after == expected, "Purchase must alter only gold, slot5, recruit HP")
	assert(not world.has_active_party_management())
	panel = _panel()
	assert(panel.get_node("%WalletLabel").text == "0g")
	assert(not panel.get_node("%Offers").has_node("scrapbroker"))
	for offer: Button in panel.get_node("%Offers").get_children():
		assert(offer.disabled)
	await _capture("poor")
	var purchased_bytes: PackedByteArray = FileAccess.get_file_as_bytes(save_path)
	launcher.queue_free()
	await process_frame
	await _launch(repository)
	assert(world.get_durable_run_state().to_dictionary() == after)
	await _open()
	await _capture("continued")
	# Presentation-only fixture after the real purchase/Continue path.
	var empty_offers: Array[StringName] = []
	_panel().configure(&"goblin", 0, empty_offers)
	await _capture("empty-fixture")
	assert(world.get_durable_run_state().to_dictionary() == after)
	assert(FileAccess.get_file_as_bytes(save_path) == purchased_bytes)
	_key(KEY_ESCAPE)
	await process_frame
	assert(not world.has_active_town_recruitment())
	print("PASS capture_ac8_5_town_recruitment width=", width, " viewport=", root.size, " mouse_continue/recruit/close/cancel/drag=true keyboard_tab/enter/escape=true modal_camera_unchanged=true domain_and_bytes_unchanged_on_cancel=true purchase_only_gold_slot_hp=true continue_no_charge=true")
	launcher.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit(0)

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
	assert(root.get_texture().get_image().save_png("res://Docs/Specs/AC8/Evidence/AC8.5/rendered-%s-%d.png" % [state, width]) == OK)

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
