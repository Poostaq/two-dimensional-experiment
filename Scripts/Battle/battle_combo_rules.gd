class_name BattleComboRules
extends RefCounted

const RESULT_PATH := "res://Scripts/Battle/combo_condition_result.gd"
const EVALUATION_PATH := "res://Scripts/Battle/combo_evaluation.gd"


static func evaluate(
	definition: RefCounted,
	actor: BattleUnitState,
	target_ids: Array[StringName],
	current_round: int,
	history_snapshot: Array[BattleActionLogEntry]
) -> RefCounted:
	var evaluation_script: Script = load(EVALUATION_PATH)
	if not is_instance_valid(definition):
		return evaluation_script.new(false, false, [], [], 1)
	if not is_instance_valid(actor) or target_ids.size() != 1 or current_round <= 0:
		return evaluation_script.new(true, false, [], [], 2)
	var result_script: Script = load(RESULT_PATH)
	var results: Array[RefCounted] = []
	var all_passed: bool = true
	for condition: RefCounted in definition.conditions:
		if condition.condition_type != 0:
			return evaluation_script.new(true, false, results, [], 3)
		var passed: bool = _target_was_damaged_by_different_ally(
			actor, target_ids[0], current_round, history_snapshot
		)
		results.append(result_script.new(condition.condition_type, passed, target_ids if passed else []))
		all_passed = all_passed and passed
	if not all_passed:
		return evaluation_script.new(true, false, results, [], 0)
	var operations: Array[Dictionary] = []
	for effect: RefCounted in definition.bonus_effects:
		if effect.effect_type != 0:
			return evaluation_script.new(true, false, results, [], 4)
		operations.append({
			&"effect_type": effect.effect_type,
			&"magnitude": effect.magnitude,
			&"target_ids": target_ids.duplicate(),
		})
	return evaluation_script.new(true, true, results, operations, 0)


static func _target_was_damaged_by_different_ally(
	actor: BattleUnitState,
	target_id: StringName,
	current_round: int,
	history_snapshot: Array[BattleActionLogEntry]
) -> bool:
	for entry: BattleActionLogEntry in history_snapshot:
		if (
			not is_instance_valid(entry)
			or entry.round_number != current_round
			or entry.actor_side != actor.side
			or entry.actor_id == actor.unit_id
		):
			continue
		for result: BattleDamageResult in entry.damage_results:
			if result.receiver_id == target_id and result.applied_damage > 0:
				return true
	return false
