class_name WorldDebugDrawerTests
extends SceneTree

var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var scene_path: String = "res://Scenes/UI/world_debug_drawer.tscn"
    if not ResourceLoader.exists(scene_path):
        _expect(false, "world debug drawer scene exists")
        quit(1)
        return
    root.size = Vector2i(1280, 720)
    var host: Control = Control.new()
    root.add_child(host)
    host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var previous: Button = Button.new()
    previous.text = "Previous"
    host.add_child(previous)
    var drawer: Control = load(scene_path).instantiate()
    host.add_child(drawer)
    await process_frame
    _expect(not drawer.is_open(), "drawer starts collapsed")
    var panel: Control = drawer.get_node("%DrawerPanel")
    var handle: Button = drawer.get_node("%DebugHandle")
    _expect(panel.mouse_filter == Control.MOUSE_FILTER_STOP, "panel stops pointer input")
    _expect(not panel.mouse_force_pass_scroll_events, "panel stops wheel propagation")
    var view: Dictionary = {"coord": Vector2i(-8, 0), "terrain": "forest",
        "habitat": {"ok": true, "display_name": "Goblin", "clan_id": &"goblin",
        "source": "Legacy world v1 rule", "habitat_id": &"", "error": &""},
        "seed": "long-seed-".repeat(60)}
    var original: Dictionary = view.duplicate(true)
    drawer.render(view)
    previous.grab_focus()
    drawer.set_open(true)
    await process_frame
    _expect(drawer.is_open(), "drawer opens")
    _expect(root.gui_get_focus_owner() == drawer.get_node("%CloseButton"), "close receives focus")
    _expect(panel.get_global_rect().end.x <= 1280 and panel.get_global_rect().position.x >= 0, "panel within viewport")
    _expect(drawer.get_node("%HabitatDetails").text.contains("Goblin"), "habitat displayed")
    _expect(drawer.get_node("%MapDetails").text.contains(view.seed), "full seed preserved")
    view.seed = "mutated"
    _expect(not drawer.get_node("%MapDetails").text.contains("mutated"), "view detached")
    _key(KEY_TAB)
    await process_frame
    _expect(drawer.is_ancestor_of(root.gui_get_focus_owner()), "tab stays in drawer")
    _key(KEY_TAB, true)
    await process_frame
    _expect(drawer.is_ancestor_of(root.gui_get_focus_owner()), "shift-tab stays in drawer")
    handle.grab_focus()
    var repeated: InputEventKey = InputEventKey.new()
    repeated.keycode = KEY_TAB
    repeated.pressed = true
    repeated.echo = true
    for iteration: int in range(12):
        root.push_input(repeated)
        await process_frame
        _expect(drawer.is_ancestor_of(root.gui_get_focus_owner()), "repeated tab stays in drawer %d" % iteration)
    _key(KEY_ESCAPE)
    await process_frame
    _expect(not drawer.is_open(), "escape closes")
    _expect(root.gui_get_focus_owner() == previous, "focus restored")
    drawer.set_open(true)
    drawer.set_available(false)
    _expect(not drawer.is_open() and not handle.visible, "modal disables and closes drawer")
    drawer.set_open(true)
    _expect(not drawer.is_open(), "disabled drawer cannot open")
    drawer.set_available(true)
    _expect(handle.visible, "handle returns")
    drawer.set_open(true)
    drawer.reset_view()
    _expect(not drawer.is_open(), "reset closes")
    _expect(drawer.get_node("%RunDetails").text.is_empty(), "reset clears stale data")
    _expect(original.coord == Vector2i(-8, 0), "diagnostics do not change input")
    host.queue_free()
    await process_frame
    if failures == 0:
        print("PASS test_world_debug_drawer")
    quit(0 if failures == 0 else 1)

func _key(code: Key, shift: bool = false) -> void:
    var event: InputEventKey = InputEventKey.new()
    event.keycode = code
    event.pressed = true
    event.shift_pressed = shift
    root.push_input(event)

func _expect(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error(label)
