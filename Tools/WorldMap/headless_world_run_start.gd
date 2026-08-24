class_name HeadlessWorldRunStart
extends SceneTree

static var SERVICE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_start_service.gd")
static var FORMATTER_SCRIPT: GDScript = load("res://Scripts/Run/world_failure_formatter.gd")


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var seed_text := "default-run"
    var build_version := "dev"
    var force_unsatisfiable := false
    var args := OS.get_cmdline_user_args()
    var index := 0
    while index < args.size():
        match args[index]:
            "--seed":
                index += 1
                if index < args.size():
                    seed_text = args[index]
            "--build-version":
                index += 1
                if index < args.size():
                    build_version = args[index]
            "--force-unsatisfiable":
                force_unsatisfiable = true
        index += 1
    if force_unsatisfiable:
        seed_text = "impossible"
    var config := {}
    if force_unsatisfiable:
        config = {
            "radius": 2,
            "town_count": 7,
            "town_min_distance": 4,
            "start": Vector2i(-2, 0),
            "boss": Vector2i(2, 0),
        }
    var service: RefCounted = SERVICE_SCRIPT.new(Callable(self, "_accept_plan"))
    var result: Dictionary = service.start(seed_text, config, "RETURN_RESULT")
    if not result.get("ok", false):
        var line: String = FORMATTER_SCRIPT.format_json_line(result["error"], build_version)
        printerr(line.trim_suffix("\n"))
        quit(70)
        return
    print("{\"event\":\"world_run_started\",\"seed_hex\":%s}" % JSON.stringify(result["plan"].get_seed_hex()))
    quit(0)


func _accept_plan(_plan: RefCounted) -> void:
    pass
