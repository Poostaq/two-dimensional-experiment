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
var cooldown_actions: int
var advance_turn: bool
var battle_revision: int

var _target_ids: Array[StringName] = []
var _damage_operations: Array[Dictionary] = []
var _speed_operations: Array[Dictionary] = []
var _is_valid: bool = false


func _init(
	plan_actor_id: StringName,
	plan_skill_id: StringName,
	plan_target_ids: Array[StringName],
	plan_damage_operations: Array[Dictionary],
	plan_speed_operations: Array[Dictionary],
	plan_cooldown_actions: int,
	plan_advance_turn: bool,
	plan_battle_revision: int
) -> void:
	if not _valid_input(
		plan_actor_id,
		plan_skill_id,
		plan_target_ids,
		plan_damage_operations,
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
	plan_battle_revision: int
) -> SkillEffectPlan:
	var plan := SkillEffectPlan.new(
		plan_actor_id,
		plan_skill_id,
		plan_target_ids,
		plan_damage_operations,
		plan_speed_operations,
		plan_cooldown_actions,
		plan_advance_turn,
		plan_battle_revision
	)
	return plan if plan.is_valid() else null


func is_valid() -> bool:
	return _is_valid


static func _valid_input(
	plan_actor_id: StringName,
	plan_skill_id: StringName,
	plan_target_ids: Array[StringName],
	plan_damage_operations: Array[Dictionary],
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
