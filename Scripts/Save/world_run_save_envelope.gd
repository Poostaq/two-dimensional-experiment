class_name WorldRunSaveEnvelope
extends RefCounted

const SCHEMA := "twde-run-save"
const GENERATOR_VERSION := 1
const STARTER_ROSTER_VERSION := 1

static var SAVE_ERROR_SCRIPT: GDScript = load("res://Scripts/Save/world_save_error.gd")
static var WORLD_ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var PLAN_CODEC_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")
static var ENEMY_BOSS_SELECTION_SCRIPT: GDScript = load(
    "res://Scripts/Run/run_enemy_boss_selection.gd"
)


static func encode(
    plan: RefCounted,
    resolved_seed: String,
    run_state: RefCounted,
    save_version: int,
    selection: RunClanSelection = null,
    coalition: RunClanCoalition = null,
    enemy_boss_selection: RefCounted = null
) -> PackedByteArray:
    if not is_instance_valid(plan) or not is_instance_valid(run_state):
        return PackedByteArray()
    if save_version not in [2, 3, 4, 5, 6, 7, 8] or not run_state.is_valid(plan):
        return PackedByteArray()
    if save_version in [6, 7, 8] and not is_instance_valid(selection):
        return PackedByteArray()
    if save_version in [7, 8] and not is_instance_valid(coalition):
        return PackedByteArray()
    if save_version in [7, 8] and coalition.main_clan_id != selection.main_clan_id:
        return PackedByteArray()
    if (
        save_version == 8
        and (
            not is_instance_valid(enemy_boss_selection)
            or enemy_boss_selection.resolved_seed != resolved_seed
        )
    ):
        return PackedByteArray()
    var state_data: Dictionary = run_state.to_dictionary()
    if save_version < 5:
        if not run_state.pending_reward_battle_id.is_empty():
            return PackedByteArray()
        state_data.erase("pending_reward_battle_id")
    if save_version < 4:
        if not run_state.is_playable() or not state_data["battle_settlements"].is_empty():
            return PackedByteArray()
        state_data.erase("run_status")
        state_data.erase("battle_settlements")
    if save_version == 2:
        state_data.erase("gold")
    var plan_bytes: PackedByteArray = PLAN_CODEC_SCRIPT.serialize(plan)
    var root: Dictionary = {
        "schema": SCHEMA,
        "save_version": save_version,
        "starter_roster_version": STARTER_ROSTER_VERSION,
        "world": {
            "generator_version": plan.get_version(),
            "run_seed_utf8_hex": plan.get_seed_hex(),
            "resolved_seed": resolved_seed,
            "canonical_plan_utf8": plan_bytes.get_string_from_utf8(),
            "canonical_plan_sha256": _sha256(plan_bytes),
            "run_state": state_data,
        },
    }
    if save_version in [6, 7, 8]:
        root["world"]["main_clan_id"] = String(selection.main_clan_id)
        root["world"]["commander_id"] = String(selection.commander_id)
    if save_version in [7, 8]:
        root["world"]["allied_clan_ids"] = coalition.allied_clan_ids.map(
            func(clan_id: StringName) -> String: return String(clan_id)
        )
    if save_version == 8:
        root["world"]["enemy_clan_id"] = String(enemy_boss_selection.enemy_clan_id)
        root["world"]["boss_party_id"] = String(enemy_boss_selection.boss_party_id)
    return (JSON.stringify(root) + "\n").to_utf8_buffer()


