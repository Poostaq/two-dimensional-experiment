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
	var source := BattleKeywordSource.create(&"brakka", &"banner_holder", 4)
	var template: RefCounted = operation_script.call("create", 1, &"brakka", 0, 1, source)
	var has_retarget: bool = template.has_method("with_target")
	var has_collect: bool = dispatcher_script.has_method("collect_action_start_reactions")
	var has_revalidate: bool = dispatcher_script.has_method("is_action_start_target_current")
	_expect(has_retarget, "keyword operation exposes immutable retargeting")
	_expect(
		definition_script.Trigger.size() == 3 and int(definition_script.Trigger.get("ACTION_START", -1)) == 2,
		"reaction definition exposes ACTION_START without renumbering existing triggers"
	)
	_expect(has_collect, "dispatcher exposes action-start collection")
	_expect(has_revalidate, "dispatcher exposes action-start target revalidation")
	if (
		not has_retarget
		or not has_collect
		or not has_revalidate
		or definition_script.Trigger.size() != 3
	):
		return
	var retargeted: RefCounted = template.call("with_target", &"enemy")
	_expect(retargeted != null and retargeted.get("target_id") == &"enemy", "retargeting replaces target")
	_expect(template.get("target_id") == &"brakka", "retargeting leaves template immutable")
	_expect(
		retargeted.get("kind") == template.get("kind")
		and retargeted.get("duration") == template.get("duration")
		and retargeted.get("source").get("source_skill_id") == &"banner_holder",
		"retargeting preserves operation data"
	)
	_expect(template.call("with_target", &"") == null, "retargeting rejects empty target")
	var definition: RefCounted = definition_script.call("create", &"banner_holder", 2, 1, 0, template, false)
	_expect(definition != null, "action-start definition validates")
	var passive := CharacterSkill.create(
		&"banner_holder",
		"Banner Holder",
		CharacterSkill.Kind.PASSIVE,
		"Apply Advantage.",
		"Closest active enemy.",
		"Owner starts an action.",
		"Once per round.",
		-1,
		-1,
		-1,
		CharacterSkill.Requirement.NONE,
		-1,
		-1,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		null,
		[],
		null,
		definition
	)
	var brakka := BattleUnitState.new(
		&"brakka",
		"Brakka",
		BattleUnitState.Side.PLAYER,
		1,
		7,
		20,
		[passive],
		4,
		2
	)
	var ally := _unit(&"ally", BattleUnitState.Side.PLAYER, 0)
	var enemy_front := _unit(&"enemy_front", BattleUnitState.Side.ENEMY, 0)
	var enemy_back := _unit(&"enemy_back", BattleUnitState.Side.ENEMY, 4)
	var units := _units([enemy_front, ally, enemy_back, brakka])
	var reactions: Array = dispatcher_script.call("collect_action_start_reactions", brakka, units, 1)
	_expect(reactions.size() == 1, "one action-start Passive dispatches")
	if not reactions.is_empty():
		var candidate: Dictionary = reactions[0]
		_expect(candidate.keys().size() == 3, "action-start candidate has exact fields")
		_expect(candidate.get("owner_id") == &"brakka", "candidate binds owner")
		_expect(candidate.get("target_id") == &"enemy_back", "candidate selects closest enemy")
		var resolved: RefCounted = candidate.get("definition")
		_expect(
			resolved.get("operation").get("target_id") == &"enemy_back",
			"candidate operation is immutably retargeted"
		)
	_expect(
		dispatcher_script.call("collect_action_start_reactions", brakka, units, 1).is_empty(),
		"once-per-round guard blocks a duplicate action start"
	)
	_expect(
		dispatcher_script.call("collect_action_start_reactions", brakka, units, 2).size() == 1,
		"next round can dispatch again"
	)
	_expect(
		dispatcher_script.call("is_action_start_target_current", brakka, &"enemy_back", units),
		"unchanged closest target revalidates"
	)
	enemy_back.current_hp = 0
	_expect(
		not dispatcher_script.call("is_action_start_target_current", brakka, &"enemy_back", units),
		"stale closest target fails without redirect"
	)
	brakka.clear_battle_local_state()
	enemy_front.current_hp = 0
	var no_enemy: Array = dispatcher_script.call("collect_action_start_reactions", brakka, units, 1)
	_expect(no_enemy.size() == 1 and no_enemy[0].get("target_id") == &"", "no enemy emits one guarded no-result")
	_expect(
		dispatcher_script.call("collect_action_start_reactions", brakka, units, 1).is_empty(),
		"no-result path still consumes the round guard"
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
