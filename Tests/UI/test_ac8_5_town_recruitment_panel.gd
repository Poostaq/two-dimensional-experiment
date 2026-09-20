class_name TownRecruitmentPanelTests
extends SceneTree

class InputProbe extends Node:
	var events: int = 0
	func _unhandled_input(_event: InputEvent) -> void:
		events += 1

var failures: Array[String] = []
var assertions: int = 0
var requests: Array[StringName] = []
var closes: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path: String = "res://Scenes/UI/town_recruitment_panel.tscn"
	_expect(ResourceLoader.exists(path), "recruitment scene exists")
	if not ResourceLoader.exists(path):
		_finish()
		return
	var probe: InputProbe = InputProbe.new()
	root.add_child(probe)
	var panel: Control = load(path).instantiate()
	root.add_child(panel)
	await process_frame
	panel.connect("recruit_requested", func(id: StringName) -> void: requests.append(id))
	panel.connect("close_requested", func() -> void: closes += 1)
	var ids: Array[StringName] = [&"scrapshield_bruiser", &"wirefang_skirmisher"]
	panel.call("configure", &"goblin", 499, ids)
	await process_frame
	var offers: VBoxContainer = panel.get_node("%Offers")
	_expect(offers.get_child_count() == 2, "one offer per class")
	var first: Button = offers.get_child(0)
	_expect(first.disabled, "499g cannot recruit")
	_expect(first.text.contains("Requires 500g"), "poor offer explains exact cost")
	_expect(first.text.contains(RunCharacterCatalog.create_by_class_id(ids[0]).display_name), "catalog display name")
	_expect((panel.get_node("%WalletLabel") as Label).text == "499g", "exact wallet")
	first.pressed.emit()
	_expect(requests.is_empty(), "disabled request guarded")
	panel.call("configure", &"goblin", 500, ids)
	panel.call("configure", &"goblin", 500, ids)
	await process_frame
	first = offers.get_child(0)
	_expect(not first.disabled, "500g can recruit")
	_expect(first.text.ends_with("500g"), "exact price")
	first.pressed.emit()
	_expect(requests == [ids[0]], "refresh emits exactly one request")
	_expect((panel.get_node("%TitleLabel") as Label).text == "Goblin Recruitment", "clan title")
	var probe_start: int = probe.events
	for key: Key in [KEY_F1, KEY_M, KEY_LEFT, KEY_TAB]:
		var input: InputEventKey = InputEventKey.new()
		input.keycode = key
		input.pressed = true
		Input.parse_input_event(input)
		await process_frame
	for location: Vector2 in [Vector2(8, 8), (offers as Control).global_position + Vector2(8, 8)]:
		var wheel: InputEventMouseButton = InputEventMouseButton.new()
		wheel.position = location
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		Input.parse_input_event(wheel)
		await process_frame
	for location: Vector2 in [Vector2(8, 8), (panel.get_node("%TitleLabel") as Control).global_position + Vector2(8, 8)]:
		for pressed: bool in [true, false]:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.position = location
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			Input.parse_input_event(click)
			await process_frame
	_expect(probe.events == probe_start, "modal blocks keyboard, wheel and click propagation")
	var close: Button = panel.get_node("%CloseButton")
	close.pressed.emit()
	_expect(closes == 1, "close request exactly once")
	_expect(panel.visible, "close leaves domain and visibility to controller")
	panel.hide()
	panel.show()
	await process_frame
	await process_frame
	_expect(panel.is_ancestor_of(root.gui_get_focus_owner()), "show reacquires modal focus")
	var tab: InputEventKey = InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	for index: int in 8:
		panel.call("_input", tab)
	_expect(panel.is_ancestor_of(root.gui_get_focus_owner()), "tab stays inside modal")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	panel.call("_input", escape)
	_expect(closes == 2, "Escape requests close")
	panel.hide()
	panel.call("_input", escape)
	_expect(closes == 2, "hidden panel ignores input")
	var hidden_key: InputEventKey = InputEventKey.new()
	hidden_key.keycode = KEY_F1
	hidden_key.pressed = true
	Input.parse_input_event(hidden_key)
	await process_frame
	_expect(probe.events > probe_start, "hidden panel releases world keyboard input")
	panel.show()
	var empty: Array[StringName] = []
	panel.call("configure", &"unknown", 0, empty)
	await process_frame
	_expect(offers.get_child_count() == 0, "refresh removes stale offers")
	_expect((panel.get_node("%EmptyLabel") as Label).text == "No eligible recruits available.", "exact empty message")
	_expect((panel.get_node("%EmptyLabel") as Label).visible, "empty state visible")
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var card: Control = panel.get_node("Card")
		_expect(panel.get_global_rect().encloses(card.get_global_rect()), "card fits %s" % viewport_size)
	_expect(close.focus_next == close.get_path_to(close), "empty modal focus loops on close")
	panel.queue_free()
	probe.queue_free()
	var hud: Control = load("res://Scenes/world_map_hud.tscn").instantiate()
	root.add_child(hud)
	await process_frame
	_expect(hud.has_method("set_recruitment_available"), "HUD recruitment API")
	if hud.has_method("set_recruitment_available"):
		var recruit: Button = hud.get_node("%RecruitButton")
		var hud_requests: Array[int] = []
		hud.connect("recruit_requested", func() -> void: hud_requests.append(1))
		hud.call("set_recruitment_available", false)
		recruit.pressed.emit()
		_expect(not recruit.visible and recruit.disabled and hud_requests.is_empty(), "unavailable HUD recruit hidden and guarded")
		hud.call("set_recruitment_available", true)
		recruit.pressed.emit()
		_expect(recruit.visible and not recruit.disabled and hud_requests.size() == 1, "available HUD recruit emits")
	hud.queue_free()
	await process_frame
	var world: Node = load("res://Scenes/world_map_runtime.tscn").instantiate()
	var world_ui: CanvasLayer = world.get_node("UI")
	world.remove_child(world_ui)
	world.free()
	root.add_child(world_ui)
	await process_frame
	var world_hud: Control = world_ui.get_node("WorldMapHud")
	world_hud.call("set_recruitment_available", true)
	var world_recruit: Button = world_hud.get_node("%RecruitButton")
	var minimap: Control = world_ui.get_node("WorldMinimap")
	var debug_handle: Control = world_ui.get_node("WorldDebugDrawer/DebugHandle")
	for viewport_size: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = viewport_size
		await process_frame
		await process_frame
		var recruit_rect: Rect2 = world_recruit.get_global_rect()
		_expect(world_recruit.is_visible_in_tree(), "world Recruit visible at %s" % viewport_size)
		_expect(not recruit_rect.intersects(minimap.get_global_rect()), "Recruit does not overlap world minimap at %s" % viewport_size)
		_expect(not recruit_rect.intersects(debug_handle.get_global_rect()), "Recruit does not overlap debug handle at %s" % viewport_size)
		_expect(world_hud.get_global_rect().encloses(recruit_rect), "world Recruit fits viewport at %s" % viewport_size)
	world_ui.queue_free()
	await process_frame
	_finish()

func _expect(condition: bool, message: String) -> void:
	assertions += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure: String in failures:
		push_error(failure)
	print("AC8.5 recruitment UI: %s (%d assertions)" % ["PASS" if failures.is_empty() else "FAIL", assertions])
	quit(0 if failures.is_empty() else 1)
