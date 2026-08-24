class_name WorldRunStartService
extends RefCounted

const RETURN_RESULT := "RETURN_RESULT"

static var GENERATOR_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_generator_v1.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")

var _commit_callback: Callable
var _generator: RefCounted


func _init(commit_callback: Callable, generator: RefCounted = null) -> void:
    _commit_callback = commit_callback
    _generator = generator if generator != null else GENERATOR_SCRIPT.new()


func start(seed_text: String, config: Dictionary = {}, policy: String = RETURN_RESULT) -> Dictionary:
    if policy != RETURN_RESULT:
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                1,
                "run-start",
                "unsupported_failure_policy=%s" % policy
            ),
        }
    var generated: Dictionary = _generator.generate(seed_text, config)
    if not generated.get("ok", false):
        return {
            "ok": false,
            "plan": null,
            "error": generated["error"],
        }
    var plan: RefCounted = generated["plan"]
    if not _commit_callback.is_valid():
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                plan.get_seed_hex(),
                plan.get_version(),
                "run-start",
                "commit_callback_invalid"
            ),
        }
    _commit_callback.call(plan)
    return {"ok": true, "plan": plan, "error": null}
