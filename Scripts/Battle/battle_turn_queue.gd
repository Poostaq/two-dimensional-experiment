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
			print("BattleTurnQueue rejected: null unit")
			return []
		if unit.side != BattleUnitState.Side.PLAYER and unit.side != BattleUnitState.Side.ENEMY:
			print("BattleTurnQueue rejected: unit %s has invalid side %d" % [unit.unit_id, unit.side])
			return []
		var base_speed := unit.get_base_speed()
		if base_speed < MIN_SPEED or base_speed > MAX_SPEED:
			print("BattleTurnQueue rejected: unit %s has speed %d outside %d..%d" % [unit.unit_id, base_speed, MIN_SPEED, MAX_SPEED])
			return []
		if unit.slot_index < 0 or unit.slot_index >= SIDE_SLOT_COUNT:
			print("BattleTurnQueue rejected: unit %s has invalid slot %d" % [unit.unit_id, unit.slot_index])
			return []
		if unit.max_hp <= 0:
			print("BattleTurnQueue rejected: unit %s has invalid max HP %d" % [unit.unit_id, unit.max_hp])
			return []
		if unit.current_hp < 0 or unit.current_hp > unit.max_hp:
			print("BattleTurnQueue rejected: unit %s has invalid current HP %d/%d" % [unit.unit_id, unit.current_hp, unit.max_hp])
			return []
		var occupancy_key := Vector2i(unit.side, unit.slot_index)
		if occupied.has(occupancy_key):
			print("BattleTurnQueue rejected: duplicate side/slot %s" % occupancy_key)
			return []
		occupied[occupancy_key] = true
		if unit.is_active():
			ordered.append(unit)
	ordered.sort_custom(_comes_before)
	return ordered


static func _comes_before(first: BattleUnitState, second: BattleUnitState) -> bool:
	var first_speed := first.get_effective_speed()
	var second_speed := second.get_effective_speed()
	if first_speed != second_speed:
		return first_speed > second_speed
	if first.side != second.side:
		return first.side < second.side
	return first.slot_index < second.slot_index
