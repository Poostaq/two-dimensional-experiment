extends SceneTree

const CODEC_PATH := "res://Scripts/Save/world_run_save_codec_v6.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var codec: Script = load(CODEC_PATH) as Script
    _expect(is_instance_valid(codec), "V6 codec exists")
    if is_instance_valid(codec):
        _expect_equal(codec.get("SAVE_VERSION"), 6, "V6 writer version")
    _finish()


func _expect(value: bool, label: String) -> void:
    if not value:
        _failures += 1
        push_error(label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
    _expect(actual == expected, "%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_run_save_codec_v6")
    quit(0 if _failures == 0 else 1)
