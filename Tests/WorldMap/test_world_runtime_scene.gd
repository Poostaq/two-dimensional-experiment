class_name WorldRuntimeSceneContractTests
extends SceneTree

const EXPECTED_TEST_COUNT := 28
const SCENE_PATH := "res://Scenes/world_map_runtime_preview.tscn"

var _failures: Array[String] = []
var _assertions: int = 0


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
    var accepted_result := runtime.call("request_move", destination) as WorldMoveResult
    _expect(accepted_result.is_accepted(), "highlighted neighbouring selection is accepted")
    _expect(accepted_result.snapshot.move_count == 1, "accepted selection increments the move count once")
    _expect(accepted_result.snapshot.player_coord == destination, "accepted selection moves the player to the chosen neighbour")
    _expect(runtime.call("get_player_coord") == destination and runtime.call("get_boss_coord") == accepted_result.snapshot.boss_coord, "main-map markers match the accepted snapshot")
    var minimap := runtime.get_node("%WorldMinimap") as WorldMinimap
    _expect(minimap.get_player_coord() == destination and minimap.get_boss_coord() == accepted_result.snapshot.boss_coord, "minimap markers match the accepted snapshot")
    var hud := runtime.get_node("%WorldMapHud") as WorldMapHud
    _expect((hud.get_node("%MoveCountLabel") as Label).text == "MOVES 1 / 30", "HUD turn state matches the accepted snapshot")

    var key_before_camera: String = runtime.call("get_runtime_snapshot").canonical_key()
    var camera := runtime.call("get_world_camera") as WorldCameraController
    camera.pan_by(Vector2(80.0, 20.0))
    camera.zoom_by_steps(1, Vector2(576.0, 324.0))
    _expect(runtime.call("get_runtime_snapshot").canonical_key() == key_before_camera, "camera pan and zoom never mutate runtime state")

    runtime.free()
    _finish()


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
