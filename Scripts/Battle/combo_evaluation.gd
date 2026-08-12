class_name ComboEvaluation
extends RefCounted

enum DiagnosticCode { NONE, NO_COMBO, INVALID_INPUT, UNSUPPORTED_CONDITION, UNSUPPORTED_EFFECT }

var has_combo: bool
var activated: bool
var condition_results: Array[RefCounted]:
	get:
		return _condition_results.duplicate()
var bonus_operations: Array[Dictionary]:
	get:
		return _bonus_operations.duplicate(true)
var diagnostic_code: DiagnosticCode

var _condition_results: Array[RefCounted] = []
var _bonus_operations: Array[Dictionary] = []


func _init(
	combo_exists: bool,
	did_activate: bool,
	results: Array,
	operations: Array,
	diagnostic: int
) -> void:
	has_combo = combo_exists
	activated = did_activate
	for result: RefCounted in results:
		_condition_results.append(result)
	for operation: Dictionary in operations:
		_bonus_operations.append(operation.duplicate(true))
	diagnostic_code = diagnostic as DiagnosticCode
