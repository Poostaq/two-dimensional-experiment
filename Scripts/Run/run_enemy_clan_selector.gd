class_name RunEnemyClanSelector
extends RefCounted

const SELECTION_VERSION: int = 1
const SELECTION_NAMESPACE := "ac9-enemy-clan-v1"


static func select(resolved_seed: String) -> Dictionary:
    var normalized_seed: String = resolved_seed.strip_edges()
    var priority_script: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
    var enemy_clan_ids: Array[StringName] = RunCharacterCatalog.get_enemy_clan_ids()
    if normalized_seed.is_empty():
        return _failure(normalized_seed, "invalid_resolved_seed")
    if enemy_clan_ids.is_empty():
        return _failure(normalized_seed, "enemy_clan_pool_empty")
    var payload := "twde-ac9|v=%d|seed=%s|ns=%s" % [
        SELECTION_VERSION,
        priority_script.seed_hex(normalized_seed),
        SELECTION_NAMESPACE,
    ]
    var hash_value: int = priority_script.fnv1a32_ascii(payload)
    var enemy_clan_id: StringName = enemy_clan_ids[hash_value % enemy_clan_ids.size()]
    var definition: EnemyBossPartyDefinition = (
        BossPartyCatalog.get_definition_by_enemy_clan_id(enemy_clan_id)
    )
    if not is_instance_valid(definition):
        return _failure(normalized_seed, "enemy_boss_party_missing")
    var selection_script: GDScript = load("res://Scripts/Run/run_enemy_boss_selection.gd")
    return selection_script.create(
        normalized_seed,
        enemy_clan_id,
        definition.boss_party_id
    )


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
            "enemy-clan-selection",
            constraint
        ),
    }
