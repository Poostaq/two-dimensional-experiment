class_name EnemyBossPartyDefinition
extends RefCounted

var boss_party_id: StringName
var enemy_clan_id: StringName
var commander_id: StringName
var combo_id: StringName
var _member_class_ids: Array[StringName] = []


static func create(
    candidate_party_id: StringName,
    candidate_clan_id: StringName,
    candidate_commander_id: StringName,
    candidate_combo_id: StringName,
    candidate_member_class_ids: Array[StringName]
) -> Dictionary:
    if (
        candidate_party_id.is_empty()
        or candidate_clan_id.is_empty()
        or candidate_commander_id.is_empty()
        or candidate_combo_id.is_empty()
    ):
        return {"ok": false, "value": null, "error": &"blank_identity"}
    if (
        candidate_member_class_ids.size() != 4
        or candidate_member_class_ids.count(candidate_commander_id) != 1
    ):
        return {"ok": false, "value": null, "error": &"member_contract"}
    var seen: Array[StringName] = []
    for member_class_id: StringName in candidate_member_class_ids:
        if member_class_id.is_empty() or seen.has(member_class_id):
            return {"ok": false, "value": null, "error": &"duplicate_member"}
        seen.append(member_class_id)
    var definition: EnemyBossPartyDefinition = EnemyBossPartyDefinition.new()
    definition.boss_party_id = candidate_party_id
    definition.enemy_clan_id = candidate_clan_id
    definition.commander_id = candidate_commander_id
    definition.combo_id = candidate_combo_id
    definition._member_class_ids = candidate_member_class_ids.duplicate()
    return {"ok": true, "value": definition, "error": null}


func get_member_class_ids() -> Array[StringName]:
    return _member_class_ids.duplicate()
