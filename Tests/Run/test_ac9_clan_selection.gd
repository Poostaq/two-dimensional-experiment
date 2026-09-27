extends SceneTree

const CATALOG_PATH := "res://Scripts/Run/run_character_catalog.gd"
const SELECTION_PATH := "res://Scripts/Run/run_clan_selection.gd"

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var catalog: Script = load(CATALOG_PATH) as Script
    _expect(is_instance_valid(catalog), "catalog loads")
    if not is_instance_valid(catalog):
        _finish()
        return
    _expect(catalog.has_method("get_playable_clans"), "catalog exposes playable clans")
    _expect(
        catalog.has_method("get_player_commander_ids_for_clan"),
        "catalog exposes clan commander lookup"
    )
    if catalog.has_method("get_playable_clans"):
        _expect_equal(
            catalog.call("get_playable_clans"),
            [&"goblin", &"orc", &"werewolf", &"lizardman", &"harpy"],
            "playable clan order"
        )
    if catalog.has_method("get_player_commander_ids_for_clan"):
        for clan_id: StringName in [&"goblin", &"orc", &"werewolf", &"lizardman", &"harpy"]:
            for commander_id: StringName in catalog.call("get_player_commander_ids_for_clan", clan_id):
                _expect_equal(
                    catalog.call("get_commander_faction_id", commander_id),
                    clan_id,
                    "%s commander belongs to %s" % [String(commander_id), String(clan_id)]
                )
    var selection_script: Script = load(SELECTION_PATH) as Script
    _expect(is_instance_valid(selection_script), "selection value loads")
    if is_instance_valid(selection_script):
        var valid: Dictionary = selection_script.call("create", &"orc", &"goruk_ironline", " seed ")
        _expect(valid.get("ok", false), "valid owning clan commander selection succeeds")
        if valid.get("ok", false):
            _expect_equal(valid.value.main_clan_id, &"orc", "selection preserves clan")
            _expect_equal(valid.value.commander_id, &"goruk_ironline", "selection preserves commander")
            _expect_equal(valid.value.seed_text, "seed", "selection normalizes seed")
        for invalid_pair: Array[StringName] in [
            [&"", &"goruk_ironline"],
            [&"orc", &""],
            [&"unknown", &"goruk_ironline"],
            [&"lizardman", &"goruk_ironline"],
        ]:
            var invalid: Dictionary = selection_script.call(
                "create", invalid_pair[0], invalid_pair[1], ""
            )
            _expect(not invalid.get("ok", true), "invalid pair is rejected")
    _finish()


func _expect(value: bool, label: String) -> void:
    if not value:
        _failures += 1
        push_error(label)


func _expect_equal(actual: Variant, expected: Variant, label: String) -> void:
    _expect(actual == expected, "%s: expected %s, got %s" % [label, str(expected), str(actual)])


func _finish() -> void:
    if _failures == 0:
        print("PASS test_ac9_clan_selection")
    quit(0 if _failures == 0 else 1)
