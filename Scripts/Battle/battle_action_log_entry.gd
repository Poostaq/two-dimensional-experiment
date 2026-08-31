class_name BattleActionLogEntry
extends RefCounted

var sequence_number: int
var round_number: int
var actor_id: StringName
var actor_side: BattleUnitState.Side
var skill_id: StringName
var target_ids: Array[StringName]:
	get:
		return _target_ids.duplicate()
var damage_results: Array[BattleDamageResult]:
	get:
		return _duplicate_damage_results()
var base_damage_by_target: Dictionary[StringName, int]:
	get:
		return _base_damage_by_target.duplicate()
var combo_bonus_damage_by_target: Dictionary[StringName, int]:
	get:
		return _combo_bonus_damage_by_target.duplicate()
var speed_target_ids: Array[StringName]:
	get:
		return _speed_target_ids.duplicate()
var combo_activated: bool

var _target_ids: Array[StringName] = []
var _damage_results: Array[BattleDamageResult] = []
var _base_damage_by_target: Dictionary[StringName, int] = {}
var _combo_bonus_damage_by_target: Dictionary[StringName, int] = {}
var _speed_target_ids: Array[StringName] = []
var _is_valid: bool = false


func _init(
	sequence: int,
	action_round: int,
	action_actor_id: StringName,
	action_actor_side: int,
	action_skill_id: StringName,
	action_target_ids: Array[StringName],
	action_damage_results: Array[BattleDamageResult],
	action_base_damage_by_target: Dictionary[StringName, int],
	action_combo_bonus_damage_by_target: Dictionary[StringName, int],
	action_speed_target_ids: Array[StringName],
	action_combo_activated: bool
) -> void:
	if not _valid_input(
		sequence,
		action_round,
		action_actor_id,
		action_actor_side,
		action_skill_id,
		action_target_ids,
		action_damage_results,
		action_base_damage_by_target,
		action_combo_bonus_damage_by_target
	):
		push_error("BattleActionLogEntry requires a valid immutable action contract.")
		return
	sequence_number = sequence
	round_number = action_round
	actor_id = action_actor_id
	actor_side = action_actor_side as BattleUnitState.Side
	skill_id = action_skill_id
	_target_ids = action_target_ids.duplicate()
	_damage_results = _copy_damage_results(action_damage_results)
	_base_damage_by_target = action_base_damage_by_target.duplicate()
	_combo_bonus_damage_by_target = action_combo_bonus_damage_by_target.duplicate()
	_speed_target_ids = action_speed_target_ids.duplicate()
	combo_activated = action_combo_activated
	_is_valid = true


func is_valid() -> bool:
	return _is_valid


func duplicate_entry() -> BattleActionLogEntry:
	if not _is_valid:
		return null
	return BattleActionLogEntry.new(
		sequence_number,
		round_number,
		actor_id,
		actor_side,
		skill_id,
		_target_ids,
		_damage_results,
		_base_damage_by_target,
		_combo_bonus_damage_by_target,
		_speed_target_ids,
		combo_activated
	)


static func _valid_input(
	sequence: int,
	action_round: int,
	action_actor_id: StringName,
	action_actor_side: int,
	action_skill_id: StringName,
	action_target_ids: Array[StringName],
	action_damage_results: Array[BattleDamageResult],
	action_base_damage_by_target: Dictionary[StringName, int],
	action_combo_bonus_damage_by_target: Dictionary[StringName, int]
) -> bool:
	if (
		sequence <= 0
		or action_round <= 0
		or String(action_actor_id).is_empty()
		or String(action_skill_id).is_empty()
		or action_actor_side not in [BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY]
	):
		return false
	var seen: Dictionary[StringName, bool] = {}
	for target_id: StringName in action_target_ids:
		if String(target_id).is_empty() or seen.has(target_id):
			return false
		seen[target_id] = true
	for key: StringName in action_base_damage_by_target:
		if not seen.has(key) or action_base_damage_by_target[key] < 0:
			return false
	for key: StringName in action_combo_bonus_damage_by_target:
		if not seen.has(key) or action_combo_bonus_damage_by_target[key] < 0:
			return false
	for result: BattleDamageResult in action_damage_results:
		if not is_instance_valid(result) or not seen.has(result.receiver_id):
			return false
		var base: int = action_base_damage_by_target.get(result.receiver_id, 0)
		var bonus: int = action_combo_bonus_damage_by_target.get(result.receiver_id, 0)
		if base + bonus != result.requested_damage:
			return false
	return true


func _duplicate_damage_results() -> Array[BattleDamageResult]:
	return _copy_damage_results(_damage_results)


static func _copy_damage_results(source: Array[BattleDamageResult]) -> Array[BattleDamageResult]:
	var result: Array[BattleDamageResult] = []
	for item: BattleDamageResult in source:
		result.append(BattleDamageResult.new(
			item.attacker_id,
			item.receiver_id,
			item.requested_damage,
			item.applied_damage,
			item.receiver_hp_after,
			item.caused_defeat,
			item.armor_prevented,
			item.was_direct_hit,
			item.is_status_damage
		))
	return result
