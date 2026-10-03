class_name HexWorldGeneratorV3
extends RefCounted

const VERSION := 3

static var V2_GENERATOR_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/hex_world_generator_v2.gd"
)
static var PLAN_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_plan.gd"
)
static var ROAD_RULES_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/habitat_road_rules_v3.gd"
)
static var CODEC_V3_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_plan_codec_v3.gd"
)
static var ERROR_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_generation_error.gd"
)
static var PRIORITY_SCRIPT: GDScript = load(
    "res://Scripts/WorldMap/world_priority.gd"
)


func generate(seed_text: String, config: Dictionary = {}) -> Dictionary:
    var v2_result: Dictionary = V2_GENERATOR_SCRIPT.new().generate(seed_text, config)
    if not bool(v2_result.get("ok", false)):
        return _promote_failure(seed_text, v2_result.get("error"))

    var v2_plan: RefCounted = v2_result.get("plan") as RefCounted
    if not is_instance_valid(v2_plan):
        return _internal_failure(seed_text, "v2_plan_missing")
    var road_result: Dictionary = ROAD_RULES_SCRIPT.build(
        v2_plan.get_towns(),
        v2_plan.get_seed_hex()
    )
    if not bool(road_result.get("ok", false)):
        return {
            "ok": false,
            "plan": null,
            "error": road_result.get("error"),
        }

    var plan: RefCounted = PLAN_SCRIPT.new(
        VERSION,
        v2_plan.get_seed_hex(),
        v2_plan.get_start_coord(),
        v2_plan.get_boss_coord(),
        v2_plan.get_cells(),
        road_result["roads"],
        v2_plan.get_forest_clusters(),
        v2_plan.get_habitats(),
        v2_plan.get_towns()
    )
    var validation: Variant = CODEC_V3_SCRIPT.validate(plan)
    if validation != null:
        return {"ok": false, "plan": null, "error": validation}
    return {"ok": true, "plan": plan, "error": null}


func _promote_failure(seed_text: String, error: Variant) -> Dictionary:
    if (
        error != null
        and error is RefCounted
        and error.get_script() == ERROR_SCRIPT
    ):
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                error.code,
                error.seed_hex,
                VERSION,
                error.feature_namespace,
                error.failed_constraint
            ),
        }
    return _internal_failure(seed_text, "v2_generation_failure_invalid")


func _internal_failure(seed_text: String, constraint: String) -> Dictionary:
    return {
        "ok": false,
        "plan": null,
        "error": ERROR_SCRIPT.new(
            ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
            PRIORITY_SCRIPT.seed_hex(seed_text),
            VERSION,
            "roads",
            constraint
        ),
    }
