class_name AC84WorldDebugIntegrationTests
extends SceneTree

var _failures: int = 0

class MemoryRepository:
    extends RefCounted
    var bytes: PackedByteArray
    var fail_next: bool = false
    var writes: int = 0

    func replace_atomic(candidate: PackedByteArray) -> Dictionary:
        writes += 1
        if fail_next:
            fail_next = false
            return {"ok": false, "error": null}
        bytes = candidate.duplicate()
        return {"ok": true, "error": null}

    func load_validated() -> Dictionary:
        return load("res://Scripts/Save/world_run_save_codec_v5.gd").decode_any(bytes)

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://Scenes/world_map_runtime.tscn")
    var probe: Node = packed.instantiate()
    var supported: bool = probe.has_method("get_debug_snapshot")
    probe.free()
    if not supported:
        _expect(false, "controller exposes get_debug_snapshot")
        _finish()
        return
    var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(
        func(_plan: RefCounted) -> void: pass)
    var session: Dictionary = service.start("golden-alpha")
    _expect(session.get("ok", false), "new session starts")
    if not session.get("ok", false):
        _finish()
        return
    var repository: MemoryRepository = MemoryRepository.new()
    var world: WorldRuntimeController = await _open(session, repository)
    if not is_instance_valid(world):
        _finish()
        return
    var drawer: Control = world.get_node_or_null("UI/WorldDebugDrawer")
    _expect(is_instance_valid(drawer), "world contains diagnostics drawer")
    if not is_instance_valid(drawer):
        world.free()
        _finish()
        return
    var handle: Button = drawer.get_node("%DebugHandle")
    await _check_viewport_input(world, drawer, repository)
    var initial: Dictionary = world.call("get_debug_snapshot")
    var start: Vector2i = session.plan.get_start_coord()
    _expect(initial.get("coord") == start and initial.get("player_coord") == start,
        "fresh diagnostics describe current coordinate")
    _expect(initial.get("gold") == 100 and initial.get("move_count") == 0,
        "fresh diagnostics describe durable balance and moves")
    _expect(initial.get("session_applied") == true, "session state exposed")
    var fields: Array[String] = ["coord", "habitat", "ownership", "terrain", "base_encounter",
        "effective_encounter", "consumed", "town_index", "seed", "version", "player_coord",
        "boss_coord", "move_count", "boss_active", "boss_engaged", "boss_defeated", "run_status",
        "gold", "session_applied", "input_blocked", "active_encounter", "active_battle",
        "active_party", "autosave_blocked", "integration_failed", "pending_reward_battle_id",
        "preparation_state", "cache_progress", "cache_ready", "neighbors", "destinations",
        "road_links", "forest_clusters"]
    for field: String in fields:
        _expect(initial.has(field), "snapshot includes " + field)
    _check_habitat(world)
    _expect(not drawer.call("is_open") and handle.visible, "fresh drawer collapsed and available")
    var state_before: Dictionary = world.get_durable_run_state().to_dictionary()
    var bytes_before: PackedByteArray = load("res://Scripts/WorldMap/world_plan_codec_v1.gd").serialize(session.plan)
    var writes_before: int = repository.writes
    drawer.call("set_open", true)
    _expect(drawer.call("is_open"), "drawer opens")
    var destinations: Array[Vector2i] = world.get_valid_destinations()
    _expect(not destinations.is_empty(), "fresh movement available")
    if destinations.is_empty():
        world.free()
        _finish()
        return
    var destination: Vector2i = destinations[0]
    world.call("_on_runtime_cell_inspected", destination)
    _expect(world.call("get_debug_snapshot").coord == start, "hover does not replace current hex")
    _check_habitat(world)
    var detached: Dictionary = world.call("get_debug_snapshot")
    detached.habitat.clan_id = &"changed"
    detached.neighbors.clear()
    detached.destinations.clear()
    detached.road_links.clear()
    detached.forest_clusters.clear()
    var fresh: Dictionary = world.call("get_debug_snapshot")
    _expect(fresh.habitat.clan_id == &"goblin", "nested habitat snapshot is detached")
    for field: String in ["neighbors", "destinations", "road_links", "forest_clusters"]:
        _expect(fresh[field] == initial[field], "snapshot collection detached: " + field)
    drawer.call("set_open", false)
    _expect(world.get_durable_run_state().to_dictionary() == state_before,
        "queries and drawer toggles preserve durable state")
    _expect(repository.writes == writes_before, "queries and drawer toggles do not write")
    _expect(load("res://Scripts/WorldMap/world_plan_codec_v1.gd").serialize(session.plan) == bytes_before,
        "queries preserve canonical plan bytes")
    var rejected: WorldMoveResult = world.request_move(Vector2i(999, 999))
    _expect(is_instance_valid(rejected) and not rejected.is_accepted(), "off-map movement rejects")
    _expect(world.call("get_debug_snapshot").coord == start and repository.writes == writes_before,
        "rejected move preserves diagnostics and writes")
    drawer.call("set_open", true)
    repository.fail_next = true
    world.request_move(destination)
    _expect(world.is_autosave_blocked(), "failed-save movement blocks")
    var failed: Dictionary = world.call("get_debug_snapshot")
    _expect(failed.coord == start and failed.player_coord == start and failed.move_count == 0,
        "failed save retains published current hex")
    _expect(failed.autosave_blocked and not drawer.call("is_open") and not handle.visible,
        "autosave failure closes and hides diagnostics")
    _check_habitat(world)
    _expect(world.retry_autosave().get("ok", false), "failed move retry succeeds")
    var moved: Dictionary = world.call("get_debug_snapshot")
    _expect(moved.coord == destination and moved.player_coord == destination and moved.move_count == 1,
        "retry publishes new current hex")
    _expect(world.has_active_encounter() and moved.active_encounter, "retry opens encounter modal")
    _expect(not handle.visible and not drawer.call("is_open"), "encounter hides diagnostics handle")
    world.close_active_encounter()
    await process_frame
    _expect(not world.has_active_encounter() and handle.visible, "encounter close restores handle")
    _check_habitat(world)
    drawer.call("set_open", true)
    world.open_party_management()
    _expect(world.has_active_party_management(), "party modal opens")
    _expect(world.call("get_debug_snapshot").active_party and not handle.visible and not drawer.call("is_open"),
        "party modal hides and closes diagnostics")
    world.call("_on_party_close_requested")
    await process_frame
    _expect(not world.has_active_party_management() and handle.visible, "party close restores handle")
    var loaded: Dictionary = repository.load_validated()
    _expect(loaded.get("ok", false), "saved session decodes")
    if loaded.get("ok", false):
        var durable_before_reload: Dictionary = world.get_durable_run_state().to_dictionary()
        world.free()
        await process_frame
        world = await _open(loaded.value, repository)
        if is_instance_valid(world):
            drawer = world.get_node("UI/WorldDebugDrawer")
            handle = drawer.get_node("%DebugHandle")
            var restored: Dictionary = world.call("get_debug_snapshot")
            _expect(restored.coord == destination and restored.move_count == 1,
                "serialized reload restores current hex diagnostics")
            _expect(world.get_durable_run_state().to_dictionary() == durable_before_reload,
                "reload diagnostics preserve durable run state")
            _check_habitat(world)
            _expect(not drawer.call("is_open"), "reload starts collapsed")
            drawer.call("set_open", true)
            _expect(drawer.call("is_open"), "reloaded drawer opens")
            _expect(world.apply_session(loaded.value, repository), "session reapply succeeds")
            _expect(not drawer.call("is_open") and handle.visible, "session reapply resets drawer")
    if is_instance_valid(world):
        world.free()
    await process_frame
    await _check_data_fixtures(session)
    _finish()

