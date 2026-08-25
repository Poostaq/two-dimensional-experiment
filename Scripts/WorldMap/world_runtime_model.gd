class_name WorldRuntimeModel
extends RefCounted

const SUDDEN_DEATH_THRESHOLD := 30

var _snapshot_script: GDScript = load("res://Scripts/WorldMap/world_runtime_snapshot.gd")
var _result_script: GDScript = load("res://Scripts/WorldMap/world_move_result.gd")

var _plan: WorldPlan
var _cells: Dictionary = {}
var _player_coord: Vector2i
var _boss_coord: Vector2i
var _move_count: int = 0
var _sudden_death_active: bool = false
var _input_blocked: bool = false
var _boss_encounter_open: bool = false


func configure(plan: WorldPlan) -> bool:
    if not is_instance_valid(plan) or WorldPlanCodecV1.validate(plan) != null:
        return false
    _plan = plan
    _cells = plan.get_cells()
    reset()
    return true


func get_snapshot() -> RefCounted:
    return _snapshot_script.new(
        _player_coord,
        _boss_coord,
        _move_count,
        _sudden_death_active,
        _input_blocked,
        _boss_encounter_open
    )


func set_surface_blocked(value: bool) -> void:
    _input_blocked = value


func get_valid_destinations() -> Array[Vector2i]:
    if not is_instance_valid(_plan) or _input_blocked or _boss_encounter_open:
        return []
    return HexWorldGeometry.get_neighbors(_player_coord)


func get_runtime_encounter_type(coord: Vector2i) -> String:
    if not _cells.has(coord):
        return ""
    if coord == _boss_coord:
        return "boss"
    if coord == _plan.get_boss_coord() and _boss_coord != coord:
        return "safe"
    return String(_cells[coord].get("encounter", "safe"))


func request_move(destination: Vector2i) -> RefCounted:
    if _boss_encounter_open:
        return _rejected(4)
    if _input_blocked:
        return _rejected(1)
    if not _cells.has(destination):
        return _rejected(2)
    if HexWorldGeometry.get_hex_distance(_player_coord, destination) != 1:
        return _rejected(3)

    var before := get_snapshot()
    var was_active := _sudden_death_active
    _player_coord = destination
    _move_count += 1
    if _player_coord == _boss_coord:
        return _accepted(before, false, "boss", true)
    if _move_count == SUDDEN_DEATH_THRESHOLD:
        _sudden_death_active = true
    if was_active:
        _boss_coord = _get_pursuit_step(_boss_coord, _player_coord)
        if _boss_coord == _player_coord:
            return _accepted(before, true, "boss", true)
    return _accepted(before, was_active, get_runtime_encounter_type(_player_coord), false)


func close_ordinary_encounter() -> void:
    if not _boss_encounter_open:
        _input_blocked = false


func reset() -> void:
    if not is_instance_valid(_plan):
        return
    _player_coord = _plan.get_start_coord()
    _boss_coord = _plan.get_boss_coord()
    _move_count = 0
    _sudden_death_active = false
    _input_blocked = false
    _boss_encounter_open = false


func _get_pursuit_step(from_coord: Vector2i, to_coord: Vector2i) -> Vector2i:
    var best_coord := from_coord
    var best_distance := HexWorldGeometry.get_hex_distance(from_coord, to_coord)
    for offset: Vector2i in HexMapModel.NEIGHBOR_OFFSETS:
        var candidate := from_coord + offset
        if not _cells.has(candidate):
            continue
        var distance := HexWorldGeometry.get_hex_distance(candidate, to_coord)
        if distance < best_distance:
            best_coord = candidate
            best_distance = distance
    return best_coord


func _accepted(
    before: RefCounted,
    boss_moved: bool,
    encounter_type: String,
    boss_open: bool
) -> RefCounted:
    _boss_encounter_open = boss_open
    _input_blocked = true
    return _result_script.new(
        0,
        0,
        get_snapshot(),
        before.get("player_coord"),
        before.get("boss_coord"),
        boss_moved,
        encounter_type
    )


func _rejected(rejection: int) -> RefCounted:
    return _result_script.new(
        1,
        rejection,
        get_snapshot(),
        _player_coord,
        _boss_coord,
        false,
        ""
    )
