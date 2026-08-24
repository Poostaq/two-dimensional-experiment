class_name WorldGenerationError
extends RefCounted

const WORLD_CONSTRAINT_UNSATISFIABLE := "WORLD_CONSTRAINT_UNSATISFIABLE"
const WORLD_GENERATION_INTERNAL_ERROR := "WORLD_GENERATION_INTERNAL_ERROR"
const WORLD_VERSION_UNSUPPORTED := "WORLD_VERSION_UNSUPPORTED"
const LEGACY_WORLD_SAVE_UNSUPPORTED := "LEGACY_WORLD_SAVE_UNSUPPORTED"

var code: String
var seed_hex: String
var generator_version: int
var feature_namespace: String
var failed_constraint: String


func _init(
    error_code: String,
    error_seed_hex: String = "",
    error_generator_version: int = 1,
    error_feature_namespace: String = "",
    error_failed_constraint: String = ""
) -> void:
    code = error_code
    seed_hex = error_seed_hex
    generator_version = error_generator_version
    feature_namespace = error_feature_namespace
    failed_constraint = error_failed_constraint


func to_dictionary() -> Dictionary:
    return {
        "code": code,
        "seed_hex": seed_hex,
        "generator_version": generator_version,
        "namespace": feature_namespace,
        "constraint": failed_constraint,
    }
