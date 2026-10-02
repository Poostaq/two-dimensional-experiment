extends SceneTree

const START_SERVICE_PATH := "res://Scripts/Run/world_run_start_service.gd"
const V8_CODEC_PATH := "res://Scripts/Save/world_run_save_codec_v8.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var service_script: GDScript = load(START_SERVICE_PATH)
    var service: RefCounted = service_script.new(func(_plan: RefCounted) -> void: pass)
    var started: Dictionary = service.call("start", "ac9-v8-round-trip")
    _expect(bool(started.get("ok", false)), "Run start succeeds")
    var codec_script: GDScript = load(V8_CODEC_PATH)
    _expect(is_instance_valid(codec_script), "V8 codec exists")
    if not bool(started.get("ok", false)) or not is_instance_valid(codec_script):
        _finish()
        return
    var bytes: PackedByteArray = codec_script.encode(
        started["plan"],
        started["resolved_seed"],
        started["run_state"],
        started["selection"],
        started["coalition"],
        started["enemy_boss_selection"]
    )
    _expect(not bytes.is_empty(), "V8 encodes enemy boss selection")
    var decoded: Dictionary = codec_script.decode_any(bytes)
    _expect(bool(decoded.get("ok", false)), "V8 round trip decodes")
    if bool(decoded.get("ok", false)):
        var enemy_boss_selection: Variant = decoded["value"].get("enemy_boss_selection")
        _expect(is_instance_valid(enemy_boss_selection), "Decoded V8 retains enemy boss selection")
        if is_instance_valid(enemy_boss_selection):
            _expect(
                enemy_boss_selection.enemy_clan_id == started["enemy_boss_selection"].enemy_clan_id
                and enemy_boss_selection.boss_party_id == started["enemy_boss_selection"].boss_party_id,
                "Decoded V8 preserves exact authored boss party"
            )
    _finish()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_world_run_save_codec_v8")
    quit(1 if _failures > 0 else 0)
