class_name RunEnemyBossSelection
extends RefCounted

var resolved_seed: String
var enemy_clan_id: StringName
var boss_party_id: StringName


static func create(
    candidate_resolved_seed: String,
    candidate_enemy_clan_id: StringName,
    candidate_boss_party_id: StringName
) -> Dictionary:
    var normalized_seed: String = candidate_resolved_seed.strip_edges()
    if normalized_seed.is_empty():
        return {"ok": false, "value": null, "error": "invalid_resolved_seed"}
    var definition: EnemyBossPartyDefinition = (
        BossPartyCatalog.get_definition_by_party_id(candidate_boss_party_id)
    )
    if (
        not is_instance_valid(definition)
        or definition.enemy_clan_id != candidate_enemy_clan_id
    ):
        return {"ok": false, "value": null, "error": "invalid_enemy_boss_party"}
    var selection: RunEnemyBossSelection = RunEnemyBossSelection.new()
    selection.resolved_seed = normalized_seed
    selection.enemy_clan_id = candidate_enemy_clan_id
    selection.boss_party_id = candidate_boss_party_id
    return {"ok": true, "value": selection, "error": null}
