class_name BattleHistoryQuery
extends RefCounted


static func was_forced_moved_since(
	records: Array[BattleActionRecord],
	unit_id: StringName,
	marker_sequence: int
) -> bool:
	if unit_id.is_empty() or marker_sequence < 0:
		return false
	for record: BattleActionRecord in records:
		if not _is_relevant_record(record, marker_sequence):
			continue
		if record.voluntary_movement:
			continue
		if not record.slot_before_by_unit.has(unit_id) or not record.slot_after_by_unit.has(unit_id):
			continue
		if record.slot_before_by_unit[unit_id] != record.slot_after_by_unit[unit_id]:
			return true
	return false


static func distinct_allied_attackers(
	records: Array[BattleActionRecord],
	attacker_side: BattleUnitState.Side,
	target_id: StringName,
	marker_sequence: int
) -> Array[StringName]:
	var attackers: Array[StringName] = []
	if target_id.is_empty() or marker_sequence < 0:
		return attackers
	var seen: Dictionary[StringName, bool] = {}
	for record: BattleActionRecord in records:
		if not _is_relevant_record(record, marker_sequence):
			continue
		if record.actor_side != attacker_side or record.is_reaction:
			continue
		if not record.direct_hit_by_target.get(target_id, false):
			continue
		if int(record.damage_by_target.get(target_id, 0)) <= 0:
			continue
		if seen.has(record.actor_id):
			continue
		seen[record.actor_id] = true
		attackers.append(record.actor_id)
	return attackers


static func _is_relevant_record(record: BattleActionRecord, marker_sequence: int) -> bool:
	return is_instance_valid(record) and record.is_valid() and record.sequence_number > marker_sequence
