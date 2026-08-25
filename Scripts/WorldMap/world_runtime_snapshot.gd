class_name WorldRuntimeSnapshot
extends RefCounted

var _player_coord: Vector2i
var _boss_coord: Vector2i
var _move_count: int
var _sudden_death_active: bool
var _input_blocked: bool
var _boss_encounter_open: bool

var player_coord: Vector2i:
    get:
        return _player_coord
var boss_coord: Vector2i:
    get:
        return _boss_coord
var move_count: int:
    get:
        return _move_count
var sudden_death_active: bool:
    get:
        return _sudden_death_active
var input_blocked: bool:
    get:
        return _input_blocked
var boss_encounter_open: bool:
    get:
        return _boss_encounter_open


func _init(
    player: Vector2i,
    boss: Vector2i,
    accepted_moves: int,
    sudden_death: bool,
    blocked: bool,
    boss_open: bool
) -> void:
    _player_coord = player
    _boss_coord = boss
    _move_count = accepted_moves
    _sudden_death_active = sudden_death
    _input_blocked = blocked
    _boss_encounter_open = boss_open


func duplicate_value() -> WorldRuntimeSnapshot:
    return get_script().new(
        player_coord,
        boss_coord,
        move_count,
        sudden_death_active,
        input_blocked,
        boss_encounter_open
    )


func canonical_key() -> String:
    return "%d,%d|%d,%d|%d|%d|%d|%d" % [
        player_coord.x,
        player_coord.y,
        boss_coord.x,
        boss_coord.y,
        move_count,
        int(sudden_death_active),
        int(input_blocked),
        int(boss_encounter_open),
    ]
