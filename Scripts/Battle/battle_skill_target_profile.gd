class_name BattleSkillTargetProfile
extends RefCounted

var minimum_targets: int:
	get:
		return _minimum_targets
var maximum_targets: int:
	get:
		return _maximum_targets
var target_side: BattleUnitState.Side:
	get:
		return _target_side
var require_adjacent_lane: bool:
	get:
		return _require_adjacent_lane
var allows_optional_self_move: bool:
	get:
		return _allows_optional_self_move
var target_sides: Array[int]:
	get:
		return _target_sides.duplicate()

var _minimum_targets: int = -1
var _maximum_targets: int = -1
var _target_side: BattleUnitState.Side = BattleUnitState.Side.PLAYER
var _require_adjacent_lane: bool = false
var _allows_optional_self_move: bool = false
var _target_sides: Array[int] = []


func _init(
	minimum: int,
	maximum: int,
	side: int,
	requires_adjacency: bool,
	allows_movement: bool,
	ordered_target_sides: Array[int] = []
) -> void:
	if not _is_valid_input(minimum, maximum, side, requires_adjacency, allows_movement, ordered_target_sides):
		return
	_minimum_targets = minimum
	_maximum_targets = maximum
	_target_side = side as BattleUnitState.Side
	_require_adjacent_lane = requires_adjacency
	_allows_optional_self_move = allows_movement
	_target_sides = ordered_target_sides.duplicate()


static func create(
	minimum: int,
	maximum: int,
	side: int,
	requires_adjacency: bool = false,
	allows_movement: bool = false,
	ordered_target_sides: Array[int] = []
) -> RefCounted:
	var profile: RefCounted = load("res://Scripts/Battle/battle_skill_target_profile.gd").new(
		minimum,
		maximum,
		side,
		requires_adjacency,
		allows_movement,
		ordered_target_sides
	)
	return profile if profile.is_valid() else null


func is_valid() -> bool:
	return _minimum_targets >= 0


func duplicate_profile() -> RefCounted:
	if not is_valid():
		return null
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	return profile_script.create(
		_minimum_targets,
		_maximum_targets,
		_target_side,
		_require_adjacent_lane,
		_allows_optional_self_move,
		_target_sides
	)


static func _is_valid_input(
	minimum: int,
	maximum: int,
	side: int,
	requires_adjacency: bool,
	allows_movement: bool,
	ordered_target_sides: Array[int]
) -> bool:
	if side not in [BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY]:
		return false
	if minimum < 0 or maximum < minimum or maximum > 2:
		return false
	if not ordered_target_sides.is_empty():
		if ordered_target_sides.size() != maximum:
			return false
		for target_side: int in ordered_target_sides:
			if target_side not in [BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY]:
				return false
	if allows_movement:
		return minimum == 0 and maximum == 0 and not requires_adjacency
	if minimum == 0 or maximum == 0:
		return false
	if requires_adjacency and (minimum != 1 or maximum != 1):
		return false
	return true
