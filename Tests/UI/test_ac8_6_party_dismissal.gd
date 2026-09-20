class_name Ac8_6PartyDismissalTests
extends SceneTree

class MapInputProbe:
	extends Node
	var keys: int = 0
	var wheels: int = 0

	func _unhandled_key_input(_event: InputEvent) -> void:
		keys += 1

	func _input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheels += 1


var _failures: Array[String] = []
var _events: Array[Array] = []
var _closed: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var probe: MapInputProbe = MapInputProbe.new()
	root.add_child(probe)
	var party: Control = (load("res://Scenes/party_management.tscn") as PackedScene).instantiate()
	root.add_child(party)
	await process_frame
	_expect(party.has_method("request_dismissal"), "dismissal API exists")
	if not party.has_method("request_dismissal"):
		party.queue_free()
		await process_frame
		_finish()
		return
	party.connect("dismissal_requested", _on_dismissal)
	party.connect("close_requested", func() -> void: _closed += 1)
	var slots: Array[RunCharacter] = []
	slots.resize(6)
	var starters: Array[RunCharacter] = RunCharacterCatalog.create_starters()
	slots[0] = starters[0]
	slots[2] = starters[1]
	var first: StringName = slots[0].character_id
	var second: StringName = slots[2].character_id
	var dialog: ConfirmationDialog = party.get_node("%DismissConfirmation")
	var button: Button = party.get_node("%DismissButton")
	party.call("configure_normal", slots)
	_expect(button.disabled and party.call("is_normal_mode"), "no selection is disabled in normal mode")
	party.call("select_character", 0, first)
	_expect(not button.disabled, "selected member can be dismissed")
	var right: InputEventKey = InputEventKey.new()
	right.keycode = KEY_RIGHT
	right.pressed = true
	root.push_input(right)
	var wheel: InputEventMouseButton = InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(12, 12)
	root.push_input(wheel)
	_expect(probe.keys == 0, "party blocks map unhandled key stage")
	_expect(probe.wheels == 0, "party blocks map wheel input stage")
	button.grab_focus()
	var accept: InputEventKey = InputEventKey.new()
	accept.keycode = KEY_ENTER
	accept.pressed = true
	root.push_input(accept)
	accept.pressed = false
	root.push_input(accept)
	_expect(dialog.visible, "keyboard still activates focused Dismiss")
	party.call("clear_dismissal_confirmation")
	button.pressed.emit()
	_expect(dialog.visible and dialog.dialog_text == "Dismiss %s? No gold is refunded." % slots[0].display_name, "button opens exact confirmation")
	dialog.canceled.emit()
	dialog.confirmed.emit()
	_expect(not dialog.visible and _events.is_empty(), "cancel invalidates confirmation")
	party.call("request_dismissal", 0, first)
	party.call("select_character", 2, second)
	dialog.confirmed.emit()
	dialog.confirmed.emit()
	_expect(_events == [[0, first]], "confirm emits captured identity once despite new selection")
	_expect(slots[0] == starters[0], "UI emits intent without mutating slots")
	party.call("request_dismissal", 0, first)
	starters[0].character_id = &"changed_after_prompt"
	dialog.confirmed.emit()
	_expect(_events.size() == 1 and not dialog.visible, "confirmation revalidates captured target identity")
	starters[0].character_id = first
	party.call("request_dismissal", 0, first)
	dialog.close_requested.emit()
	dialog.confirmed.emit()
	_expect(_events.size() == 1 and not dialog.visible, "window close invalidates")
	party.call("request_dismissal", 0, first)
	party.call("configure_normal", slots)
	dialog.confirmed.emit()
	_expect(_events.size() == 1 and not dialog.visible, "reconfigure invalidates")
	party.call("request_dismissal", 0, first)
	slots[1] = slots[0]
	slots[0] = null
	party.call("refresh_slots", slots)
	dialog.confirmed.emit()
	_expect(_events.size() == 1 and not dialog.visible, "refresh and moved target invalidate")
	party.call("request_dismissal", 0, first)
	party.call("request_dismissal", -1, first)
	party.call("request_dismissal", 1, second)
	_expect(not dialog.visible, "invalid slot and mismatched identity rejected")
	party.call("request_dismissal", 1, first)
	party.call("request_close")
	dialog.confirmed.emit()
	_expect(_closed == 1 and _events.size() == 1 and not dialog.visible, "party close invalidates")
	for method: String in ["configure_placement", "configure_replacement"]:
		party.call("configure_normal", slots)
		party.call("request_dismissal", 1, first)
		party.call(method, slots, starters[2])
		party.call("request_dismissal", 1, first)
		dialog.confirmed.emit()
		_expect(not party.call("is_normal_mode") and not button.visible and not dialog.visible and _events.size() == 1, method + " rejects dismissal")
	party.call("configure_normal", slots)
	party.call("request_dismissal", 1, first)
	await process_frame
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	dialog.window_input.emit(escape)
	await process_frame
	_expect(not dialog.visible and _closed == 1, "window Escape handler cancels without closing party")
	dialog.confirmed.emit()
	_expect(_events.size() == 1, "Escape invalidates pending identity")
	party.call("request_dismissal", 1, first)
	await process_frame
	dialog.get_ok_button().grab_focus()
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	dialog.push_input(enter)
	enter.pressed = false
	dialog.push_input(enter)
	await process_frame
	_expect(not dialog.visible and _events == [[0, first], [1, first]] and _closed == 1, "actual Enter confirms exactly once without party close")
	root.push_input(escape)
	await process_frame
	_expect(_closed == 2, "normal party Escape closes party")
	slots[2] = null
	party.call("configure_normal", slots)
	party.call("select_character", 1, first)
	party.call("request_dismissal", 1, first)
	_expect(button.disabled and button.tooltip_text == "Keep at least one party member." and not dialog.visible, "last-member guard explains restriction")
	party.queue_free()
	probe.queue_free()
	await process_frame
	_finish()

func _on_dismissal(slot_index: int, character_id: StringName) -> void:
	_events.append([slot_index, character_id])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _finish() -> void:
	if _failures.is_empty():
		print("AC8.6 dismissal UI: PASS")
		quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		quit(1)
