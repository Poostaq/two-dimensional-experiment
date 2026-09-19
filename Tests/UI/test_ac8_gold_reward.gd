class_name Ac83GoldRewardTests
extends SceneTree
var failures: int = 0
var requests: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var path: String = "res://Scenes/UI/battle_gold_reward_panel.tscn"
	_expect(ResourceLoader.exists(path), "gold panel scene exists")
	if failures > 0:
		quit(1)
		return
	var panel: Control = load(path).instantiate()
	root.add_child(panel)
	await process_frame
	panel.acknowledgement_requested.connect(func(id: String) -> void: requests.append(id))
	_expect(not panel.visible, "initially hidden")
	for amount: int in [0, 50, 150, 9007199254740991]:
		panel.present("battle-a", amount)
		_expect(panel.get_node("%AmountLabel").text == "Gold received: %dg" % amount, "exact receipt amount")
		_expect(panel.get_node("%MoneyIcon").texture != null, "money texture authored")
	panel.set_saving(true)
	panel.call("_on_continue_pressed")
	_expect(requests.is_empty(), "save blocks Continue")
	panel.set_saving(false)
	panel.get_node("%ContinueButton").pressed.emit()
	panel.get_node("%ContinueButton").pressed.emit()
	_expect(requests == ["battle-a"], "one request per presentation")
	_expect(panel.visible, "intent does not dismiss")
	panel.present("battle-b", 50)
	_expect(not panel.get_node("%ContinueButton").disabled, "next presentation resets latch")
	_expect(panel.get_node("%ContinueButton").has_focus(), "Continue keyboard focus")
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame
	_expect(requests == ["battle-a", "battle-b"], "keyboard submits")
	panel.present("battle-c", 150)
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	_expect(panel.visible and requests.size() == 2, "Escape cannot dismiss")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(4, 4)
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	_expect(panel.visible and requests.size() == 2, "outside click cannot dismiss")
	for attempt: int in 2:
		click = InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = panel.get_node("%ContinueButton").get_global_rect().get_center()
		click.global_position = click.position
		click.pressed = true
		root.push_input(click)
		click = click.duplicate()
		click.pressed = false
		root.push_input(click)
		await process_frame
	_expect(requests == ["battle-a", "battle-b", "battle-c"], "repeated pointer clicks submit once")
	panel.dismiss()
	_expect(not panel.visible, "controller dismissal hides panel")
	panel.free()
	if failures == 0:
		print("PASS test_ac8_gold_reward")
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
