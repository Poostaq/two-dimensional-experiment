class_name WorldSingleSlotRepository
extends RefCounted

const DEFAULT_SAVE_PATH := "user://active-world-run.json"

static var SAVE_CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_run_save_codec_v5.gd")
static var SAVE_STORE_SCRIPT: GDScript = load("res://Scripts/Save/world_save_store.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/Save/world_save_error.gd")

var save_path: String
var _store: RefCounted


func _init(path: String = DEFAULT_SAVE_PATH) -> void:
    save_path = path
    _store = SAVE_STORE_SCRIPT.new()


func has_save() -> bool:
    return FileAccess.file_exists(save_path)


func load_validated() -> Dictionary:
    var inspected: Dictionary = inspect_slot()
    if not inspected.get("ok", false):
        return inspected
    var state: RefCounted = inspected.get("value", {}).get("run_state") as RefCounted
    if is_instance_valid(state) and not state.is_playable():
        return {"ok": false, "value": null, "error": ERROR_SCRIPT.new(ERROR_SCRIPT.RUN_LOST, "run_status_lost")}
    return inspected


func inspect_slot() -> Dictionary:
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        return _failure("open_source")
    var bytes := file.get_buffer(file.get_length())
    file.close()
    return SAVE_CODEC_SCRIPT.decode_any(bytes)


func replace_atomic(bytes: PackedByteArray) -> Dictionary:
    return _store.call("save_atomic", save_path, bytes)


func _failure(constraint: String) -> Dictionary:
    return {
        "ok": false,
        "value": null,
        "error": ERROR_SCRIPT.new(ERROR_SCRIPT.SAVE_ENVELOPE_INVALID, constraint),
    }
