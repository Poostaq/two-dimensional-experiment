class_name WorldMoveResult
extends RefCounted

enum Status {
    ACCEPTED,
    REJECTED,
}

enum Rejection {
    NONE,
    INPUT_BLOCKED,
    INVALID_DESTINATION,
    NOT_ADJACENT,
    BOSS_ENCOUNTER_OPEN,
}

var status: Status
var rejection: Rejection
var snapshot: RefCounted
var previous_player_coord: Vector2i
var previous_boss_coord: Vector2i
var boss_moved: bool
var encounter_type: String


func _init(
    value_status: Status,
    value_rejection: Rejection,
    value_snapshot: RefCounted,
    previous_player: Vector2i,
    previous_boss: Vector2i,
    did_boss_move: bool,
    value_encounter_type: String
) -> void:
    status = value_status
    rejection = value_rejection
    snapshot = value_snapshot
    previous_player_coord = previous_player
    previous_boss_coord = previous_boss
    boss_moved = did_boss_move
    encounter_type = value_encounter_type


func is_accepted() -> bool:
    return status == Status.ACCEPTED
