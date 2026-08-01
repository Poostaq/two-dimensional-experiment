class_name SkillActionReason
extends RefCounted

enum Code {
	NONE,
	NOT_CURRENT_ACTOR,
	ACTOR_INACTIVE,
	ENEMY_NOT_PLAYER_CONTROLLABLE,
	PASSIVE_NOT_ACTIONABLE,
	BATTLE_COMPLETE,
	POSITION_REQUIRED,
	HEALTH_REQUIRED,
	PRE_USE_COOLDOWN,
	POST_USE_COOLDOWN,
	TARGET_INVALID,
	TARGET_DEFEATED,
	TARGET_REMOVED,
	TARGET_OWNERSHIP_CHANGED,
	ROUND_CHANGED,
	TURN_ORDER_CHANGED,
	SKILL_AVAILABILITY_CHANGED,
	REVISION_MISMATCH,
}

var code: Code
var message: String
var actor_id: StringName
var skill_id: StringName
var target_id: StringName


func _init(
	reason_code: Code = Code.NONE,
	reason_message: String = "",
	reason_actor_id: StringName = &"",
	reason_skill_id: StringName = &"",
	reason_target_id: StringName = &""
) -> void:
	code = reason_code
	message = reason_message
	actor_id = reason_actor_id
	skill_id = reason_skill_id
	target_id = reason_target_id


static func none() -> SkillActionReason:
	return SkillActionReason.new()
