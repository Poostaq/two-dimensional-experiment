extends SceneTree

const SCRIPT_PATH := "res://Scripts/WorldMap/world_encounter_type.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var encounter_script: GDScript = load(SCRIPT_PATH)
    _expect(encounter_script != null, "encounter authority script exists")
    if encounter_script != null:
        _expect(encounter_script.NONE == "", "none identifier")
        _expect(encounter_script.SAFE == "safe", "safe identifier")
        _expect(encounter_script.COMBAT == "combat", "combat identifier")
        _expect(encounter_script.BOSS == "boss", "boss identifier")
    _finish()


func _expect(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_encounter_type")
    quit(1 if _failures > 0 else 0)
