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
