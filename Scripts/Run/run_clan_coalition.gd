class_name RunClanCoalition
extends RefCounted

var main_clan_id: StringName
var allied_clan_ids: Array[StringName] = []


static func create(
    candidate_main_clan_id: StringName,
    candidate_allied_clan_ids: Array[StringName]
) -> Dictionary:
    var ordered_clans: Array[StringName] = RunCharacterCatalog.get_playable_clan_ids()
    if not ordered_clans.has(candidate_main_clan_id):
        return {"ok": false, "value": null, "error": "invalid_main_clan_id"}
    if candidate_allied_clan_ids.size() != 2:
        return {"ok": false, "value": null, "error": "ally_count"}
    var seen: Array[StringName] = [candidate_main_clan_id]
    var last_index: int = -1
    var has_synergy: bool = false
    for ally_id: StringName in candidate_allied_clan_ids:
        var index: int = ordered_clans.find(ally_id)
        if index < 0:
            return {"ok": false, "value": null, "error": "invalid_ally_id"}
        if seen.has(ally_id):
            return {"ok": false, "value": null, "error": "duplicate_ally_id"}
        if index <= last_index:
            return {"ok": false, "value": null, "error": "allies_out_of_order"}
        seen.append(ally_id)
        last_index = index
        has_synergy = has_synergy or RunCharacterCatalog.has_main_clan_synergy(
            candidate_main_clan_id, ally_id
        )
    if not has_synergy:
        return {"ok": false, "value": null, "error": "synergy_required"}
    var coalition: RunClanCoalition = RunClanCoalition.new()
    coalition.main_clan_id = candidate_main_clan_id
    coalition.allied_clan_ids = candidate_allied_clan_ids.duplicate()
    return {"ok": true, "value": coalition, "error": null}


func get_clan_ids() -> Array[StringName]:
    var result: Array[StringName] = [main_clan_id]
    result.append_array(allied_clan_ids)
    return result
