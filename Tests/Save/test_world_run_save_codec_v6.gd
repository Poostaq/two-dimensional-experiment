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
        var service: WorldRunStartService = WorldRunStartService.new(func(_plan: RefCounted) -> void: pass)
        var selection_result: Dictionary = RunClanSelection.create(&"orc", &"goruk_ironline", "v6-selection")
        _expect(selection_result.get("ok", false), "valid selection constructs")
        if selection_result.get("ok", false):
            var selection: RunClanSelection = selection_result["value"] as RunClanSelection
            var started: Dictionary = service.start("v6-selection", {}, "RETURN_RESULT", selection.commander_id, selection.main_clan_id, selection)
            _expect(started.get("ok", false), "selected run starts")
            if started.get("ok", false):
                var bytes: PackedByteArray = codec.encode(started.plan, started.resolved_seed, started.run_state, selection)
                _expect(not bytes.is_empty(), "V6 encodes selected run")
                var decoded: Dictionary = codec.decode_any(bytes)
                _expect(decoded.get("ok", false), "V6 decodes selected run")
                if decoded.get("ok", false):
                    var restored: RunClanSelection = decoded.value.selection as RunClanSelection
                    _expect_equal(restored.main_clan_id, &"orc", "V6 restores clan")
                    _expect_equal(restored.commander_id, &"goruk_ironline", "V6 restores commander")
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
