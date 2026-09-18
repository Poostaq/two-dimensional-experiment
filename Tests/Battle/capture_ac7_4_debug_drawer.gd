class_name CaptureAc7_4DebugDrawer
extends SceneTree

const EVIDENCE: String = "res://Docs/Specs/AC7/Evidence/AC7.4/"
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena := (load("res://Scenes/battle_arena.tscn") as PackedScene).instantiate() as BattleArena
	root.add_child(arena)
	await _settle()
	var drawer := arena.get_node("%BattleDebugDrawer") as Control
	var handle := drawer.get_node("%DebugHandle") as Button
	var close := drawer.get_node("%CloseButton") as Button
	var damage := drawer.get_node("%AdvanceTurnDebugButton") as Button
	var panel := drawer.get_node("%DrawerPanel") as Control
	var bar := arena.get_node("%BattleActionBar") as Control
	for width: int in [1152, 1024]:
		root.content_scale_size = Vector2i(width, 648)
		root.size = Vector2i(width, 648)
		arena.configure_units(arena.call("_create_debug_units"))
		await _settle()
		await _capture(drawer, "drawer-closed-%d.png" % width)
		await _click(bar.get_node("%DefaultAttackButton"))
		var bar_rect: Rect2 = bar.get_global_rect()
		var revision: int = arena.get_battle_revision()
		var transaction: Dictionary = arena.get_skill_presentation_snapshot()
		var mode: int = arena.get("_default_action_mode")
		await _click(handle)
		_expect(drawer.is_open(), "pointer opens")
		_expect(close.has_focus(), "open focuses close")
		_expect(bar.get_global_rect() == bar_rect, "drawer does not move action bar")
		await _capture(drawer, "drawer-open-%d.png" % width)
		# Clicking the opaque panel must not reach a covered battlefield slot.
		var inspected: StringName = arena.get_inspected_unit_id()
		await _click(drawer.get_node("%LiveState"))
		_expect(arena.get_inspected_unit_id() == inspected, "panel blocks unit inspection")
		await _key(KEY_TAB)
		_expect(drawer.is_ancestor_of(root.gui_get_focus_owner()), "Tab remains in drawer")
		await _key(KEY_TAB, true)
		await _key(KEY_ESCAPE)
		_expect(not drawer.is_open(), "Escape closes only drawer")
		_expect(arena.get_battle_revision() == revision and arena.get_skill_presentation_snapshot() == transaction and arena.get("_default_action_mode") == mode, "drawer inputs preserve selected action")
		handle.grab_focus()
		await _key(KEY_ENTER)
		_expect(drawer.is_open(), "Enter opens handle")
		await _click(damage)
		_expect(arena.get_battle_log_entries().size() == 1, "real damage button commits once")
		var rows := drawer.get_node("%BattleLogEntries") as VBoxContainer
		if rows.get_child_count() == 0:
			quit(1)
			return
		var diagnostics := drawer.get_node("DrawerPanel/DrawerContents/DiagnosticsScroll") as ScrollContainer
		diagnostics.ensure_control_visible(drawer.get_node("%BattleLogScroll"))
		await _settle()
		await _move((rows.get_child(0) as Control).get_global_rect().get_center())
		_expect(arena.get("_hovered_log_index") == 0, "real row hover previews history")
		await _click(close)
		_expect(arena.get("_hovered_log_index") == -1, "real close clears preview")
		for index: int in 24:
			drawer.append_log_row({"index": index + 1, "sequence": index + 1,
				"text": "History entry %d — chronological diagnostics remain available while closed." % index, "previewable": false})
		await _click(handle)
		await _settle()
		var scroll := drawer.get_node("%BattleLogScroll") as ScrollContainer
		_expect(scroll.scroll_vertical > 0, "reopen scrolls to newest history")
		await _capture(drawer, "drawer-history-%d.png" % width)
		var before_scroll: int = scroll.scroll_vertical
		var wheel := InputEventMouseButton.new()
		wheel.position = scroll.get_global_rect().get_center()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		root.push_input(wheel)
		await _settle()
		_expect(scroll.scroll_vertical < before_scroll, "history accepts wheel scrolling")
		await _key(KEY_ESCAPE)
		_expect(not panel.visible, "closed panel hidden")
		handle.grab_focus()
		await _key(KEY_TAB)
		_expect(not panel.is_ancestor_of(root.gui_get_focus_owner()), "closed panel excluded from Tab")
		handle.grab_focus()
		await _key(KEY_SPACE)
		_expect(drawer.is_open(), "Space activates handle")
		await _key(KEY_ESCAPE)
		arena.configure_units(arena.call("_create_debug_units"))
		await _settle()
		await _click(bar.get_node("%DefaultAttackButton"))
		drawer.set_open(true)
		await _settle()
		var covered := arena.get_enemy_slots()[4] as Control
		var covered_point: Vector2 = covered.get_global_rect().get_center()
		_expect(panel.get_global_rect().has_point(covered_point), "covered-unit fixture lies under panel")
		var before_target: Dictionary = (arena.get("_default_action_preview") as Dictionary).duplicate(true)
		await _click(covered)
		_expect(arena.get("_default_action_preview") == before_target, "covered unit cannot be targeted")
		drawer.set_open(false)
		await _click(covered)
		_expect((arena.get("_default_action_preview") as Dictionary).get(&"target_id", &"") == covered.get_meta("unit_id"), "same unit can be targeted after close")
	# Blocking preparation owns input and collapses an open drawer.
	arena.configure(Vector2i.ZERO, WorldEncounterType.COMBAT)
	var identity: RefCounted = arena.get_setup_identity()
	var record: RefCounted = load("res://Scripts/Battle/battle_preparation_record.gd").offered(&"drawer_prep", Vector2i.ZERO, WorldEncounterType.COMBAT, String(identity.get("canonical_key")))
	drawer.set_open(true)
	_expect(arena.configure_preparation(record), "preparation accepted")
	await _settle()
	_expect(not drawer.is_open() and not handle.visible, "preparation excludes drawer input")
	await _capture(drawer, "drawer-preparation.png")
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	print("AC7.4 rendered input/layout QA: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

func _capture(drawer: Control, filename: String) -> void:
	await _settle()
	var bounds := Rect2(Vector2.ZERO, Vector2(root.content_scale_size))
	for name: String in ["DebugHandle", "DrawerPanel", "CloseButton", "AdvanceTurnDebugButton", "ExitBattleDebugButton"]:
		var control := drawer.get_node("%" + name) as Control
		if control.is_visible_in_tree():
			_expect(bounds.grow(1).encloses(control.get_global_rect()), filename + " " + name + " fits")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(EVIDENCE + filename) == OK, "saved " + filename)

func _settle() -> void:
	for frame: int in range(4):
		await process_frame


func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion)
	await _settle()


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	await _move(point)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await _settle()


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await _settle()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
