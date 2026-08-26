class_name WorldRuntimeSceneContractTests
extends SceneTree

const EXPECTED_TEST_COUNT := 45
const SCENE_PATH := "res://Scenes/world_map_runtime_preview.tscn"

var _failures: Array[String] = []
var _assertions: int = 0
var _camera_view_events: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _expect(
        ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/game_world.tscn",
        "production main scene remains frozen"
    )
    _expect(ResourceLoader.exists(SCENE_PATH), "explicit non-production runtime scene exists")
    if not ResourceLoader.exists(SCENE_PATH):
        _finish()
        return
    var packed := load(SCENE_PATH) as PackedScene
    var runtime := packed.instantiate()
    _expect(runtime.has_method("get_runtime_snapshot"), "runtime scene exposes typed snapshot inspection")
    _expect(runtime.has_method("request_move"), "runtime scene exposes movement request boundary")
    _expect(runtime.has_method("get_valid_destinations"), "runtime scene exposes valid destinations")
    _expect(runtime.has_method("get_plan_instance_id"), "runtime scene exposes shared plan identity")
    _expect(runtime.has_method("get_world_camera"), "runtime scene exposes camera verification boundary")
    _expect(runtime.has_method("has_integration_failed"), "runtime scene exposes integration failure state")
    get_root().add_child(runtime)
    await process_frame
    await process_frame

    _expect(not bool(runtime.call("has_integration_failed")), "validated runtime composition enables integration")
    _expect(runtime.find_child("*MapController*", true, false) == null, "legacy MapController is absent")
    var initial_snapshot := runtime.call("get_runtime_snapshot") as WorldRuntimeSnapshot
    _expect(is_instance_valid(initial_snapshot), "runtime exposes an immutable initial snapshot")
    _expect(initial_snapshot.player_coord == Vector2i(-8, 0), "runtime starts at canonical player coordinate")
    _expect(initial_snapshot.boss_coord == Vector2i(8, 0), "runtime starts at canonical boss coordinate")
    _expect(initial_snapshot.move_count == 0, "runtime starts before the first accepted move")
    _expect(not initial_snapshot.input_blocked, "validated runtime starts with cell input enabled")
    var valid_destinations := runtime.call("get_valid_destinations") as Array[Vector2i]
    _expect(not valid_destinations.is_empty(), "runtime exposes highlighted canonical neighbours")
    var highlighted_count := 0
    for cell: Node in runtime.get_node("%WorldCells").get_children():
        if (cell.get_node("HighlightLayer/Outline") as Line2D).visible:
            highlighted_count += 1
    _expect(highlighted_count == valid_destinations.size(), "highlighted cells match valid destinations exactly")
    var plan_id := int(runtime.call("get_plan_instance_id"))
    _expect(plan_id != 0, "controller exposes the presented plan identity")
    _expect(plan_id == int(runtime.get_node("%WorldMinimap").call("get_plan_instance_id")), "runtime and minimap share one plan identity")

    var initial_key := initial_snapshot.canonical_key()
    var invalid_result := runtime.call("request_move", Vector2i(0, 0)) as WorldMoveResult
    _expect(not invalid_result.is_accepted(), "non-highlighted distant selection is rejected")
    _expect(runtime.call("get_runtime_snapshot").canonical_key() == initial_key, "rejected selection preserves canonical runtime state")
    var destination := valid_destinations[0]
    var camera := runtime.call("get_world_camera") as WorldCameraController
    _expect(camera.get_visible_world_rect().has_point(Vector2(runtime.call("axial_to_world", destination))), "first destination starts inside the visible camera rectangle")
    var camera_before_visible_move := camera.position
    var accepted_result := runtime.call("request_move", destination) as WorldMoveResult
    _expect(accepted_result.is_accepted(), "highlighted neighbouring selection is accepted")
    _expect(accepted_result.snapshot.move_count == 1, "accepted selection increments the move count once")
    _expect(accepted_result.snapshot.player_coord == destination, "accepted selection moves the player to the chosen neighbour")
    _expect(camera.position.is_equal_approx(camera_before_visible_move), "visible player movement preserves camera position")
    _expect(runtime.call("get_player_coord") == destination and runtime.call("get_boss_coord") == accepted_result.snapshot.boss_coord, "main-map markers match the accepted snapshot")
    var minimap := runtime.get_node("%WorldMinimap") as WorldMinimap
    _expect(minimap.get_player_coord() == destination and minimap.get_boss_coord() == accepted_result.snapshot.boss_coord, "minimap markers match the accepted snapshot")
    var hud := runtime.get_node("%WorldMapHud") as WorldMapHud
    _expect((hud.get_node("%MoveCountLabel") as Label).text == "MOVES 1 / 30", "HUD turn state matches the accepted snapshot")

    runtime.call("close_active_encounter")
    var second_destinations := runtime.call("get_valid_destinations") as Array[Vector2i]
    var second_destination := second_destinations[0]
    camera.center_on(Vector2(runtime.call("axial_to_world", Vector2i(8, 0))))
    _camera_view_events = 0
    camera.view_changed.connect(_on_camera_view_changed)
    var second_result := runtime.call("request_move", second_destination) as WorldMoveResult
    _expect(second_result.is_accepted(), "second highlighted neighbour is accepted")
    _expect(not camera.get_visible_world_rect().has_point(Vector2(runtime.call("axial_to_world", Vector2i(8, 0)))), "hidden-player move replaces the prior remote framing")
    _expect(camera.position.is_equal_approx(Vector2(runtime.call("axial_to_world", second_destination))), "hidden player recenters exactly on its marker")
    _expect(_camera_view_events == 1, "hidden-player snapshot performs exactly one camera recenter")
    var key_before_camera: String = runtime.call("get_runtime_snapshot").canonical_key()
    camera.pan_by(Vector2(80.0, 20.0))
    camera.zoom_by_steps(1, Vector2(576.0, 324.0))
    _expect(runtime.call("get_runtime_snapshot").canonical_key() == key_before_camera, "camera pan and zoom never mutate runtime state")

    runtime.free()

    var input_runtime := packed.instantiate() as WorldRuntimeController
    get_root().add_child(input_runtime)
    await process_frame
    await process_frame
    var pointer_destination := input_runtime.get_valid_destinations()[0]
    var pointer_cell: WorldCellView
    for candidate: Node in input_runtime.get_node("%WorldCells").get_children():
        if candidate is WorldCellView and candidate.coordinate == pointer_destination:
            pointer_cell = candidate
            break
    var pointer_event := InputEventMouseButton.new()
    pointer_event.button_index = MOUSE_BUTTON_LEFT
    pointer_event.pressed = true
    pointer_event.position = pointer_cell.get_canvas_transform() * pointer_cell.global_position
    pointer_cell._unhandled_input(pointer_event)
    pointer_event.pressed = false
    pointer_cell._unhandled_input(pointer_event)
    var pointer_snapshot := input_runtime.get_runtime_snapshot()
    _expect(pointer_snapshot.move_count == 1, "left-click cell input reaches the runtime transaction boundary")
    _expect(pointer_snapshot.player_coord == pointer_destination, "clicked highlighted cell becomes the player coordinate")
    _expect(input_runtime.has_active_encounter(), "clicked highlighted cell opens its encounter surface")
    input_runtime.free()

    var drag_runtime := packed.instantiate() as WorldRuntimeController
    get_root().add_child(drag_runtime)
    await process_frame
    await process_frame
    var drag_destination := drag_runtime.get_valid_destinations()[0]
    var drag_cell: WorldCellView
    for candidate: Node in drag_runtime.get_node("%WorldCells").get_children():
        if candidate is WorldCellView and candidate.coordinate == drag_destination:
            drag_cell = candidate
            break
    var drag_camera := drag_runtime.get_world_camera()
    var drag_start := drag_cell.get_canvas_transform() * drag_cell.global_position
    var before_drag_key := drag_runtime.get_runtime_snapshot().canonical_key()
    var drag_press := InputEventMouseButton.new()
    drag_press.button_index = MOUSE_BUTTON_LEFT
    drag_press.pressed = true
    drag_press.position = drag_start
    drag_cell._unhandled_input(drag_press)
    drag_camera._unhandled_input(drag_press)
    var drag_motion := InputEventMouseMotion.new()
    drag_motion.position = drag_start + Vector2(32.0, 0.0)
    drag_motion.relative = Vector2(32.0, 0.0)
    drag_cell._unhandled_input(drag_motion)
    drag_camera._unhandled_input(drag_motion)
    var drag_release := InputEventMouseButton.new()
    drag_release.button_index = MOUSE_BUTTON_LEFT
    drag_release.pressed = false
    drag_release.position = drag_motion.position
    drag_cell._unhandled_input(drag_release)
    drag_camera._unhandled_input(drag_release)
    _expect(drag_runtime.get_runtime_snapshot().canonical_key() == before_drag_key, "drag over highlighted cell preserves the canonical runtime snapshot")
    _expect(not drag_runtime.has_active_encounter(), "drag over highlighted cell opens no encounter")
    _expect(not drag_camera.is_dragging(), "drag release closes the camera gesture")
    drag_runtime.free()

    var failed_runtime := packed.instantiate() as WorldRuntimeController
    failed_runtime.auto_initialize_runtime = false
    get_root().add_child(failed_runtime)
    await process_frame
    _expect(not failed_runtime.configure_runtime(null), "invalid runtime plan is rejected atomically")
    _expect(failed_runtime.has_integration_failed(), "invalid runtime plan marks integration failed")
    _expect(failed_runtime.get_main_cell_count() == 0, "failed runtime configuration creates zero world cells")
    _expect(failed_runtime.get_node("EncounterHost").get_child_count() + failed_runtime.get_node("BattleHost").get_child_count() + failed_runtime.get_node("PartyHost").get_child_count() == 0, "failed runtime configuration creates zero modal surfaces")
    var failed_snapshot := failed_runtime.get_runtime_snapshot()
    _expect(failed_snapshot.move_count == 0 and failed_snapshot.player_coord == Vector2i.ZERO and failed_snapshot.boss_coord == Vector2i.ZERO, "failed configuration creates no runtime movement mutation")
    failed_runtime.free()
    _finish()


func _on_camera_view_changed(_visible_world_rect: Rect2) -> void:
    _camera_view_events += 1


func _expect(condition: bool, message: String) -> void:
    _assertions += 1
    if not condition:
        _failures.append(message)


func _finish() -> void:
    if _assertions != EXPECTED_TEST_COUNT:
        _failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
    if _failures.is_empty():
        print("World runtime scene contract tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
        quit(0)
        return
    for failure: String in _failures:
        push_error(failure)
    quit(1)
