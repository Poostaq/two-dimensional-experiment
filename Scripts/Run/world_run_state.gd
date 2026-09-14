class_name WorldRunState
extends RefCounted

const FORMATION_SLOT_COUNT := 6

static var PREPARATION_RECORD_SCRIPT: GDScript = load(
	"res://Scripts/Battle/battle_preparation_record.gd"
)

var player_coord: Vector2i
var boss_coord: Vector2i
var move_count: int
var boss_active: bool
var boss_engaged: bool
var consumed_encounters: Array[Vector2i] = []
var formation: Array[StringName] = []
var cache_move_progress: int = 0
var cache_ready: bool = false
var battle_preparation: RefCounted
var _character_hp: Dictionary[StringName, int] = {}


static func create(
    new_player_coord: Vector2i,
    new_boss_coord: Vector2i,
    new_move_count: int,
    new_boss_active: bool,
    new_boss_engaged: bool,
    new_consumed_encounters: Array[Vector2i],
    new_formation: Array[StringName],
    new_cache_move_progress: int = 0,
    new_cache_ready: bool = false,
    new_battle_preparation: RefCounted = null
) -> RefCounted:
    if new_move_count < 0 or (new_boss_active and new_move_count < 30):
        return null
    if new_cache_move_progress < 0 or new_cache_move_progress > 3:
        return null
    var preparation: RefCounted = new_battle_preparation
    if not is_instance_valid(preparation):
        preparation = PREPARATION_RECORD_SCRIPT.none()
    if not is_instance_valid(preparation) or not preparation.call("is_valid"):
        return null
    var preparation_state: int = int(preparation.get("state"))
    if (
        preparation_state == PREPARATION_RECORD_SCRIPT.State.OFFERED
        and not new_cache_ready
    ):
        return null
    if (
        preparation_state == PREPARATION_RECORD_SCRIPT.State.COMMITTED
        and new_cache_ready
    ):
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
    state.cache_move_progress = new_cache_move_progress
    state.cache_ready = new_cache_ready
    var preparation_copy: Dictionary = PREPARATION_RECORD_SCRIPT.from_dictionary(
        preparation.call("to_dictionary")
    )
    if not bool(preparation_copy.get("ok", false)):
        return null
    state.battle_preparation = preparation_copy["value"]
    return state


static func from_dictionary(value: Dictionary, plan: WorldPlan) -> Dictionary:
    var player_result := _decode_coord(value.get("player_coord"))
    var boss_result := _decode_coord(value.get("boss_coord"))
    if not player_result.get("ok", false) or not boss_result.get("ok", false):
        return {"ok": false}
    var consumed_result := _decode_consumed(value.get("consumed_encounters"))
    var formation_result := _decode_formation(value.get("formation"))
    var health_result := _decode_character_hp(value.get("character_hp", {}))
    var preparation_result: Dictionary = PREPARATION_RECORD_SCRIPT.from_dictionary(
        value.get("battle_preparation", {"state": "none"})
    )
    if (
        not consumed_result.get("ok", false)
        or not formation_result.get("ok", false)
        or not health_result.get("ok", false)
        or not preparation_result.get("ok", false)
    ):
        return {"ok": false}
    var state := create(
        player_result["coord"],
        boss_result["coord"],
        int(value.get("move_count", -1)),
        bool(value.get("boss_active", false)),
        bool(value.get("boss_engaged", false)),
        consumed_result["coords"],
        formation_result["slots"],
        int(value.get("cache_move_progress", 0)),
        bool(value.get("cache_ready", false)),
        preparation_result["value"]
    )
    if not is_instance_valid(state) or not state.is_valid(plan):
        return {"ok": false}
    if not state.set_character_hp_snapshot(health_result["health"]):
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


func get_character_hp_snapshot() -> Dictionary[StringName, int]:
    var snapshot: Dictionary[StringName, int] = {}
    for character_id: StringName in _character_hp:
        snapshot[character_id] = _character_hp[character_id]
    return snapshot


func set_character_hp_snapshot(candidate: Dictionary[StringName, int]) -> bool:
    var snapshot: Dictionary[StringName, int] = {}
    for character_id: StringName in candidate:
        var hp: int = candidate[character_id]
        if character_id.is_empty() or hp < 1:
            return false
        snapshot[character_id] = hp
    _character_hp = snapshot
    return true


func to_dictionary() -> Dictionary:
    var consumed: Array[Array] = []
    for coord: Vector2i in consumed_encounters:
        consumed.append([coord.x, coord.y])
    var slot_ids: Array[String] = []
    for character_id: StringName in formation:
        slot_ids.append(String(character_id))
    var health_ids: Array[String] = []
    for character_id: StringName in _character_hp:
        health_ids.append(String(character_id))
    health_ids.sort()
    var serialized_health: Dictionary = {}
    for character_id: String in health_ids:
        serialized_health[character_id] = _character_hp[StringName(character_id)]
    return {
        "player_coord": [player_coord.x, player_coord.y],
        "boss_coord": [boss_coord.x, boss_coord.y],
        "move_count": move_count,
        "boss_active": boss_active,
        "boss_engaged": boss_engaged,
        "consumed_encounters": consumed,
        "formation": slot_ids,
        "character_hp": serialized_health,
        "cache_move_progress": cache_move_progress,
        "cache_ready": cache_ready,
        "battle_preparation": battle_preparation.call("to_dictionary"),
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


static func _decode_character_hp(value: Variant) -> Dictionary:
    if not value is Dictionary:
        return {"ok": false}
    var health: Dictionary[StringName, int] = {}
    for character_id: Variant in value:
        if not character_id is String or String(character_id).is_empty():
            return {"ok": false}
        var hp: Variant = value[character_id]
        if (not hp is int and not hp is float) or float(hp) != floorf(float(hp)) or int(hp) < 1:
            return {"ok": false}
        health[StringName(character_id)] = int(hp)
    return {"ok": true, "health": health}


static func _decode_formation(value: Variant) -> Dictionary:
    if not value is Array or value.size() != FORMATION_SLOT_COUNT:
        return {"ok": false}
    var slots: Array[StringName] = []
    for item: Variant in value:
        if not item is String:
            return {"ok": false}
        slots.append(StringName(item))
    return {"ok": true, "slots": slots}
