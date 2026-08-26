class_name WorldRunState
extends RefCounted

const FORMATION_SLOT_COUNT := 6

var player_coord: Vector2i
var boss_coord: Vector2i
var move_count: int
var boss_active: bool
var boss_engaged: bool
var consumed_encounters: Array[Vector2i] = []
var formation: Array[StringName] = []


static func create(
    new_player_coord: Vector2i,
    new_boss_coord: Vector2i,
    new_move_count: int,
    new_boss_active: bool,
    new_boss_engaged: bool,
    new_consumed_encounters: Array[Vector2i],
    new_formation: Array[StringName]
) -> RefCounted:
    if new_move_count < 0 or (new_boss_active and new_move_count < 30):
        return null
    if new_formation.size() != FORMATION_SLOT_COUNT:
        return null
    var occupied: Dictionary = {}
    for character_id: StringName in new_formation:
        if character_id.is_empty():
            continue
        if occupied.has(character_id):
            return null
        occupied[character_id] = true
    var state_script: GDScript = load("res://Scripts/Run/world_run_state.gd")
    var state: RefCounted = state_script.new()
    state.player_coord = new_player_coord
    state.boss_coord = new_boss_coord
    state.move_count = new_move_count
    state.boss_active = new_boss_active
    state.boss_engaged = new_boss_engaged
    state.consumed_encounters = new_consumed_encounters.duplicate()
    state.formation = new_formation.duplicate()
    return state


static func from_dictionary(value: Dictionary, plan: WorldPlan) -> Dictionary:
    var player_result := _decode_coord(value.get("player_coord"))
    var boss_result := _decode_coord(value.get("boss_coord"))
    if not player_result.get("ok", false) or not boss_result.get("ok", false):
        return {"ok": false}
    var consumed_result := _decode_consumed(value.get("consumed_encounters"))
    var formation_result := _decode_formation(value.get("formation"))
    if not consumed_result.get("ok", false) or not formation_result.get("ok", false):
        return {"ok": false}
    var state := create(
        player_result["coord"],
        boss_result["coord"],
        int(value.get("move_count", -1)),
        bool(value.get("boss_active", false)),
        bool(value.get("boss_engaged", false)),
        consumed_result["coords"],
        formation_result["slots"]
    )
    if not is_instance_valid(state) or not state.is_valid(plan):
        return {"ok": false}
    return {"ok": true, "value": state}


func is_valid(plan: WorldPlan) -> bool:
    if not is_instance_valid(plan):
        return false
    var cells := plan.get_cells()
    if not cells.has(player_coord) or not cells.has(boss_coord):
        return false
    for coord: Vector2i in consumed_encounters:
        if not cells.has(coord):
            return false
    return true


func to_dictionary() -> Dictionary:
    var consumed: Array[Array] = []
    for coord: Vector2i in consumed_encounters:
        consumed.append([coord.x, coord.y])
    var slot_ids: Array[String] = []
    for character_id: StringName in formation:
        slot_ids.append(String(character_id))
    return {
        "player_coord": [player_coord.x, player_coord.y],
        "boss_coord": [boss_coord.x, boss_coord.y],
        "move_count": move_count,
        "boss_active": boss_active,
        "boss_engaged": boss_engaged,
        "consumed_encounters": consumed,
        "formation": slot_ids,
    }


func canonical_key() -> String:
    return JSON.stringify(to_dictionary())


static func _decode_coord(value: Variant) -> Dictionary:
    if not value is Array or value.size() != 2:
        return {"ok": false}
    if (not value[0] is int and not value[0] is float) or (not value[1] is int and not value[1] is float):
        return {"ok": false}
    return {"ok": true, "coord": Vector2i(int(value[0]), int(value[1]))}


static func _decode_consumed(value: Variant) -> Dictionary:
    if not value is Array:
        return {"ok": false}
    var coords: Array[Vector2i] = []
    for item: Variant in value:
        var result := _decode_coord(item)
        if not result.get("ok", false):
            return {"ok": false}
        coords.append(result["coord"])
    return {"ok": true, "coords": coords}


static func _decode_formation(value: Variant) -> Dictionary:
    if not value is Array or value.size() != FORMATION_SLOT_COUNT:
        return {"ok": false}
    var slots: Array[StringName] = []
    for item: Variant in value:
        if not item is String:
            return {"ok": false}
        slots.append(StringName(item))
    return {"ok": true, "slots": slots}
