class_name Ac6_5BrakkaTests
extends SceneTree

const COMMANDER_CATALOG_PATH: String = "res://Scripts/Run/goblin_commander_catalog.gd"
const FORMATION_RULES_PATH: String = "res://Scripts/Battle/battle_formation_rules.gd"
const KEYWORD_OPERATION_PATH: String = "res://Scripts/Battle/battle_keyword_operation.gd"
const REACTION_DEFINITION_PATH: String = "res://Scripts/Battle/battle_reaction_definition.gd"
const REACTION_DISPATCHER_PATH: String = "res://Scripts/Battle/battle_reaction_dispatcher.gd"
const EXPECTED_BRAKKA_ID: StringName = &"brakka_rustbanner"

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_missing_commander_catalog_contract()
	_test_closest_active_opponent_contract()
	_test_action_start_reaction_contract()
	if _failures.is_empty():
		print("AC6.5 Brakka: PASS (%d/%d)" % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_missing_commander_catalog_contract() -> void:
	_expect(ResourceLoader.exists(COMMANDER_CATALOG_PATH), "commander catalog exists")


func _test_closest_active_opponent_contract() -> void:
	var rules := load(FORMATION_RULES_PATH) as Script
	_expect(rules.has_method("closest_active_opponent"), "formation rules expose closest_active_opponent")
	if not rules.has_method("closest_active_opponent"):
		return
	var brakka := _unit(&"brakka", BattleUnitState.Side.PLAYER, 1)
	var enemy_front_left := _unit(&"enemy_front_left", BattleUnitState.Side.ENEMY, 0)
	var enemy_front_right := _unit(&"enemy_front_right", BattleUnitState.Side.ENEMY, 2)
	var enemy_back_middle := _unit(&"enemy_back_middle", BattleUnitState.Side.ENEMY, 4)
	var ally_middle := _unit(&"ally_middle", BattleUnitState.Side.PLAYER, 1)
	var winner: BattleUnitState = rules.call(
		"closest_active_opponent",
		brakka,
		_units([enemy_front_right, ally_middle, enemy_back_middle, enemy_front_left, brakka])
	)
	_expect(winner == enemy_back_middle, "same lane beats adjacent frontline enemies")
	enemy_back_middle.current_hp = 0
	winner = rules.call(
		"closest_active_opponent",
		brakka,
		_units([enemy_front_right, enemy_front_left, enemy_back_middle, brakka])
	)
	_expect(winner == enemy_front_left, "equal distance uses lowest frontline slot")
	enemy_front_left.current_hp = 0
	enemy_front_right.current_hp = 0
	_expect(
		rules.call("closest_active_opponent", brakka, _units([brakka, ally_middle])) == null,
		"no active opponent returns null"
	)
	var enemy_back_left := _unit(&"enemy_back_left", BattleUnitState.Side.ENEMY, 3)
	var enemy_front_left_fresh := _unit(&"enemy_front_left_fresh", BattleUnitState.Side.ENEMY, 0)
	_expect(
		rules.call(
			"closest_active_opponent",
			brakka,
			_units([enemy_back_left, enemy_front_left_fresh, brakka])
		) == enemy_front_left_fresh,
		"frontline wins an equal-distance row tie"
	)
	_expect(
		rules.call(
			"closest_active_opponent",
			brakka,
			_units([enemy_front_left_fresh, enemy_back_left, brakka])
		) == enemy_front_left_fresh,
		"input order does not change the winner"
	)
	var invalid_enemy := _unit(&"invalid_enemy", BattleUnitState.Side.ENEMY, 6)
	_expect(
		rules.call(
			"closest_active_opponent",
			brakka,
			_units([invalid_enemy, enemy_back_left, brakka])
		) == enemy_back_left,
		"invalid candidate slots are filtered"
	)
	brakka.current_hp = 0
	_expect(
		rules.call("closest_active_opponent", brakka, _units([brakka, enemy_back_left])) == null,
		"inactive actor returns null"
	)
	var invalid_actor := _unit(&"invalid_actor", BattleUnitState.Side.PLAYER, -1)
	_expect(
		rules.call("closest_active_opponent", invalid_actor, _units([invalid_actor, enemy_back_left])) == null,
		"invalid actor slot returns null"
	)


func _test_action_start_reaction_contract() -> void:
	var operation_script := load(KEYWORD_OPERATION_PATH) as Script
	var definition_script := load(REACTION_DEFINITION_PATH) as Script
	var dispatcher_script := load(REACTION_DISPATCHER_PATH) as Script
	_expect(operation_script.has_method("with_target"), "keyword operation exposes immutable retargeting")
	_expect(
		definition_script.Trigger.size() == 3 and int(definition_script.Trigger.get("ACTION_START", -1)) == 2,
		"reaction definition exposes ACTION_START without renumbering existing triggers"
	)
	_expect(
		dispatcher_script.has_method("collect_action_start_reactions"),
		"dispatcher exposes action-start collection"
	)
	_expect(
		dispatcher_script.has_method("is_action_start_target_current"),
		"dispatcher exposes action-start target revalidation"
	)


func _unit(id: StringName, side: BattleUnitState.Side, slot_index: int) -> BattleUnitState:
	return BattleUnitState.new(id, String(id), side, slot_index, 5, 20, [], 4, 0)


func _units(values: Array) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for value: Variant in values:
		result.append(value as BattleUnitState)
	return result


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
