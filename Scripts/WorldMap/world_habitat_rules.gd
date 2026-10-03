class_name WorldHabitatRules
extends RefCounted

const PRE_HABITAT_WORLD_VERSION: int = 1
const GENERATED_HABITAT_WORLD_VERSION: int = 2
const INTERNAL_ROADS_WORLD_VERSION: int = 3
const GOBLIN_CLAN_ID: StringName = &"goblin"

static func resolve(plan: WorldPlan, coord: Vector2i) -> Dictionary:
    if not is_instance_valid(plan):
        return _failure(&"invalid_plan")
    var version: int = plan.get_version()
    if version not in [
        PRE_HABITAT_WORLD_VERSION,
        GENERATED_HABITAT_WORLD_VERSION,
        INTERNAL_ROADS_WORLD_VERSION,
    ]:
        return _failure(&"unsupported_world_version")
    var cells: Dictionary = plan.get_cells()
    if not cells.has(coord):
        return _failure(&"invalid_coordinate")
    var cell_value: Variant = cells[coord]
    if not cell_value is Dictionary:
        return _failure(&"invalid_cell_record")
    if version == PRE_HABITAT_WORLD_VERSION:
        return {
            "ok": true,
            "clan_id": GOBLIN_CLAN_ID,
            "display_name": "Goblin",
            "source": "Legacy world v1 rule",
            "habitat_id": &"",
            "error": &"",
        }
    return _resolve_generated(plan, cell_value)

static func _resolve_generated(plan: WorldPlan, cell: Dictionary) -> Dictionary:
    var habitat_id_value: Variant = cell.get("habitat_id")
    if not _is_string_value(habitat_id_value):
        return _failure(&"invalid_habitat_record")
    var habitat_id := String(habitat_id_value)
    if habitat_id.is_empty():
        return _failure(&"invalid_habitat_record")
    var matching: Array[Dictionary] = []
    for habitat_value: Variant in plan.get_habitats():
        if not habitat_value is Dictionary:
            continue
        var habitat: Dictionary = habitat_value
        if String(habitat.get("habitat_id", "")) == habitat_id:
            matching.append(habitat)
    if matching.size() != 1:
        return _failure(&"invalid_habitat_record")
    var habitat: Dictionary = matching[0]
    var clan_id_value: Variant = habitat.get("clan_id")
    var role_value: Variant = habitat.get("role")
    var anchor_value: Variant = habitat.get("anchor")
    if (
        not _is_string_value(clan_id_value)
        or String(clan_id_value).is_empty()
        or not _is_string_value(role_value)
        or String(role_value) not in ["main", "ally", "enemy"]
        or not anchor_value is Vector2i
    ):
        return _failure(&"invalid_habitat_record")
    var cell_count: int = plan.get_habitat_cells(habitat_id).size()
    if cell_count <= 0:
        return _failure(&"invalid_habitat_record")
    return {
        "ok": true,
        "clan_id": StringName(clan_id_value),
        "display_name": habitat_id.replace("_", " ").capitalize(),
        "source": "Generated world v2",
        "habitat_id": StringName(habitat_id),
        "role": String(role_value),
        "anchor": anchor_value,
        "cell_count": cell_count,
        "error": &"",
    }

static func _is_string_value(value: Variant) -> bool:
    return value is String or value is StringName

static func _failure(error: StringName) -> Dictionary:
    return {
        "ok": false,
        "clan_id": &"",
        "display_name": "",
        "source": "",
        "habitat_id": &"",
        "error": error,
    }
