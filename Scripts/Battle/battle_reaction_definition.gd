class_name BattleReactionDefinition
extends RefCounted

enum Trigger {
	DIRECT_HIT,
	FORCED_MOVEMENT,
	ACTION_START,
	ACTION_END,
}

enum TargetPolicy {
	CLOSEST_OPPONENT,
	ADJACENT_ALLY,
	OWNER_AND_ADJACENT_ALLY,
	OWNER_AND_ALL_ADJACENT_ALLIES,
}

enum Frequency {
	ONCE_PER_ACTION,
	ONCE_PER_ROUND,
	ONCE_PER_BATTLE,
}

var passive_skill_id: StringName:
	get:
		return _passive_skill_id
var trigger: Trigger:
	get:
		return _trigger
var frequency: Frequency:
	get:
		return _frequency
var priority: int:
	get:
		return _priority
var operation: RefCounted:
	get:
		return _operation.call("duplicate_operation") if is_instance_valid(_operation) else null
var allow_reaction_chain: bool:
	get:
		return _allow_reaction_chain
var target_policy: TargetPolicy:
	get:
		return _target_policy
var owner_unit_id: StringName:
	get:
		return _owner_unit_id

var _passive_skill_id: StringName = &""
var _trigger: Trigger = Trigger.DIRECT_HIT
var _frequency: Frequency = Frequency.ONCE_PER_ACTION
var _priority: int = 0
var _operation: RefCounted = null
var _allow_reaction_chain: bool = false
var _target_policy: TargetPolicy = TargetPolicy.CLOSEST_OPPONENT
var _owner_unit_id: StringName = &""


func _init(
	definition_passive_skill_id: StringName,
	definition_trigger: int,
	definition_frequency: int,
	definition_priority: int,
	definition_operation: RefCounted,
	definition_allow_reaction_chain: bool = false,
	definition_owner_unit_id: StringName = &"",
	definition_target_policy: int = TargetPolicy.CLOSEST_OPPONENT
) -> void:
	if not _is_valid_input(
		definition_passive_skill_id,
		definition_trigger,
		definition_frequency,
		definition_operation,
		definition_target_policy
	):
		push_error("BattleReactionDefinition requires valid passive, trigger, frequency, and operation data.")
		return
	_passive_skill_id = definition_passive_skill_id
	_trigger = definition_trigger as Trigger
	_frequency = definition_frequency as Frequency
	_priority = definition_priority
	_operation = definition_operation.call("duplicate_operation")
	_allow_reaction_chain = definition_allow_reaction_chain
	_target_policy = definition_target_policy as TargetPolicy
	_owner_unit_id = definition_owner_unit_id


static func create(
	definition_passive_skill_id: StringName,
	definition_trigger: int,
	definition_frequency: int,
	definition_priority: int,
	definition_operation: RefCounted,
	definition_allow_reaction_chain: bool = false,
	definition_owner_unit_id: StringName = &"",
	definition_target_policy: int = TargetPolicy.CLOSEST_OPPONENT
) -> RefCounted:
	var definition: RefCounted = load("res://Scripts/Battle/battle_reaction_definition.gd").new(
		definition_passive_skill_id,
		definition_trigger,
		definition_frequency,
		definition_priority,
		definition_operation,
		definition_allow_reaction_chain,
		definition_owner_unit_id,
		definition_target_policy
	)
	return definition if definition.is_valid() else null


func is_valid() -> bool:
	return not _passive_skill_id.is_empty() and is_instance_valid(_operation)


func duplicate_definition() -> RefCounted:
	if not is_valid():
		return null
	var definition_script := load("res://Scripts/Battle/battle_reaction_definition.gd") as Script
	return definition_script.call(
		"create",
		_passive_skill_id,
		_trigger,
		_frequency,
		_priority,
		_operation,
		_allow_reaction_chain,
		_owner_unit_id,
		_target_policy
	)


func with_owner(unit_id: StringName) -> RefCounted:
	if unit_id.is_empty() or not is_valid():
		return null
	var definition_script := load("res://Scripts/Battle/battle_reaction_definition.gd") as Script
	return definition_script.call(
		"create",
		_passive_skill_id,
		_trigger,
		_frequency,
		_priority,
		_operation,
		_allow_reaction_chain,
		unit_id,
		_target_policy
	)


func with_owner_and_operation(
	unit_id: StringName,
	resolved_operation: RefCounted
) -> RefCounted:
	if (
		unit_id.is_empty()
		or not is_valid()
		or not is_instance_valid(resolved_operation)
		or not resolved_operation.has_method("is_valid")
		or not resolved_operation.has_method("duplicate_operation")
		or not resolved_operation.call("is_valid")
	):
		return null
	var definition_script: Script = load("res://Scripts/Battle/battle_reaction_definition.gd") as Script
	return definition_script.call(
		"create",
		_passive_skill_id,
		_trigger,
		_frequency,
		_priority,
		resolved_operation,
		_allow_reaction_chain,
		unit_id,
		_target_policy
	)


static func _is_valid_input(
	definition_passive_skill_id: StringName,
	definition_trigger: int,
	definition_frequency: int,
	definition_operation: RefCounted,
	definition_target_policy: int
) -> bool:
	return (
		not definition_passive_skill_id.is_empty()
		and definition_trigger in [Trigger.DIRECT_HIT, Trigger.FORCED_MOVEMENT, Trigger.ACTION_START, Trigger.ACTION_END]
		and definition_target_policy in [
			TargetPolicy.CLOSEST_OPPONENT,
			TargetPolicy.ADJACENT_ALLY,
			TargetPolicy.OWNER_AND_ADJACENT_ALLY,
			TargetPolicy.OWNER_AND_ALL_ADJACENT_ALLIES,
		]
		and definition_frequency in [Frequency.ONCE_PER_ACTION, Frequency.ONCE_PER_ROUND, Frequency.ONCE_PER_BATTLE]
		and is_instance_valid(definition_operation)
		and definition_operation.has_method("is_valid")
		and definition_operation.has_method("duplicate_operation")
		and definition_operation.call("is_valid")
	)
