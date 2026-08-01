class_name SkillConfirmationValidation
extends RefCounted

var accepted: bool
var reason: SkillActionReason
var actor_id: StringName
var skill_id: StringName
var target_ids: Array[StringName]
var evaluated_revision: int
var effect_plan: SkillEffectPlan


func _init(
	validation_accepted: bool,
	validation_reason: SkillActionReason,
	validation_actor_id: StringName,
	validation_skill_id: StringName,
	validation_target_ids: Array[StringName],
	validation_revision: int,
	validation_effect_plan: SkillEffectPlan = null
) -> void:
	accepted = validation_accepted
	reason = validation_reason
	actor_id = validation_actor_id
	skill_id = validation_skill_id
	target_ids = validation_target_ids.duplicate()
	evaluated_revision = validation_revision
	effect_plan = validation_effect_plan
