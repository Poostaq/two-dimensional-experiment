class_name BattleActionLogEntry
extends RefCounted

var sequence_number: int
var round_number: int
var actor_id: StringName
var skill_id: StringName
var target_ids: Array[StringName]:
	get:
		return _target_ids.duplicate()
var damage_results: Array[BattleDamageResult]:
	get:
		return _damage_results.duplicate()
var speed_target_ids: Array[StringName]:
	get:
		return _speed_target_ids.duplicate()

var _target_ids: Array[StringName] = []
var _damage_results: Array[BattleDamageResult] = []
var _speed_target_ids: Array[StringName] = []


func _init(
	sequence: int,
	action_round: int,
	action_actor_id: StringName,
	action_skill_id: StringName,
	action_target_ids: Array[StringName],
	action_damage_results: Array[BattleDamageResult],
	action_speed_target_ids: Array[StringName]
) -> void:
	sequence_number = sequence
	round_number = action_round
	actor_id = action_actor_id
	skill_id = action_skill_id
	_target_ids = action_target_ids.duplicate()
	_damage_results = action_damage_results.duplicate()
	_speed_target_ids = action_speed_target_ids.duplicate()
