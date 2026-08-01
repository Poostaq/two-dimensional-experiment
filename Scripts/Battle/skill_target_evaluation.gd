class_name SkillTargetEvaluation
extends RefCounted

var actor_id: StringName
var skill_id: StringName
var targeting_mode: CharacterSkill.TargetingMode
var can_start: bool
var blocking_reason: SkillActionReason
var valid_target_ids: Array[StringName]
var invalid_targets: Dictionary[StringName, SkillActionReason]
var affected_target_ids: Array[StringName]
var battle_revision: int


func _init(
	evaluation_actor_id: StringName,
	evaluation_skill_id: StringName,
	evaluation_targeting_mode: CharacterSkill.TargetingMode,
	evaluation_can_start: bool,
	evaluation_blocking_reason: SkillActionReason,
	evaluation_valid_target_ids: Array[StringName],
	evaluation_invalid_targets: Dictionary[StringName, SkillActionReason],
	evaluation_affected_target_ids: Array[StringName],
	evaluation_battle_revision: int
) -> void:
	actor_id = evaluation_actor_id
	skill_id = evaluation_skill_id
	targeting_mode = evaluation_targeting_mode
	can_start = evaluation_can_start
	blocking_reason = evaluation_blocking_reason
	valid_target_ids = evaluation_valid_target_ids.duplicate()
	invalid_targets = evaluation_invalid_targets.duplicate()
	affected_target_ids = evaluation_affected_target_ids.duplicate()
	battle_revision = evaluation_battle_revision
