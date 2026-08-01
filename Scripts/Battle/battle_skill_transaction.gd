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
var hovered_target_id: StringName = &""

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


func hover_target(target_id: StringName, callback_generation: int) -> bool:
	if not _is_current(callback_generation) or state != State.TARGETING:
		return false
	if targeting_mode != CharacterSkill.TargetingMode.FREE:
		return false
	hovered_target_id = target_id
	return valid_target_ids.has(target_id) or invalid_targets.has(target_id)


func clear_target_hover(callback_generation: int) -> bool:
	if not _is_current(callback_generation) or state != State.TARGETING:
		return false
	hovered_target_id = &""
	return true


func presentation_snapshot() -> Dictionary:
	var roles: Dictionary[StringName, StringName] = {}
	if state == State.PREVIEWING:
		for target_id: StringName in valid_target_ids:
			roles[target_id] = &"valid_preview"
		for target_id: StringName in invalid_targets:
			roles[target_id] = &"invalid_preview"
	elif state in [State.TARGETING, State.VALIDATING, State.RESOLVING]:
		for target_id: StringName in locked_target_ids:
			roles[target_id] = &"locked"
		if (
			state == State.TARGETING
			and not hovered_target_id.is_empty()
			and not locked_target_ids.has(hovered_target_id)
		):
			if valid_target_ids.has(hovered_target_id):
				roles[hovered_target_id] = &"valid_hover"
			elif invalid_targets.has(hovered_target_id):
				roles[hovered_target_id] = &"invalid_hover"
	var has_lock: bool = not locked_target_ids.is_empty()
	var action_visible: bool = state in [
		State.TARGETING,
		State.VALIDATING,
		State.REJECTED_STALE,
	]
	var message: String = ""
	if state == State.TARGETING:
		message = (
			"Select a target for %s" % _display_skill_name()
			if targeting_mode == CharacterSkill.TargetingMode.FREE and not has_lock
			else "Confirm %s" % _display_skill_name()
		)
	elif state == State.VALIDATING:
		message = "Validating %s..." % _display_skill_name()
	elif state == State.REJECTED_STALE:
		message = last_reason.message
	return {
		"state": state,
		"generation": generation,
		"message": message,
		"summary": _target_summary(),
		"action_region_visible": action_visible,
		"confirm_visible": action_visible and has_lock and state != State.REJECTED_STALE,
		"confirm_enabled": state == State.TARGETING and has_lock,
		"cancel_visible": action_visible,
		"cancel_enabled": state in [State.TARGETING, State.REJECTED_STALE],
		"indicator_roles": roles.duplicate(),
	}


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
	hovered_target_id = &""
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
	hovered_target_id = &""
	last_reason = SkillActionReason.none()
	_can_start = false
	_confirmation_pending = false


func _display_skill_name() -> String:
	return String(skill_id).replace("_", " ").capitalize()


func _target_summary() -> String:
	if locked_target_ids.is_empty():
		return ""
	var names: PackedStringArray = []
	for target_id: StringName in locked_target_ids:
		names.append(String(target_id))
	return "Targets: %s" % ", ".join(names)


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
