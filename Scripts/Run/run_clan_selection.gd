class_name RunClanSelection
extends RefCounted

var main_clan_id: StringName
var commander_id: StringName
var seed_text: String


static func create(
    candidate_clan_id: StringName,
    candidate_commander_id: StringName,
    candidate_seed_text: String
) -> Dictionary:
    if (
        candidate_clan_id.is_empty()
        or not RunCharacterCatalog.get_playable_clans().has(candidate_clan_id)
    ):
        return {"ok": false, "value": null, "error": "invalid_main_clan_id"}
    if (
        candidate_commander_id.is_empty()
        or not RunCharacterCatalog.get_player_commander_ids_for_clan(candidate_clan_id).has(
            candidate_commander_id
        )
    ):
        return {"ok": false, "value": null, "error": "invalid_commander_id"}
    var selection: RunClanSelection = RunClanSelection.new()
    selection.main_clan_id = candidate_clan_id
    selection.commander_id = candidate_commander_id
    selection.seed_text = candidate_seed_text.strip_edges()
    return {"ok": true, "value": selection, "error": null}
