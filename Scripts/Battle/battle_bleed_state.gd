class_name BattleBleedState
extends RefCounted

const MAX_STACKS: int = 3
const DAMAGE_RATIO: float = 0.20

var source: RefCounted:
	get:
		return _source.duplicate_source() if is_instance_valid(_source) else null
var stacks: int:
	get:
		return _stacks
var remaining_actions: int:
	get:
		return _remaining_actions

var _source: RefCounted
var _stacks: int = 0
var _remaining_actions: int = 0


static func create(
	candidate_source: RefCounted,
	candidate_stacks: int,
	candidate_remaining_actions: int
) -> RefCounted:
	if (
		not _is_valid_source(candidate_source)
		or candidate_stacks < 1
		or candidate_stacks > MAX_STACKS
		or candidate_remaining_actions < 1
	):
		return null
	var state: RefCounted = load("res://Scripts/Battle/battle_bleed_state.gd").new()
	state.set("_source", candidate_source.call("duplicate_source") as RefCounted)
	state.set("_stacks", candidate_stacks)
	state.set("_remaining_actions", candidate_remaining_actions)
	return state


func is_valid() -> bool:
	return _is_valid_source(_source) and _stacks >= 1 and _stacks <= MAX_STACKS and _remaining_actions >= 1


func add_application(candidate_source: RefCounted, duration_actions: int) -> bool:
	if not _same_source(candidate_source) or duration_actions < 1:
		return false
	_stacks = mini(MAX_STACKS, _stacks + 1)
	_remaining_actions = maxi(_remaining_actions, duration_actions)
	return true


func tick_damage() -> int:
	if not is_valid():
		return 0
	var per_stack: int = maxi(1, ceili(float(_source.get("source_power")) * DAMAGE_RATIO))
	return _stacks * per_stack


func consume_action() -> bool:
	if _remaining_actions < 1:
		return false
	_remaining_actions -= 1
	return _remaining_actions > 0


func duplicate_state() -> RefCounted:
	var state_script := load("res://Scripts/Battle/battle_bleed_state.gd") as Script
	return state_script.call("create", _source, _stacks, _remaining_actions) as RefCounted


func _same_source(candidate_source: RefCounted) -> bool:
	return (
		_is_valid_source(candidate_source)
		and candidate_source.get("source_unit_id") == _source.get("source_unit_id")
		and candidate_source.get("source_skill_id") == _source.get("source_skill_id")
	)


static func _is_valid_source(candidate_source: RefCounted) -> bool:
	return (
		is_instance_valid(candidate_source)
		and candidate_source.has_method("is_valid")
		and bool(candidate_source.call("is_valid"))
	)
