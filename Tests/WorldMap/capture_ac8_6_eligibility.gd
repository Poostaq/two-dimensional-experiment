class_name CaptureAC86Eligibility
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
	save_path = "user://ac8-6-rendered-%d.json" % width
	var repository: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(save_path)
	await _seed_and_launch(repository, RunCharacterCatalog.get_goblin_class_ids())
	var before: Dictionary = world.get_durable_run_state().to_dictionary()
	await _open()
	assert(_panel().get_node("%Offers").get_child_count() == 0)
	assert(_panel().get_node("%EmptyLabel").visible)
	await _capture("empty")
	_key(KEY_ESCAPE)
	await process_frame
	assert(not world.has_active_town_recruitment())
	await _party()
	var party: PartyManagement = world.get("_active_party")
	_click(party.get_node("%Slot3"))
	await process_frame
	assert(party.get_node("%DismissButton").visible)
	await _capture("selected")
	_click(party.get_node("%DismissButton"))
	await process_frame
	var dialog: ConfirmationDialog = party.get_node("%DismissConfirmation")
	assert(dialog.visible and dialog.dialog_text.contains("No gold is refunded."))
	await _capture("confirmation")
	var camera: Camera2D = world.find_children("*", "Camera2D", true, false)[0]
	var camera_position: Vector2 = camera.position
	var camera_zoom: Vector2 = camera.zoom
	_dialog_key(dialog, KEY_ESCAPE)
	await process_frame
	assert(not dialog.visible and world.has_active_party_management())
	assert(world.get_durable_run_state().to_dictionary() == before)
	_click(party.get_node("%DismissButton"))
	await process_frame
	_dialog_click(dialog, dialog.get_ok_button())
	await process_frame
	assert(world.get_durable_run_state().gold == 1500)
	assert(world.get_durable_run_state().formation[3] == &"")
	assert(world.get_valid_destinations().is_empty())
	var dismissed: Dictionary = before.duplicate(true)
	dismissed.formation[3] = ""
	dismissed.character_hp.erase("scrapbroker")
	assert(world.get_durable_run_state().to_dictionary() == dismissed)
	# Keyboard and pointer input while the normal party remains open cannot move the map.
	_key(KEY_RIGHT)
	_mouse(Vector2(10, 350), MOUSE_BUTTON_WHEEL_UP, true)
	await process_frame
	assert(camera.position == camera_position and camera.zoom == camera_zoom)
	_click(party.get_node("%ReturnToMapButton"))
	await process_frame
	await _open()
	assert(world.get_town_recruitment_context().class_ids == [&"scrapbroker"])
	await _capture("returned-offer")
	_click(_panel().get_node("%Offers/scrapbroker"))
	await process_frame
	party = world.get("_active_party")
	await _drag_recruit(party, 3)
	assert(world.get_durable_run_state().gold == 1000)
	assert(world.get_durable_run_state().formation[3] == &"scrapbroker")
	assert(_panel().get_node("%Offers").get_child_count() == 0)
	await _capture("repurchased-empty")
	var purchased: Dictionary = world.get_durable_run_state().to_dictionary()
	launcher.queue_free()
	await process_frame
	await _launch(repository)
	assert(world.get_durable_run_state().to_dictionary() == purchased)
	await _open()
	assert(_panel().get_node("%Offers").get_child_count() == 0)
	await _capture("continued-empty")
	launcher.queue_free()
	await process_frame
	# Full roster with duplicate canonical class leaves Scrapbroker eligible.
	await _seed_and_launch(repository, [&"scrapshield_bruiser", &"wirefang_skirmisher", &"snarewright", &"shivrunner", &"mobcaller", &"player_0"])
	await _open()
	_click(_panel().get_node("%Offers/scrapbroker"))
	await process_frame
	party = world.get("_active_party")
	await _drag_recruit(party, 1)
	assert(world.get_durable_run_state().gold == 1000)
	assert(world.get_town_recruitment_context().class_ids == [&"wirefang_skirmisher"])
	await _capture("replacement")
	launcher.queue_free()
	await process_frame
	await _seed_and_launch(repository, [&"snarewright"])
	await _party()
	party = world.get("_active_party")
	_click(party.get_node("%Slot0"))
	await process_frame
	var dismiss_button: Button = party.get_node("%DismissButton")
	assert(dismiss_button.disabled)
	await _capture("last-member")
	print("PASS capture_ac8_6_eligibility width=", width, " actual_continue/click/drag/dialog_escape=true empty/dismiss/repurchase/replacement/reload/D1=true camera_unchanged=true")
	launcher.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit(0)

func _seed_and_launch(repository: RefCounted, ids: Array[StringName]) -> void:
	var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass).start("golden-alpha")
	for coord: Vector2i in session.plan.get_cells():
		if session.plan.get_cells()[coord].town_index >= 0 and coord != session.plan.get_boss_coord():
			session.run_state.player_coord = coord
			break
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
	assert(decoded.ok)
	session.run_state = decoded.value
	var bytes: PackedByteArray = load("res://Scripts/Save/world_run_save_codec_v5.gd").encode(session.plan, session.resolved_seed, session.run_state)
	assert(repository.replace_atomic(bytes).ok)
	await _launch(repository)

func _party() -> void:
	_click(world.find_child("ManagePartyButton", true, false) as Control)
	await process_frame
	await process_frame
	assert(world.has_active_party_management())

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
	assert(not world.has_active_party_management())

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
	assert(root.get_texture().get_image().save_png("res://Docs/Specs/AC8/Evidence/AC8.6/rendered-%s-%d.png" % [state, width]) == OK)

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
