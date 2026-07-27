class_name BattleTurnQueue
extends RefCounted

const MIN_SPEED := 1
const MAX_SPEED := 10
const SIDE_SLOT_COUNT := 6


static func build(units: Array[BattleUnitState]) -> Array[BattleUnitState]:
	var ordered: Array[BattleUnitState] = []
	var occupied: Dictionary = {}
	for unit: BattleUnitState in units:
		if not is_instance_valid(unit):
			push_error("Battle turn queue contains a null unit")
			return []
		if unit.side != BattleUnitState.Side.PLAYER and unit.side != BattleUnitState.Side.ENEMY:
			push_error("Battle unit %s has invalid side %d" % [unit.unit_id, unit.side])
			return []
		if unit.speed < MIN_SPEED or unit.speed > MAX_SPEED:
			push_error("Battle unit %s has speed %d outside %d..%d" % [unit.unit_id, unit.speed, MIN_SPEED, MAX_SPEED])
			return []
		if unit.slot_index < 0 or unit.slot_index >= SIDE_SLOT_COUNT:
			push_error("Battle unit %s has invalid slot %d" % [unit.unit_id, unit.slot_index])
			return []
		var occupancy_key := Vector2i(unit.side, unit.slot_index)
		if occupied.has(occupancy_key):
			push_error("Battle turn queue has duplicate side/slot %s" % occupancy_key)
			return []
		occupied[occupancy_key] = true
		ordered.append(unit)
	ordered.sort_custom(_comes_before)
	return ordered


static func _comes_before(first: BattleUnitState, second: BattleUnitState) -> bool:
	if first.speed != second.speed:
		return first.speed > second.speed
	if first.side != second.side:
		return first.side < second.side
	return first.slot_index < second.slot_index
