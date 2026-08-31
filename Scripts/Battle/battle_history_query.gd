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


static func consumed_advantage_this_round(
	records: Array[BattleActionRecord],
	actor_id: StringName,
	round_number: int
) -> bool:
	if actor_id.is_empty() or round_number < 1:
		return false
	for record: BattleActionRecord in records:
		if (
			is_instance_valid(record)
			and record.is_valid()
			and not record.is_reaction
			and record.round_number == round_number
			and record.actor_id == actor_id
			and is_instance_valid(record.advantage_consumed)
		):
			return true
	return false


static func ally_acted_before_this_round(
	records: Array[BattleActionRecord],
	actor_side: BattleUnitState.Side,
	excluded_actor_id: StringName,
	round_number: int
) -> bool:
	if excluded_actor_id.is_empty() or round_number < 1:
		return false
	for record: BattleActionRecord in records:
		if (
			is_instance_valid(record)
			and record.is_valid()
			and not record.is_reaction
			and record.round_number == round_number
			and record.actor_side == actor_side
			and record.actor_id != excluded_actor_id
		):
			return true
	return false


static func was_directly_hit_by_ally_this_round(
	records: Array[BattleActionRecord],
	attacker_side: BattleUnitState.Side,
	target_id: StringName,
	excluded_actor_id: StringName,
	round_number: int
) -> bool:
	return not distinct_allied_attackers_this_round(
		records, attacker_side, target_id, excluded_actor_id, round_number
	).is_empty()


static func distinct_allied_attackers_this_round(
	records: Array[BattleActionRecord],
	attacker_side: BattleUnitState.Side,
	target_id: StringName,
	excluded_actor_id: StringName,
	round_number: int
) -> Array[StringName]:
	var attackers: Array[StringName] = []
	if target_id.is_empty() or excluded_actor_id.is_empty() or round_number < 1:
		return attackers
	var seen: Dictionary[StringName, bool] = {}
	for record: BattleActionRecord in records:
		if (
			not is_instance_valid(record)
			or not record.is_valid()
			or record.is_reaction
			or record.round_number != round_number
			or record.actor_side != attacker_side
			or record.actor_id == excluded_actor_id
			or not record.direct_hit_by_target.get(target_id, false)
			or int(record.damage_by_target.get(target_id, 0)) <= 0
			or seen.has(record.actor_id)
		):
			continue
		seen[record.actor_id] = true
		attackers.append(record.actor_id)
	return attackers


static func _is_relevant_record(record: BattleActionRecord, marker_sequence: int) -> bool:
	return is_instance_valid(record) and record.is_valid() and record.sequence_number > marker_sequence
