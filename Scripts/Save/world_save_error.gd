class_name WorldSaveError
extends RefCounted

const RUN_LOST: String = "RUN_LOST"

const SAVE_ENVELOPE_INVALID := "SAVE_ENVELOPE_INVALID"

var code: String
var failed_constraint: String


func _init(error_code: String, constraint: String) -> void:
    code = error_code
    failed_constraint = constraint
