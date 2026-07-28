class_name BattleTargetSelector
extends RefCounted

const FRONT_COLUMN_END := 3


static func find_closest_enemy(
	attacker: BattleUnitState,
	units: Array[BattleUnitState]
) -> BattleUnitState:
	if not is_instance_valid(attacker) or not attacker.is_active():
		return null
	var candidates: Array[BattleUnitState] = []
	for unit: BattleUnitState in units:
		if (
			is_instance_valid(unit)
			and unit.is_active()
			and unit.side != attacker.side
			and (
				unit.side == BattleUnitState.Side.PLAYER
				or unit.side == BattleUnitState.Side.ENEMY
			)
		):
			candidates.append(unit)
	if candidates.is_empty():
		return null
	candidates.sort_custom(
		func(first: BattleUnitState, second: BattleUnitState) -> bool:
			return _comes_before(attacker, first, second)
	)
	return candidates[0]


static func _comes_before(
	attacker: BattleUnitState,
	first: BattleUnitState,
	second: BattleUnitState
) -> bool:
	var first_key: Vector3i = _target_key(attacker, first)
	var second_key: Vector3i = _target_key(attacker, second)
	if first_key.x != second_key.x:
		return first_key.x < second_key.x
	if first_key.y != second_key.y:
		return first_key.y < second_key.y
	return first_key.z < second_key.z


static func _target_key(attacker: BattleUnitState, target: BattleUnitState) -> Vector3i:
	var attacker_row := attacker.slot_index % 3
	var target_row := target.slot_index % 3
	var row_distance := absi(target_row - attacker_row)
	var column_priority := 0 if target.slot_index < FRONT_COLUMN_END else 1
	return Vector3i(row_distance, column_priority, target.slot_index)
