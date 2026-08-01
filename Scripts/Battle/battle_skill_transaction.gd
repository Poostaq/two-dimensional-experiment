class_name BattleSkillTransaction
extends RefCounted

enum State {
	IDLE,
	PREVIEWING,
	TARGETING,
	VALIDATING,
	RESOLVING,
	CANCELLED,
	REJECTED_STALE,
}

var state: State = State.IDLE
var generation: int = 0
var actor_id: StringName = &""
var skill_id: StringName = &""
var targeting_mode: CharacterSkill.TargetingMode = CharacterSkill.TargetingMode.PREDEFINED
var battle_revision: int = -1
var valid_target_ids: Array[StringName] = []
var invalid_targets: Dictionary[StringName, SkillActionReason] = {}
var affected_target_ids: Array[StringName] = []
var locked_target_ids: Array[StringName] = []
var last_reason: SkillActionReason = SkillActionReason.none()

var _can_start: bool = false
var _confirmation_pending: bool = false


func preview(evaluation: SkillTargetEvaluation) -> int:
	generation += 1
	_clear_selection()
	state = State.PREVIEWING
	if not is_instance_valid(evaluation):
		last_reason = SkillActionReason.new(
			SkillActionReason.Code.SKILL_AVAILABILITY_CHANGED,
			"Skill availability changed. Review this skill again."
		)
		return generation
	actor_id = evaluation.actor_id
	skill_id = evaluation.skill_id
	targeting_mode = evaluation.targeting_mode
	battle_revision = evaluation.battle_revision
	valid_target_ids = evaluation.valid_target_ids.duplicate()
	invalid_targets = evaluation.invalid_targets.duplicate()
	affected_target_ids = evaluation.affected_target_ids.duplicate()
	_can_start = evaluation.can_start
	last_reason = evaluation.blocking_reason
	return generation


func begin_targeting(callback_generation: int) -> bool:
	if not _is_current(callback_generation) or state != State.PREVIEWING or not _can_start:
		return false
	state = State.TARGETING
	last_reason = SkillActionReason.none()
	if targeting_mode == CharacterSkill.TargetingMode.PREDEFINED:
		locked_target_ids = affected_target_ids.duplicate()
	return true


func select_target(target_id: StringName, callback_generation: int) -> bool:
	if not _is_current(callback_generation) or state != State.TARGETING:
		return false
	if targeting_mode != CharacterSkill.TargetingMode.FREE:
		return false
	if not valid_target_ids.has(target_id):
		last_reason = invalid_targets.get(
			target_id,
			SkillActionReason.new(
				SkillActionReason.Code.TARGET_INVALID,
				"Invalid target.",
				actor_id,
				skill_id,
				target_id
			)
		)
		return false
	locked_target_ids.clear()
	locked_target_ids.append(target_id)
	last_reason = SkillActionReason.none()
	return true


func begin_confirmation(callback_generation: int) -> bool:
	if (
		not _is_current(callback_generation)
		or state != State.TARGETING
		or _confirmation_pending
		or locked_target_ids.is_empty()
	):
		return false
	_confirmation_pending = true
	state = State.VALIDATING
	return true


func complete_confirmation(
	validation: SkillConfirmationValidation,
	callback_generation: int
) -> bool:
	if (
		not _is_current(callback_generation)
		or state != State.VALIDATING
		or not _confirmation_pending
	):
		return false
	_confirmation_pending = false
	if validation.accepted:
		state = State.RESOLVING
		last_reason = SkillActionReason.none()
		return true
	last_reason = validation.reason
	if _is_stale_reason(validation.reason.code):
		locked_target_ids.clear()
		state = State.REJECTED_STALE
	else:
		state = State.TARGETING
	return true


func finish_resolution(callback_generation: int) -> bool:
	if not _is_current(callback_generation) or state != State.RESOLVING:
		return false
	reset()
	return true


func cancel(callback_generation: int) -> bool:
	if not _is_current(callback_generation):
		return false
	generation += 1
	_clear_selection()
	state = State.CANCELLED
	return true


func reset() -> void:
	generation += 1
	_clear_selection()
	state = State.IDLE


func _clear_selection() -> void:
	actor_id = &""
	skill_id = &""
	battle_revision = -1
	valid_target_ids.clear()
	invalid_targets.clear()
	affected_target_ids.clear()
	locked_target_ids.clear()
	last_reason = SkillActionReason.none()
	_can_start = false
	_confirmation_pending = false


func _is_current(callback_generation: int) -> bool:
	return callback_generation == generation


func _is_stale_reason(code: SkillActionReason.Code) -> bool:
	return code in [
		SkillActionReason.Code.ACTOR_INACTIVE,
		SkillActionReason.Code.BATTLE_COMPLETE,
		SkillActionReason.Code.TARGET_DEFEATED,
		SkillActionReason.Code.TARGET_REMOVED,
		SkillActionReason.Code.TARGET_OWNERSHIP_CHANGED,
		SkillActionReason.Code.ROUND_CHANGED,
		SkillActionReason.Code.TURN_ORDER_CHANGED,
		SkillActionReason.Code.SKILL_AVAILABILITY_CHANGED,
		SkillActionReason.Code.REVISION_MISMATCH,
	]
