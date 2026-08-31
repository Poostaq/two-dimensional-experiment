class_name BattleSkillCondition
extends RefCounted

enum Kind {
	PRIMARY_SNARED,
	PRIMARY_ATTACKED_ALLY_THIS_ROUND,
	PRIMARY_BLEEDING,
	PRIMARY_BELOW_HALF_HP,
	PRIMARY_HIT_BY_ALLY_THIS_ROUND,
	PRIMARY_CONSUMED_ADVANTAGE_THIS_ROUND,
	ALLY_ACTED_BEFORE_ACTOR_THIS_ROUND,
	PRIMARY_DIFFERENT_RACE_FROM_ACTOR,
}

var kind: Kind:
	get:
		return _kind

var _kind: Kind = Kind.PRIMARY_SNARED
var _is_valid: bool = false


func _init(condition_kind: int) -> void:
	if condition_kind not in [
		Kind.PRIMARY_SNARED,
		Kind.PRIMARY_ATTACKED_ALLY_THIS_ROUND,
		Kind.PRIMARY_BLEEDING,
		Kind.PRIMARY_BELOW_HALF_HP,
		Kind.PRIMARY_HIT_BY_ALLY_THIS_ROUND,
		Kind.PRIMARY_CONSUMED_ADVANTAGE_THIS_ROUND,
		Kind.ALLY_ACTED_BEFORE_ACTOR_THIS_ROUND,
		Kind.PRIMARY_DIFFERENT_RACE_FROM_ACTOR,
	]:
		return
	_kind = condition_kind as Kind
	_is_valid = true


static func create(condition_kind: int) -> RefCounted:
	var condition: RefCounted = load("res://Scripts/Battle/battle_skill_condition.gd").new(condition_kind)
	return condition if condition.is_valid() else null


func is_valid() -> bool:
	return _is_valid


func duplicate_condition() -> RefCounted:
	if not is_valid():
		return null
	var condition_script := load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	return condition_script.create(_kind)