func _open(session: Dictionary, repository: MemoryRepository) -> WorldRuntimeController:
    var packed: PackedScene = load("res://Scenes/world_map_runtime.tscn")
    var world: WorldRuntimeController = packed.instantiate() as WorldRuntimeController
    world.auto_initialize_runtime = false
    root.add_child(world)
    await process_frame
    var applied: bool = world.apply_session(session, repository)
    _expect(applied, "session applies")
    if not applied:
        world.free()
        return null
    return world

func _check_habitat(world: WorldRuntimeController) -> void:
    var snapshot: Dictionary = world.call("get_debug_snapshot")
    _expect(snapshot.get("habitat", {}).get("clan_id") == &"goblin",
        "current coordinate reports Goblin habitat")
    var hud: Node = world.get_node("%WorldMapHud")
    var label: Label = hud.get_node_or_null("%HabitatLabel")
    _expect(is_instance_valid(label) and label.text == "Habitat: Goblin",
        "HUD exposes current Goblin habitat")

func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)

func _finish() -> void:
    if _failures == 0:
        print("PASS test_ac8_4_world_debug_integration")
    quit(0 if _failures == 0 else 1)

func _check_viewport_input(world: WorldRuntimeController, drawer: Control, repository: MemoryRepository) -> void:
    root.size = Vector2i(1280, 720)
    await process_frame
    await process_frame
    var camera: Camera2D = world.get_viewport().get_camera_2d()
    _expect(is_instance_valid(camera), "viewport has world camera")
    if not is_instance_valid(camera):
        return
    var before: Dictionary = world.get_durable_run_state().to_dictionary()
    var writes: int = repository.writes
    var camera_position: Vector2 = camera.position
    var camera_zoom: Vector2 = camera.zoom
    var handle: Control = drawer.get_node("%DebugHandle")
    _mouse_button(handle.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
    await process_frame
    _expect(drawer.call("is_open"), "viewport click opens drawer handle")
    var panel: Control = drawer.get_node("%DrawerPanel")
    var point: Vector2 = panel.get_global_rect().get_center()
    _mouse_button(point, MOUSE_BUTTON_LEFT)
    _mouse_button(point, MOUSE_BUTTON_WHEEL_DOWN)
    await process_frame
    _expect(camera.position.is_equal_approx(camera_position) and camera.zoom.is_equal_approx(camera_zoom),
        "drawer click and wheel do not pan or zoom map")
    _expect(world.get_durable_run_state().to_dictionary() == before and repository.writes == writes,
        "drawer input never moves player or writes durable state")
    var close: Control = drawer.get_node("%CloseButton")
    _mouse_button(close.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
    await process_frame
    _expect(not drawer.call("is_open"), "viewport close button hit closes drawer")
    _mouse_button(handle.get_global_rect().get_center(), MOUSE_BUTTON_LEFT)
    await process_frame
    var key: InputEventKey = InputEventKey.new()
    key.keycode = KEY_TAB
    key.pressed = true
    root.push_input(key, true)
    _expect(drawer.is_ancestor_of(root.gui_get_focus_owner()), "Tab focus remains in drawer")
    key = InputEventKey.new()
    key.keycode = KEY_ESCAPE
    key.pressed = true
    root.push_input(key, true)
    await process_frame
    _expect(not drawer.call("is_open"), "viewport Escape closes drawer")
    drawer.call("set_open", true)
    await process_frame
    var map_point: Vector2 = Vector2(300, 350)
    var press: InputEventMouseButton = InputEventMouseButton.new()
    press.position = map_point
    press.global_position = map_point
    press.button_index = MOUSE_BUTTON_LEFT
    press.pressed = true
    root.push_input(press, true)
    _expect(camera.call("is_dragging"), "map press starts camera drag")
    var into_panel: InputEventMouseMotion = InputEventMouseMotion.new()
    into_panel.position = panel.get_global_rect().get_center()
    into_panel.global_position = into_panel.position
    into_panel.button_mask = MOUSE_BUTTON_MASK_LEFT
    root.push_input(into_panel, true)
    var release: InputEventMouseButton = InputEventMouseButton.new()
    release.position = panel.get_global_rect().get_center()
    release.global_position = release.position
    release.button_index = MOUSE_BUTTON_LEFT
    release.pressed = false
    root.push_input(release, true)
    _expect(not camera.call("is_dragging"), "drawer release terminates existing camera drag")
    var released_position: Vector2 = camera.position
    var motion: InputEventMouseMotion = InputEventMouseMotion.new()
    motion.position = map_point + Vector2(20, 10)
    motion.global_position = motion.position
    motion.relative = Vector2(20, 10)
    root.push_input(motion, true)
    _expect(camera.position.is_equal_approx(released_position),
        "map motion after drawer release cannot continue stale drag")
    camera.call("end_drag")
    drawer.call("set_open", false)

func _mouse_button(point: Vector2, button: MouseButton) -> void:
    var motion: InputEventMouseMotion = InputEventMouseMotion.new()
    motion.position = point
    motion.global_position = point
    root.push_input(motion, true)
    for pressed: bool in [true, false]:
        var event: InputEventMouseButton = InputEventMouseButton.new()
        event.position = point
        event.global_position = point
        event.button_index = button
        event.pressed = pressed
        root.push_input(event, true)

func _check_data_fixtures(session: Dictionary) -> void:
    var plan: WorldPlan = session.plan
    var cells: Dictionary = plan.get_cells()
    var samples: Dictionary = {}
    for coord: Vector2i in cells:
        if cells[coord].town_index >= 0:
            samples["town"] = coord
        if cells[coord].terrain == "forest":
            samples["forest"] = coord
        if cells[coord].encounter == "combat":
            samples["consumed"] = coord
    var roads: Array = plan.get_roads()
    _expect(not roads.is_empty(), "fixture contains roads")
    if not roads.is_empty():
        samples["road"] = roads[0].a
    samples["moved_boss"] = plan.get_boss_coord()
    var state_script: Script = load("res://Scripts/Run/world_run_state.gd")
    for kind: String in ["town", "forest", "road", "consumed", "moved_boss"]:
        _expect(samples.has(kind), "fixture contains " + kind)
        if not samples.has(kind):
            continue
        var coord: Vector2i = samples[kind]
        var data: Dictionary = session.run_state.to_dictionary()
        data.player_coord = [coord.x, coord.y]
        if kind == "consumed":
            data.consumed_encounters = [[coord.x, coord.y]]
        if kind == "moved_boss":
            var moved_boss: Vector2i = plan.get_start_coord()
            data.boss_coord = [moved_boss.x, moved_boss.y]
            data.boss_active = true
            data.move_count = 30
        var built: Dictionary = state_script.from_dictionary(data, plan)
        _expect(built.get("ok", false), kind + " run-state fixture validates")
        if not built.get("ok", false):
            continue
        var fixture: Dictionary = session.duplicate()
        fixture.run_state = built.value
        var world: WorldRuntimeController = await _open(fixture, MemoryRepository.new())
        if not is_instance_valid(world):
            continue
        var view: Dictionary = world.call("get_debug_snapshot")
        _expect(view.coord == coord and view.terrain == cells[coord].terrain,
            kind + " reads current plan cell")
        if kind == "town":
            _expect(view.town_index == cells[coord].town_index and view.ownership.ok and
                view.ownership.clan_id == &"goblin", "town reports resolved owner")
        elif kind == "forest":
            var expected_clusters: Array[int] = []
            var clusters: Array = plan.get_forest_clusters()
            for index: int in clusters.size():
                if clusters[index].has(coord):
                    expected_clusters.append(index)
            _expect(not expected_clusters.is_empty() and view.forest_clusters == expected_clusters,
                "forest reports actual cluster membership")
        elif kind == "road":
            var expected_roads: Array = []
            for road: Dictionary in roads:
                if road.a == coord or road.b == coord:
                    expected_roads.append(road)
            _expect(not expected_roads.is_empty() and view.road_links == expected_roads,
                "road reports actual incident links")
        elif kind == "consumed":
            _expect(view.consumed and view.base_encounter == "combat", "consumed encounter exposed")
        elif kind == "moved_boss":
            _expect(view.base_encounter == "boss" and view.effective_encounter == "safe",
                "moved boss origin distinguishes base and effective encounter")
        world.free()
        await process_frame
    var packed: PackedScene = load("res://Scenes/world_map_runtime.tscn")
    var preview: WorldRuntimeController = packed.instantiate() as WorldRuntimeController
    preview.auto_initialize_runtime = false
    root.add_child(preview)
    await process_frame
    _expect(preview.configure_runtime(plan), "preview configures plan without durable session")
    var view: Dictionary = preview.call("get_debug_snapshot")
    _expect(not view.session_applied and view.coord == plan.get_start_coord(),
        "preview reports plan coordinate without applied session")
    for key: String in ["gold", "run_status", "consumed", "pending_reward_battle_id", "cache_progress"]:
        _expect(not view.has(key), "preview does not invent durable field: " + key)
    preview.free()
    await process_frame
