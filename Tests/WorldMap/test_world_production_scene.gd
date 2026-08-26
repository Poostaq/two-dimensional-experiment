class_name WorldProductionSceneTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_map_runtime.tscn"
const GENERATOR_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"
const RUN_STATE_PATH := "res://Scripts/Run/world_run_state.gd"

var _failures: int = 0


class FakeRepository:
    extends RefCounted

    var writes: int = 0

    func replace_atomic(_bytes: PackedByteArray) -> Dictionary:
        writes += 1
        return {"ok": true, "value": null, "error": null}


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    if not ResourceLoader.exists(SCENE_PATH):
        _fail("production world scene is missing")
        _finish()
        return
    var packed := load(SCENE_PATH) as PackedScene
    var world := packed.instantiate() as Node2D
    _expect(is_instance_valid(world), "production world instantiates")
    if not is_instance_valid(world):
        _finish()
        return
    _expect(not bool(world.get("auto_initialize_runtime")), "preview auto-start is disabled")
    root.add_child(world)
    await process_frame
    _expect(not bool(world.call("apply_session", {}, FakeRepository.new())), "missing session is rejected")
    _expect(not bool(world.call("is_session_applied")), "input remains unavailable without a session")
    _expect(world.call("get_valid_destinations").is_empty(), "missing session exposes no moves")

    var generated: Dictionary = (load(GENERATOR_PATH) as GDScript).new().generate("golden-alpha")
    var plan := generated.get("plan") as WorldPlan
    var consumed: Array[Vector2i] = []
    var formation: Array[StringName] = [&"", &"", &"", &"", &"", &""]
    var state: RefCounted = (load(RUN_STATE_PATH) as GDScript).create(
        plan.get_start_coord(), plan.get_boss_coord(), 0, false, false, consumed, formation
    )
    var session := {
        "plan": plan,
        "resolved_seed": "golden-alpha",
        "run_state": state,
    }
    _expect(bool(world.call("apply_session", session, FakeRepository.new())), "valid session applies")
    _expect(bool(world.call("is_session_applied")), "session becomes authoritative")
    _expect(
        world.call("get_runtime_snapshot").call("canonical_key")
        == "%d,%d|%d,%d|0|0|0|0" % [
            plan.get_start_coord().x,
            plan.get_start_coord().y,
            plan.get_boss_coord().x,
            plan.get_boss_coord().y,
        ],
        "plan and runtime state restore before input"
    )
    _expect(not world.call("get_valid_destinations").is_empty(), "input enables after restore")

    var overlays := world.find_children("*", "WorldAutosaveFailureOverlay", true, false)
    _expect(overlays.size() == 1, "production world hosts exactly one autosave overlay")
    if overlays.size() == 1:
        _expect(
            (overlays[0] as Control).mouse_filter == Control.MOUSE_FILTER_STOP,
            "autosave overlay is blocking"
        )
    world.queue_free()
    await process_frame
    _finish()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _fail(message)


func _fail(message: String) -> void:
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_production_scene")
    quit(1 if _failures > 0 else 0)
