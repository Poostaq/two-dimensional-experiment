extends SceneTree

const CATALOG_PATH := "res://Scripts/Run/run_character_catalog.gd"
const COALITION_PATH := "res://Scripts/Run/run_clan_coalition.gd"
const SELECTOR_PATH := "res://Scripts/Run/run_allied_clan_selector.gd"

var _failures: int = 0


func _init() -> void:
    _run()


func _run() -> void:
    var catalog: Script = load(CATALOG_PATH) as Script
    _expect(is_instance_valid(catalog), "catalog loads")
    if not is_instance_valid(catalog):
        _finish()
        return
    _expect(catalog.has_method("get_playable_clan_ids"), "canonical clan API exists")
    if catalog.has_method("get_playable_clan_ids"):
        var expected: Array[StringName] = [&"goblin", &"orc", &"werewolf", &"lizardman", &"harpy"]
        var first: Array[StringName] = catalog.call("get_playable_clan_ids")
        _expect_equal(first, expected, "canonical clan order")
        first.clear()
        _expect_equal(catalog.call("get_playable_clan_ids"), expected, "clan order is defensive")
    _expect(catalog.has_method("get_synergistic_clan_ids"), "synergy list API exists")
    _expect(catalog.has_method("has_main_clan_synergy"), "synergy predicate API exists")
    if catalog.has_method("get_synergistic_clan_ids"):
        _expect_equal(
            catalog.call("get_synergistic_clan_ids", &"goblin"),
            [&"orc", &"werewolf", &"lizardman"],
            "Goblin synergy order"
        )

    var coalition_script: Script = load(COALITION_PATH) as Script
    _expect(is_instance_valid(coalition_script), "coalition value exists")
    if is_instance_valid(coalition_script):
        var valid: Dictionary = coalition_script.call("create", &"goblin", [&"orc", &"werewolf"])
        _expect(valid.get("ok", false), "canonical coalition succeeds")
        var reversed: Dictionary = coalition_script.call("create", &"goblin", [&"werewolf", &"orc"])
        _expect(not reversed.get("ok", true), "out-of-order coalition fails")

    var selector_script: Script = load(SELECTOR_PATH) as Script
    _expect(is_instance_valid(selector_script), "selector exists")
    if is_instance_valid(selector_script):
        var selected: Dictionary = selector_script.call("select", &"goblin", "ac9-vector-1")
        _expect(selected.get("ok", false), "golden selection succeeds")
        if selected.get("ok", false):
            _expect_equal(
                selected.value.allied_clan_ids,
                [&"orc", &"werewolf"],
                "golden selection pair"
            )
            var replay: Dictionary = selector_script.call("select", &"goblin", "ac9-vector-1")
            _expect(replay.get("ok", false), "deterministic replay succeeds")
            if replay.get("ok", false):
                _expect_equal(
                    replay.value.allied_clan_ids,
                    selected.value.allied_clan_ids,
                    "same seed selects same pair"
                )

        var reachable: Dictionary = {}
        var all_selections_succeeded: bool = true
        for seed_index: int in range(4096):
            var candidate: Dictionary = selector_script.call("select", &"goblin", "reachability-%d" % seed_index)
            if not candidate.get("ok", false):
                all_selections_succeeded = false
                break
            var candidate_allies: Array[StringName] = candidate.value.allied_clan_ids
            reachable["%s,%s" % [candidate_allies[0], candidate_allies[1]]] = true
        _expect(all_selections_succeeded, "reachability selections succeed")
        var expected_reachable: Dictionary = {
            "orc,werewolf": true,
            "orc,lizardman": true,
            "orc,harpy": true,
            "werewolf,lizardman": true,
            "werewolf,harpy": true,
            "lizardman,harpy": true,
        }
        _expect_equal(reachable, expected_reachable, "every valid Goblin pair is reachable")

        var invalid_main: Dictionary = selector_script.call("select", &"unknown", "invalid-main")
        _expect(not invalid_main.get("ok", true), "unknown main clan fails")
        if not invalid_main.get("ok", true):
            _expect_equal(
                invalid_main.error.code,
                WorldGenerationError.WORLD_GENERATION_INTERNAL_ERROR,
                "invalid main error code"
            )
            _expect_equal(
                invalid_main.error.feature_namespace,
                "allied-clan-selection",
                "invalid main error namespace"
            )
            _expect_equal(
                invalid_main.error.failed_constraint,
                "invalid_main_clan_id",
                "invalid main error constraint"
            )
    _finish()


func _expect(value: bool, label: String) -> void:
    if not value:
        _failures += 1
        push_error(label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
    _expect(actual == expected, "%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
    if _failures == 0:
        print("PASS test_ac9_2_allied_clan_selection")
    quit(0 if _failures == 0 else 1)
