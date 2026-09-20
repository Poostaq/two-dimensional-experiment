class_name WorldHabitatRules
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
    if not cells[coord] is Dictionary:
        return _failure(&"invalid_cell_record")
    return {
        "ok": true,
        "clan_id": GOBLIN_CLAN_ID,
        "display_name": "Goblin",
        "source": "Legacy world v1 rule",
        "habitat_id": &"",
        "error": &"",
    }

static func _failure(error: StringName) -> Dictionary:
    return {
        "ok": false,
        "clan_id": &"",
        "display_name": "",
        "source": "",
        "habitat_id": &"",
        "error": error,
    }
