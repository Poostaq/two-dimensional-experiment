class_name RunAlliedClanSelector
extends RefCounted

const SELECTION_VERSION: int = 1
const SELECTION_NAMESPACE := "ac9-allied-clans-v1"


static func select(main_clan_id: StringName, resolved_seed: String) -> Dictionary:
    var priority_script: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
    var playable: Array[StringName] = RunCharacterCatalog.get_playable_clan_ids()
    if not playable.has(main_clan_id):
        return _failure(resolved_seed, "invalid_main_clan_id")
    var eligible: Array[StringName] = []
    for clan_id: StringName in playable:
        if clan_id != main_clan_id:
            eligible.append(clan_id)
    if eligible.size() < 2:
        return _failure(resolved_seed, "eligible_pool_too_small")
    var pairs: Array[Array] = []
    for first: int in eligible.size():
        for second: int in range(first + 1, eligible.size()):
            var pair: Array[StringName] = [eligible[first], eligible[second]]
            if (
                RunCharacterCatalog.has_main_clan_synergy(main_clan_id, pair[0])
                or RunCharacterCatalog.has_main_clan_synergy(main_clan_id, pair[1])
            ):
                pairs.append(pair)
    if pairs.is_empty():
        return _failure(resolved_seed, "no_valid_allied_pair")
    var payload := "twde-ac9|v=%d|seed=%s|ns=%s|main=%s" % [
        SELECTION_VERSION,
        priority_script.seed_hex(resolved_seed),
        SELECTION_NAMESPACE,
        String(main_clan_id),
    ]
    var hash_value: int = priority_script.fnv1a32_ascii(payload)
    var selection_result: Dictionary = RunClanCoalition.create(main_clan_id, pairs[hash_value % pairs.size()])
    if not bool(selection_result.get("ok", false)):
        return _failure(resolved_seed, "coalition_invalid")
    return selection_result


static func _failure(resolved_seed: String, constraint: String) -> Dictionary:
    var error_script: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
    var priority_script: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
    return {
        "ok": false,
        "value": null,
        "error": error_script.new(
            error_script.WORLD_GENERATION_INTERNAL_ERROR,
            priority_script.seed_hex(resolved_seed),
            1,
            "allied-clan-selection",
            constraint
        ),
    }
