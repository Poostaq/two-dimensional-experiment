class_name SkillEffectPlan
extends RefCounted

const DAMAGE_KEYS: Array[StringName] = [
	&"target_id",
	&"base_damage",
	&"combo_bonus_damage",
	&"total_requested_damage",
]

var actor_id: StringName
var skill_id: StringName
var target_ids: Array[StringName]:
	get:
		return _target_ids.duplicate()
var damage_operations: Array[Dictionary]:
	get:
		return _damage_operations.duplicate(true)
var speed_operations: Array[Dictionary]:
	get:
		return _speed_operations.duplicate(true)
var keyword_operations: Array[RefCounted]:
	get:
		return _duplicate_keyword_operations(_keyword_operations)
var locked_advantage_source: RefCounted:
	get:
		return _locked_advantage_source.call("duplicate_source") if is_instance_valid(_locked_advantage_source) else null
var advantage_rider: RefCounted:
	get:
		return _advantage_rider.call("duplicate_operation") if is_instance_valid(_advantage_rider) else null
var cooldown_actions: int
var advance_turn: bool
var battle_revision: int

var _target_ids: Array[StringName] = []
var _damage_operations: Array[Dictionary] = []
var _speed_operations: Array[Dictionary] = []
var _keyword_operations: Array[RefCounted] = []
var _locked_advantage_source: RefCounted = null
var _advantage_rider: RefCounted = null
var _is_valid: bool = false


func _init(
	plan_actor_id: StringName,
	plan_skill_id: StringName,
	plan_target_ids: Array[StringName],
	plan_damage_operations: Array[Dictionary],
	plan_speed_operations: Array[Dictionary],
	plan_cooldown_actions: int,
	plan_advance_turn: bool,
	plan_battle_revision: int,
	plan_keyword_operations: Array[RefCounted] = [],
	plan_locked_advantage_source: RefCounted = null,
	plan_advantage_rider: RefCounted = null
) -> void:
	if not _valid_input(
		plan_actor_id,
		plan_skill_id,
		plan_target_ids,
		plan_damage_operations,
		plan_keyword_operations,
		plan_locked_advantage_source,
		plan_advantage_rider,
		plan_cooldown_actions,
		plan_battle_revision
	):
		push_error("SkillEffectPlan requires valid targets and effect operations.")
		return
	actor_id = plan_actor_id
	skill_id = plan_skill_id
	_target_ids = plan_target_ids.duplicate()
	_damage_operations = plan_damage_operations.duplicate(true)
	_speed_operations = plan_speed_operations.duplicate(true)
	_keyword_operations = _duplicate_keyword_operations(plan_keyword_operations)
	_locked_advantage_source = (
		plan_locked_advantage_source.call("duplicate_source")
		if is_instance_valid(plan_locked_advantage_source)
		else null
	)
	_advantage_rider = (
		plan_advantage_rider.call("duplicate_operation")
		if is_instance_valid(plan_advantage_rider)
		else null
	)
	cooldown_actions = plan_cooldown_actions
	advance_turn = plan_advance_turn
	battle_revision = plan_battle_revision
	_is_valid = true


static func create(
	plan_actor_id: StringName,
	plan_skill_id: StringName,
	plan_target_ids: Array[StringName],
	plan_damage_operations: Array[Dictionary],
	plan_speed_operations: Array[Dictionary],
	plan_cooldown_actions: int,
	plan_advance_turn: bool,
	plan_battle_revision: int,
	plan_keyword_operations: Array[RefCounted] = [],
	plan_locked_advantage_source: RefCounted = null,
	plan_advantage_rider: RefCounted = null
) -> SkillEffectPlan:
	var plan: SkillEffectPlan = SkillEffectPlan.new(
		plan_actor_id,
		plan_skill_id,
		plan_target_ids,
		plan_damage_operations,
		plan_speed_operations,
		plan_cooldown_actions,
		plan_advance_turn,
		plan_battle_revision,
		plan_keyword_operations,
		plan_locked_advantage_source,
		plan_advantage_rider
	)
	return plan if plan.is_valid() else null


func is_valid() -> bool:
	return _is_valid


static func _valid_input(
	plan_actor_id: StringName,
	plan_skill_id: StringName,
	plan_target_ids: Array[StringName],
	plan_damage_operations: Array[Dictionary],
	plan_keyword_operations: Array[RefCounted],
	plan_locked_advantage_source: RefCounted,
	plan_advantage_rider: RefCounted,
	plan_cooldown_actions: int,
	plan_battle_revision: int
) -> bool:
	if (
		String(plan_actor_id).is_empty()
		or String(plan_skill_id).is_empty()
		or plan_target_ids.is_empty()
		or plan_cooldown_actions < 0
		or plan_battle_revision < 0
	):
		return false
	if not _valid_damage_operations(plan_target_ids, plan_damage_operations):
		return false
	if not _valid_keyword_operations(plan_actor_id, plan_target_ids, plan_keyword_operations):
		return false
	if is_instance_valid(plan_locked_advantage_source) and not _is_valid_keyword_source(plan_locked_advantage_source):
		return false
	if is_instance_valid(plan_advantage_rider) and not _is_valid_keyword_operation(plan_advantage_rider):
		return false
	return true


static func _valid_damage_operations(
	plan_target_ids: Array[StringName],
	plan_damage_operations: Array[Dictionary]
) -> bool:
	for operation: Dictionary in plan_damage_operations:
		if operation.size() != DAMAGE_KEYS.size():
			return false
		for key: StringName in DAMAGE_KEYS:
			if not operation.has(key):
				return false
		var target_id: StringName = operation[&"target_id"]
		var base: int = int(operation[&"base_damage"])
		var bonus: int = int(operation[&"combo_bonus_damage"])
		var total: int = int(operation[&"total_requested_damage"])
		if (
			String(target_id).is_empty()
			or not plan_target_ids.has(target_id)
			or base < 0
			or bonus < 0
			or total <= 0
			or base + bonus != total
		):
			return false
	return true


static func _valid_keyword_operations(
	plan_actor_id: StringName,
	plan_target_ids: Array[StringName],
	plan_keyword_operations: Array[RefCounted]
) -> bool:
	var seen: Dictionary[StringName, bool] = {}
	for operation: RefCounted in plan_keyword_operations:
		if not _is_valid_keyword_operation(operation):
			return false
		var target_id: StringName = operation.get("target_id")
		if target_id != plan_actor_id and not plan_target_ids.has(target_id):
			return false
		var key: StringName = StringName("%s::%s::%s" % [operation.get("kind"), target_id, operation.get("affected_skill_id")])
		if seen.has(key):
			return false
		seen[key] = true
	return true


static func _duplicate_keyword_operations(source_operations: Array[RefCounted]) -> Array[RefCounted]:
	var copied: Array[RefCounted] = []
	for operation: RefCounted in source_operations:
		if is_instance_valid(operation):
			copied.append(operation.call("duplicate_operation"))
	return copied


static func _is_valid_keyword_operation(operation: RefCounted) -> bool:
	return (
		is_instance_valid(operation)
		and operation.has_method("is_valid")
		and operation.has_method("duplicate_operation")
		and operation.call("is_valid")
	)


static func _is_valid_keyword_source(source: RefCounted) -> bool:
	return (
		is_instance_valid(source)
		and source.has_method("is_valid")
		and source.has_method("duplicate_source")
		and source.call("is_valid")
	)
