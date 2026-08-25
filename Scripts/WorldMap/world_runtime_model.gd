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


func request_move(destination: Vector2i) -> RefCounted:
    if _boss_encounter_open:
        return _rejected(4)
    if _input_blocked:
        return _rejected(1)
    if not _cells.has(destination):
        return _rejected(2)
    return _rejected(3)


func reset() -> void:
    if not is_instance_valid(_plan):
        return
    _player_coord = _plan.get_start_coord()
    _boss_coord = _plan.get_boss_coord()
    _move_count = 0
    _sudden_death_active = false
    _input_blocked = false
    _boss_encounter_open = false


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
