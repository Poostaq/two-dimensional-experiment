class_name WorldFailureFormatter
extends RefCounted


static func format_json_line(error: RefCounted, build_version: String) -> String:
    return "{\"event\":\"world_generation_failed\",\"code\":%s,\"seed_hex\":%s,\"generator_version\":%d,\"namespace\":%s,\"constraint\":%s,\"build_version\":%s}\n" % [
        JSON.stringify(error.code),
        JSON.stringify(error.seed_hex),
        error.generator_version,
        JSON.stringify(error.feature_namespace),
        JSON.stringify(error.failed_constraint),
        JSON.stringify(build_version),
    ]