# Shared validation for explicit V2 and V3 envelopes; only V2 receives a zero wallet.
static func decode(root: Dictionary, expected_version: int) -> Dictionary:
    var version: Variant = root.get("save_version")
    if not (version is int or version is float) or version != expected_version:
        return _save_failure("root_schema")
    if expected_version not in [2, 3, 4, 5, 6, 7, 8] or root.get("schema") != SCHEMA:
        return _save_failure("root_schema")
    if expected_version >= 4 and not _valid_current_shape(root, expected_version):
        return _save_failure("v%d_shape" % expected_version)
    var roster_version: Variant = root.get("starter_roster_version", 0)
    if not (roster_version is int or roster_version is float) or (roster_version != 0 and roster_version != STARTER_ROSTER_VERSION):
        return _save_failure("starter_roster_version")
    var world_value: Variant = root.get("world")
    if not world_value is Dictionary:
        return _save_failure("world_object")
    var world := world_value as Dictionary
    for field: String in [
        "generator_version",
        "run_seed_utf8_hex",
        "resolved_seed",
        "canonical_plan_utf8",
        "canonical_plan_sha256",
        "run_state",
    ]:
        if not world.has(field):
            return _save_failure("missing_%s" % field)
    var generator_version := int(world.get("generator_version", -1))
    if generator_version != GENERATOR_VERSION:
        return _world_failure(
            WORLD_ERROR_SCRIPT.WORLD_VERSION_UNSUPPORTED,
            String(world.get("run_seed_utf8_hex", "")),
            generator_version,
            "save",
            "generator_version"
        )
    if not world.get("canonical_plan_utf8") is String or not world.get("canonical_plan_sha256") is String:
        return _save_failure("plan_fields")
    var plan_bytes := String(world["canonical_plan_utf8"]).to_utf8_buffer()
    if _sha256(plan_bytes) != String(world["canonical_plan_sha256"]):
        return _save_failure("canonical_plan_sha256")
    var plan_result: Dictionary = PLAN_CODEC_SCRIPT.parse(plan_bytes)
    if not bool(plan_result.get("ok", false)):
        return _save_failure("canonical_plan")
    var plan := plan_result.get("plan") as RefCounted
    if not is_instance_valid(plan) or plan.get_seed_hex() != String(world.get("run_seed_utf8_hex", "")):
        return _save_failure("run_seed_utf8_hex")
    if not world.get("resolved_seed") is String or not world.get("run_state") is Dictionary:
        return _save_failure("runtime_fields")
    var selection: RunClanSelection = null
    if expected_version in [6, 7, 8]:
        var selection_result: Dictionary = RunClanSelection.create(
            StringName(world.get("main_clan_id", "")),
            StringName(world.get("commander_id", "")),
            String(world.get("resolved_seed", ""))
        )
        if not bool(selection_result.get("ok", false)):
            return _save_failure("clan_selection")
        selection = selection_result["value"] as RunClanSelection
    var coalition: RunClanCoalition = null
    if expected_version in [7, 8]:
        var allied_values: Variant = world.get("allied_clan_ids")
        if not allied_values is Array:
            return _save_failure("allied_clan_ids")
        var allied_clan_ids: Array[StringName] = []
        for value: Variant in allied_values:
            if not value is String:
                return _save_failure("allied_clan_ids")
            allied_clan_ids.append(StringName(value))
        var coalition_result: Dictionary = RunClanCoalition.create(
            selection.main_clan_id,
            allied_clan_ids
        )
        if not bool(coalition_result.get("ok", false)):
            return _save_failure("allied_clan_ids")
        coalition = coalition_result["value"] as RunClanCoalition
    var enemy_boss_selection: RefCounted = null
    if expected_version == 8:
        var enemy_selection_result: Dictionary = ENEMY_BOSS_SELECTION_SCRIPT.create(
            String(world.get("resolved_seed", "")),
            StringName(world.get("enemy_clan_id", "")),
            StringName(world.get("boss_party_id", ""))
        )
        if not bool(enemy_selection_result.get("ok", false)):
            return _save_failure("enemy_boss_selection")
        enemy_boss_selection = enemy_selection_result.get("value") as RefCounted
    var state_data: Dictionary = world["run_state"].duplicate(true)
    if expected_version < 5:
        if state_data.has("pending_reward_battle_id"):
            return _save_failure("legacy_reward_field")
        state_data["pending_reward_battle_id"] = ""
    if expected_version < 4:
        if state_data.has("run_status") or state_data.has("battle_settlements"):
            return _save_failure("legacy_lifecycle_fields")
        state_data["run_status"] = "active"
        state_data["battle_settlements"] = []
    if expected_version == 2:
        state_data["gold"] = 0
    var state_result: Dictionary = RUN_STATE_SCRIPT.from_dictionary(state_data, plan)
    if not bool(state_result.get("ok", false)):
        return _save_failure("run_state")
    if int(roster_version) == 0 and not _migrate_legacy_starter_health(state_result["value"]):
        return _save_failure("legacy_starter_health")
    return {
        "ok": true,
        "value": {
            "plan": plan,
            "resolved_seed": String(world["resolved_seed"]),
            "run_state": state_result["value"],
            "selection": selection,
            "coalition": coalition,
            "enemy_boss_selection": enemy_boss_selection,
        },
        "error": null,
    }


