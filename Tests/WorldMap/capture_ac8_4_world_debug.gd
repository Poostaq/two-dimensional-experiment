class_name CaptureAC84WorldDebug
extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var width: int = 1280
    for argument: String in OS.get_cmdline_user_args():
        if argument.begins_with("--width="):
            width = argument.trim_prefix("--width=").to_int()
    var height: int = 720 if width == 1280 else 1080
    root.mode = Window.MODE_WINDOWED
    root.content_scale_size = Vector2i.ZERO
    root.size = Vector2i(width, height)
    var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass)
    var session: Dictionary = service.start("world-debug-qa")
    var world: Node = load("res://Scenes/world_map_runtime.tscn").instantiate()
    world.auto_initialize_runtime = false
    root.add_child(world)
    await process_frame
    var repository: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new("user://ac8-expansion-capture-%d.json" % width)
    assert(world.apply_session(session, repository))
    await process_frame
    var drawer: Control = world.get_node("UI/WorldDebugDrawer")
    var handle: Button = drawer.get_node("%DebugHandle")
    var before: String = world.get_durable_run_state().canonical_key()
    _click(handle.get_global_rect().get_center())
    await process_frame
    assert(drawer.is_open())
    await RenderingServer.frame_post_draw
    var directory: String = "res://Docs/Specs/AC8/Evidence/AC8.4-expansion/"
    root.get_texture().get_image().save_png(directory + "drawer-%d.png" % width)
    var data: Dictionary = world.get_debug_snapshot()
    data.seed = "long-seed-validation-" + "0123456789abcdef".repeat(24)
    drawer.render(data)
    await process_frame
    var scroll: ScrollContainer = drawer.get_node("%DiagnosticsScroll")
    scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)
    await process_frame
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(directory + "drawer-scroll-%d.png" % width)
    var panel: Control = drawer.get_node("%DrawerPanel")
    assert(panel.get_global_rect().position.x >= 0 and panel.get_global_rect().end.x <= width)
    assert(panel.get_global_rect().position.y >= 0 and panel.get_global_rect().end.y <= height)
    var close: Button = drawer.get_node("%CloseButton")
    _click(close.get_global_rect().get_center())
    await process_frame
    assert(not drawer.is_open())
    assert(world.get_durable_run_state().canonical_key() == before)
    await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(directory + "hud-%d.png" % width)
    print("PASS capture_ac8_4_world_debug width=", width, " viewport=", root.size, " panel=", panel.get_global_rect())
    world.queue_free()
    await process_frame
    quit(0)

func _click(position: Vector2) -> void:
    for pressed: bool in [true, false]:
        var event: InputEventMouseButton = InputEventMouseButton.new()
        event.position = position
        event.global_position = position
        event.button_index = MOUSE_BUTTON_LEFT
        event.pressed = pressed
        root.push_input(event, true)
