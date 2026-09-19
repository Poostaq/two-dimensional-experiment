class_name AC81GoldCapture
extends SceneTree

const OUTPUT: String = "res://Docs/Specs/AC8/Evidence/AC8.1"
var _failures: int = 0
var _launcher: Control
var _repository: RefCounted


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed: PackedScene = load("res://Scenes/world_run_start.tscn")
	_launcher = packed.instantiate()
	_repository = load("res://Scripts/Run/world_single_slot_repository.gd").new("user://tests/ac8-1-rendered.json")
	_launcher.set("_repository", _repository)
	root.add_child(_launcher)
	await process_frame
	root.size = Vector2i(1152, 648)
	await _activate(_launcher.get_node("%StartNewRunButton"))
	_launcher.get_node("%SeedInput").text = "ac8-1-rendered"
	await _activate(_launcher.get_node("%BeginButton"))
	if _launcher.get_node("%OverwriteConfirmButton").is_visible_in_tree():
		await _activate(_launcher.get_node("%OverwriteConfirmButton"))
	var host: Node = _launcher.get_node("%WorldHost")
	_expect(host.get_child_count() == 1, "production menu starts one world")
	if host.get_child_count() == 0:
		_finish()
		return
	var world: WorldRuntimeController = host.get_child(0)
	world.get("_save_coordinator").set("_repository", _repository)
	_check(world, 100, "new run")
	await _capture("new-run-1152.png")
	var coords: Array[Vector2i] = world.get_valid_destinations()
	var coord: Vector2i = coords[0]
	var point: Vector2 = world.axial_to_world(coord)
	var camera: Camera2D = world.get_world_camera()
	var screen_point: Vector2 = (point - camera.global_position) * camera.zoom + root.get_visible_rect().size / 2.0
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_LEFT
	pressed.position = screen_point
	pressed.pressed = true
	root.push_input(pressed)
	await process_frame
	pressed = pressed.duplicate()
	pressed.pressed = false
	root.push_input(pressed)
	await process_frame
	_expect(world.get_runtime_snapshot().move_count == 1, "map click accepts one move")
	_check(world, 100, "after map click")
	world.close_active_encounter()
	await process_frame
	world.launcher_return_requested.emit()
	await process_frame
	await _activate(_launcher.get_node("%ContinueButton"))
	world = host.get_child(0)
	world.get("_save_coordinator").set("_repository", _repository)
	_check(world, 100, "Continue after move")
	var codec: GDScript = load("res://Scripts/Save/world_run_save_codec_v3.gd")
	for amount: int in [375, 0]:
		var durable: RefCounted = world.get_durable_run_state()
		durable.gold = amount
		var plan: WorldPlan = world.get("_runtime_plan")
		_expect(_repository.replace_atomic(codec.encode(plan, "ac8-1-rendered", durable)).get("ok", false), "fixture wallet saved")
		world.launcher_return_requested.emit()
		await process_frame
		await _activate(_launcher.get_node("%ContinueButton"))
		world = host.get_child(0)
		world.get("_save_coordinator").set("_repository", _repository)
		_check(world, amount, "Continue fixture")
		await _capture("continued-%dg-1152.png" % amount)
	root.size = Vector2i(1920, 1080)
	await _capture("continued-0g-1920.png")
	world.launcher_return_requested.emit()
	await process_frame
	await _activate(_launcher.get_node("%StartNewRunButton"))
	_launcher.get_node("%SeedInput").text = "ac8-1-replacement"
	await _activate(_launcher.get_node("%BeginButton"))
	await _activate(_launcher.get_node("%OverwriteConfirmButton"))
	world = host.get_child(0)
	_check(world, 100, "replacement run")
	_launcher.free()
	await process_frame
	_finish()


func _activate(button: Button) -> void:
	_expect(button.is_visible_in_tree() and not button.disabled, "button available: " + str(button.name))
	button.grab_focus()
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event)
	await process_frame
	await process_frame


func _check(world: WorldRuntimeController, amount: int, label: String) -> void:
	_expect(world.get_durable_run_state().gold == amount, label + " durable wallet")
	_expect(world.get_node("%WorldMapHud").get_node("%GoldLabel").text == "%dg" % amount, label + " HUD")
	print("STATE ", label, ": ", amount, "g")


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var error: Error = screenshot.save_png(OUTPUT + "/" + filename)
	_expect(error == OK, "capture saved: " + filename)
	print("CAPTURE ", filename)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _finish() -> void:
	if _failures == 0:
		print("PASS capture_ac8_1_gold")
	quit(0 if _failures == 0 else 1)