static func _migrate_legacy_starter_health(state: RefCounted) -> bool:
    if not state.has_character_hp_snapshot():
        return true
    var health: Dictionary[StringName, int] = state.get_character_hp_snapshot()
    # Legacy placeholders had 20 HP. Only these two starters lost maximum HP.
    var new_maxima: Dictionary[StringName, int] = {&"player_1": 14, &"player_2": 16}
    for character_id: StringName in new_maxima:
        if not health.has(character_id):
            continue
        if health[character_id] > 20:
            return false
        health[character_id] = mini(health[character_id], new_maxima[character_id])
    return state.set_character_hp_snapshot(health)


static func _save_failure(constraint: String) -> Dictionary:
    return {
        "ok": false,
        "value": null,
        "error": SAVE_ERROR_SCRIPT.new(SAVE_ERROR_SCRIPT.SAVE_ENVELOPE_INVALID, constraint),
    }


static func _world_failure(
    code: String,
    seed_hex: String,
    version: int,
    feature_namespace: String,
    constraint: String
) -> Dictionary:
    return {
        "ok": false,
        "value": null,
        "error": WORLD_ERROR_SCRIPT.new(code, seed_hex, version, feature_namespace, constraint),
    }


static func _sha256(bytes: PackedByteArray) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update(bytes)
    return context.finish().hex_encode()


static func _keys_match(value: Variant, expected: Array[String]) -> bool:
    if not value is Dictionary or value.size() != expected.size():
        return false
    for key: String in expected:
        if not value.has(key):
            return false
    return true


static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
    if not value is int and not value is float:
        return false
    return is_finite(float(value)) and value >= minimum and value <= maximum and float(value) == floorf(float(value))


static func _coord(value: Variant) -> bool:
    return value is Array and value.size() == 2 and _integer(value[0], -2147483648, 2147483647) and _integer(value[1], -2147483648, 2147483647)


static func _valid_current_shape(root: Dictionary, version: int) -> bool:
    if not _keys_match(root, ["schema", "save_version", "starter_roster_version", "world"]):
        return false
    if not _integer(root.starter_roster_version, 1, 1):
        return false
    var world: Variant = root.world
    var world_keys: Array[String] = ["generator_version", "run_seed_utf8_hex", "resolved_seed", "canonical_plan_utf8", "canonical_plan_sha256", "run_state"]
    if version in [6, 7, 8]:
        world_keys.append("main_clan_id")
        world_keys.append("commander_id")
    if version in [7, 8]:
        world_keys.append("allied_clan_ids")
    if version == 8:
        world_keys.append("enemy_clan_id")
        world_keys.append("boss_party_id")
    if not _keys_match(world, world_keys):
        return false
    if not _integer(world.generator_version, 1, 1) or not world.run_seed_utf8_hex is String or not world.resolved_seed is String or world.resolved_seed.is_empty():
        return false
    var state: Variant = world.run_state
    var keys: Array[String] = ["player_coord", "boss_coord", "move_count", "gold", "boss_active", "boss_engaged", "consumed_encounters", "formation", "character_hp", "cache_move_progress", "cache_ready", "battle_preparation", "run_status", "battle_settlements"]
    if version >= 5:
        keys.append("pending_reward_battle_id")
    if not _keys_match(state, keys):
        return false
    if version >= 5 and not state.pending_reward_battle_id is String:
        return false
    if not _coord(state.player_coord) or not _coord(state.boss_coord):
        return false
    if not _integer(state.move_count, 0, 9007199254740991) or not _integer(state.cache_move_progress, 0, 3):
        return false
    for key: String in ["boss_active", "boss_engaged", "cache_ready"]:
        if not state[key] is bool:
            return false
    if not state.consumed_encounters is Array:
        return false
    var seen: Array[Vector2i] = []
    for value: Variant in state.consumed_encounters:
        if not _coord(value):
            return false
        var coord := Vector2i(int(value[0]), int(value[1]))
        if seen.has(coord):
            return false
        seen.append(coord)
    return true
