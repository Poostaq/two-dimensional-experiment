class_name WorldSaveStore
extends RefCounted

static var CODEC_SCRIPT: GDScript = load("res://Scripts/Save/world_save_codec_v1.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/Save/world_save_error.gd")


func save_atomic(path: String, bytes: PackedByteArray) -> Dictionary:
    var absolute_path := ProjectSettings.globalize_path(path)
    var base_dir := absolute_path.get_base_dir()
    var make_error := DirAccess.make_dir_recursive_absolute(base_dir)
    if make_error != OK:
        return _failure("create_directory")
    var temp_path := absolute_path + ".tmp"
    var backup_path := absolute_path + ".bak"
    _remove_if_exists(temp_path)
    _remove_if_exists(backup_path)

    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return _failure("open_temp")
    file.store_buffer(bytes)
    file.flush()
    var write_error := file.get_error()
    file.close()
    if write_error != OK:
        _remove_if_exists(temp_path)
        return _failure("write_temp")

    var had_destination := FileAccess.file_exists(absolute_path)
    if had_destination:
        var backup_error := DirAccess.rename_absolute(absolute_path, backup_path)
        if backup_error != OK:
            _remove_if_exists(temp_path)
            return _failure("backup_destination")
    var publish_error := DirAccess.rename_absolute(temp_path, absolute_path)
    if publish_error != OK:
        if had_destination and FileAccess.file_exists(backup_path):
            DirAccess.rename_absolute(backup_path, absolute_path)
        _remove_if_exists(temp_path)
        return _failure("publish_temp")
    _remove_if_exists(backup_path)
    return {"ok": true, "error": null}


func load_validated(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return _failure("open_source")
    var bytes := file.get_buffer(file.get_length())
    file.close()
    return CODEC_SCRIPT.decode(bytes)


func _failure(constraint: String) -> Dictionary:
    return {
        "ok": false,
        "value": null,
        "error": ERROR_SCRIPT.new(ERROR_SCRIPT.SAVE_ENVELOPE_INVALID, constraint),
    }


func _remove_if_exists(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
