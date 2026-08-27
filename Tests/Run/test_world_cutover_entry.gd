class_name WorldCutoverEntryTests
extends SceneTree

const EXPECTED_MAIN_SCENE := "res://Scenes/world_run_start.tscn"
const REMOVED_LEGACY_PATHS: Array[String] = [
    "res://Scenes/game_world.tscn",
    "res://Scenes/map_hex_tile.tscn",
    "res://Scripts/Map/map_controller.gd",
    "res://Scripts/Map/hex_tile_view.gd",
]

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var configured_main := String(
        ProjectSettings.get_setting("application/run/main_scene", "")
    )
    _expect(
        configured_main == EXPECTED_MAIN_SCENE,
        "production authority is the Stage 5 launcher"
    )
    for legacy_path: String in REMOVED_LEGACY_PATHS:
        _expect(
            not FileAccess.file_exists(ProjectSettings.globalize_path(legacy_path)),
            "legacy runtime path is removed: %s" % legacy_path
        )
    if _failures == 0:
        print("PASS test_world_cutover_entry")
    quit(1 if _failures > 0 else 0)


func _expect(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)
