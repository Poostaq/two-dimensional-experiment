class_name SkillEffectPlan
extends RefCounted

var actor_id: StringName
var skill_id: StringName
var target_ids: Array[StringName]
var damage_operations: Array[Dictionary]
var speed_operations: Array[Dictionary]
var cooldown_actions: int
var advance_turn: bool
var battle_revision: int


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
	actor_id = plan_actor_id
	skill_id = plan_skill_id
	target_ids = plan_target_ids.duplicate()
	damage_operations = plan_damage_operations.duplicate(true)
	speed_operations = plan_speed_operations.duplicate(true)
	cooldown_actions = plan_cooldown_actions
	advance_turn = plan_advance_turn
	battle_revision = plan_battle_revision
