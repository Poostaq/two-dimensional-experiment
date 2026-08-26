class_name WorldFailureFormatter
extends RefCounted


static func format_json_line(error: RefCounted, build_version: String) -> String:
    if error is WorldGenerationError:
        return "{\"event\":\"world_generation_failed\",\"code\":%s,\"seed_hex\":%s,\"generator_version\":%d,\"namespace\":%s,\"constraint\":%s,\"build_version\":%s}\n" % [
            JSON.stringify(error.get("code")),
            JSON.stringify(error.get("seed_hex")),
            int(error.get("generator_version")),
            JSON.stringify(error.get("feature_namespace")),
            JSON.stringify(error.get("failed_constraint")),
            JSON.stringify(build_version),
        ]
    var payload := {
        "event": "world_save_failed",
        "code": String(error.get("code")) if is_instance_valid(error) else "UNKNOWN",
        "constraint": (
            String(error.get("failed_constraint"))
            if is_instance_valid(error)
            else "missing_error"
        ),
        "build_version": build_version,
    }
    return JSON.stringify(payload) + "\n"
