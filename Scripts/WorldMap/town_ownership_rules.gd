class_name TownOwnershipRules
extends RefCounted

const PRE_HABITAT_WORLD_VERSION: int = 1
const GOBLIN_CLAN_ID: StringName = &"goblin"

static func resolve(plan: WorldPlan, coord: Vector2i) -> Dictionary:
    if not is_instance_valid(plan):
        return _failure(&"invalid_plan")
    if plan.get_version() != PRE_HABITAT_WORLD_VERSION:
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
    return {"ok": true, "clan_id": GOBLIN_CLAN_ID, "error": &""}

static func _failure(error: StringName) -> Dictionary:
    return {"ok": false, "clan_id": &"", "error": error}
