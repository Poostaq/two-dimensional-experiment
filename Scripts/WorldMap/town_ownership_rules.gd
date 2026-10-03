class_name TownOwnershipRules
extends RefCounted

const PRE_HABITAT_WORLD_VERSION: int = 1
const GENERATED_HABITAT_WORLD_VERSION: int = 2
const GOBLIN_CLAN_ID: StringName = &"goblin"

static func resolve(plan: WorldPlan, coord: Vector2i) -> Dictionary:
    if not is_instance_valid(plan):
        return _failure(&"invalid_plan")
    var version: int = plan.get_version()
    if version != PRE_HABITAT_WORLD_VERSION and version != GENERATED_HABITAT_WORLD_VERSION:
        return _failure(&"unsupported_world_version")
    var cells: Dictionary = plan.get_cells()
    if not cells.has(coord):
        return _failure(&"invalid_coordinate")
    var cell: Variant = cells[coord]
    if not cell is Dictionary:
        return _failure(&"invalid_town_record")
    var index: Variant = cell.get("town_index")
    if not index is int:
        return _failure(&"invalid_town_record")
    if index < -1:
        return _failure(&"invalid_town_record")
    if index == -1:
        return _failure(&"not_a_town")
    var habitat_rules: GDScript = load("res://Scripts/WorldMap/world_habitat_rules.gd")
    var habitat: Dictionary = habitat_rules.resolve(plan, coord)
    if not habitat.ok:
        return _failure(habitat.error)
    if version == PRE_HABITAT_WORLD_VERSION:
        return {"ok": true, "clan_id": habitat.clan_id, "error": &""}
    if index > 8:
        return _failure(&"invalid_town_record")
    var towns: Array = plan.get_towns()
    if index >= towns.size() or not towns[index] is Dictionary:
        return _failure(&"invalid_town_record")
    var town: Dictionary = towns[index]
    var town_id_value: Variant = town.get("town_id")
    var habitat_id_value: Variant = town.get("habitat_id")
    var local_index_value: Variant = town.get("local_index")
    var town_coord_value: Variant = town.get("coord")
    if (
        not _is_string_value(town_id_value)
        or String(town_id_value).is_empty()
        or not _is_string_value(habitat_id_value)
        or String(habitat_id_value) != String(habitat.habitat_id)
        or not local_index_value is int
        or int(local_index_value) < 0
        or int(local_index_value) > 2
        or int(local_index_value) != index % 3
        or not town_coord_value is Vector2i
        or town_coord_value != coord
        or String(town_id_value) != "%s_town_%d" % [String(habitat_id_value), int(local_index_value)]
    ):
        return _failure(&"invalid_town_record")
    if habitat.role == "enemy":
        return _failure(&"enemy_town_owner")
    return {
        "ok": true,
        "clan_id": habitat.clan_id,
        "display_name": habitat.display_name,
        "source": habitat.source,
        "habitat_id": habitat.habitat_id,
        "role": habitat.role,
        "anchor": habitat.anchor,
        "cell_count": habitat.cell_count,
        "town_id": StringName(town_id_value),
        "local_index": int(local_index_value),
        "error": &"",
    }

static func _is_string_value(value: Variant) -> bool:
    return value is String or value is StringName

static func _failure(error: StringName) -> Dictionary:
    return {"ok": false, "clan_id": &"", "error": error}
