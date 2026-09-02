class_name BattleFormationRules
extends RefCounted

const SLOT_COUNT: int = 6
const ROW_SIZE: int = 3


static func is_valid_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < SLOT_COUNT


static func is_front_slot(slot_index: int) -> bool:
	return is_valid_slot(slot_index) and slot_index < ROW_SIZE


static func is_back_slot(slot_index: int) -> bool:
	return is_valid_slot(slot_index) and slot_index >= ROW_SIZE


static func lane_of(slot_index: int) -> int:
	return slot_index % ROW_SIZE if is_valid_slot(slot_index) else -1


static func lane_distance(first_slot: int, second_slot: int) -> int:
	if not is_valid_slot(first_slot) or not is_valid_slot(second_slot):
		return -1
	return absi(lane_of(first_slot) - lane_of(second_slot))


static func closest_active_opponent(
	actor: BattleUnitState,
	units: Array[BattleUnitState]
) -> BattleUnitState:
	if (
		not is_instance_valid(actor)
		or not actor.is_active()
		or not is_valid_slot(actor.slot_index)
	):
		return null
	var winner: BattleUnitState = null
	for candidate: BattleUnitState in units:
		if (
			not is_instance_valid(candidate)
			or not candidate.is_active()
			or candidate.side == actor.side
			or not is_valid_slot(candidate.slot_index)
		):
			continue
		if not is_instance_valid(winner) or _opponent_comes_before(actor, candidate, winner):
			winner = candidate
	return winner


static func _opponent_comes_before(
	actor: BattleUnitState,
	first: BattleUnitState,
	second: BattleUnitState
) -> bool:
	var first_distance: int = lane_distance(actor.slot_index, first.slot_index)
	var second_distance: int = lane_distance(actor.slot_index, second.slot_index)
	if first_distance != second_distance:
		return first_distance < second_distance
	var first_row: int = 0 if is_front_slot(first.slot_index) else 1
	var second_row: int = 0 if is_front_slot(second.slot_index) else 1
	if first_row != second_row:
		return first_row < second_row
	if first.slot_index != second.slot_index:
		return first.slot_index < second.slot_index
	return String(first.unit_id) < String(second.unit_id)


static func is_move_one(from_slot: int, to_slot: int) -> bool:
	if not is_valid_slot(from_slot) or not is_valid_slot(to_slot) or from_slot == to_slot:
		return false
	var lane_delta: int = absi(lane_of(from_slot) - lane_of(to_slot))
	var row_changed: bool = is_front_slot(from_slot) != is_front_slot(to_slot)
	return (lane_delta == 1 and not row_changed) or (lane_delta == 0 and row_changed)
