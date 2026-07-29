class_name Ac2_4BattleResultsTests
extends SceneTree

const OUTCOME_PATH := "res://Scripts/Battle/battle_outcome.gd"
const UNIT_PATH := "res://Scripts/Battle/battle_unit_state.gd"
const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 9
const IN_PROGRESS := 0
const VICTORY := 1
const DEFEAT := 2

var _failures: Array[String] = []
var _outcome_script: GDScript
var _unit_script: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_outcome_script = load(OUTCOME_PATH) as GDScript if ResourceLoader.exists(OUTCOME_PATH) else null
	_unit_script = load(UNIT_PATH) as GDScript
	_test_active_sides_remain_in_progress()
	_test_no_active_enemies_is_victory()
	_test_no_active_players_is_defeat()
	_test_invalid_configurations_remain_in_progress()
	await _test_final_enemy_hit_latches_victory()
	await _test_final_player_hit_latches_defeat()
	await _test_completed_battle_is_immutable()
	await _test_reconfigure_resets_outcome()
	await _test_result_presentation_is_binary()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _unit(id: StringName, side: int, slot_index: int, speed: int = 5) -> BattleUnitState:
	return _unit_script.new(id, str(id), side, slot_index, speed) as BattleUnitState


func _set_hp(unit: BattleUnitState, hp: int) -> void:
	unit.current_hp = hp


func _typed_units(units: Array) -> Array[BattleUnitState]:
	var typed: Array[BattleUnitState] = []
	for unit: Variant in units:
		typed.append(unit as BattleUnitState)
	return typed


func _evaluate(units: Array) -> int:
	if _outcome_script == null:
		return -1
	return int(_outcome_script.call("evaluate", _typed_units(units)))


func _instantiate_arena() -> Control:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as Control if packed != null else null
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _configure(arena: Control, units: Array) -> void:
	if is_instance_valid(arena) and arena.has_method("configure_units"):
		arena.call("configure_units", _typed_units(units))


func _get_outcome(arena: Control) -> int:
	if not is_instance_valid(arena) or not arena.has_method("get_battle_outcome"):
		return -1
	return int(arena.call("get_battle_outcome"))


func _perform_damage(arena: Control) -> void:
	if is_instance_valid(arena) and arena.has_method("perform_debug_damage"):
		arena.call("perform_debug_damage")


func _free_arena(arena: Control) -> void:
	if is_instance_valid(arena):
		arena.queue_free()


func _test_active_sides_remain_in_progress() -> void:
	var units: Array[BattleUnitState] = [
		_unit(&"player", BattleUnitState.Side.PLAYER, 0),
		_unit(&"enemy", BattleUnitState.Side.ENEMY, 0),
	]
	_assert(_evaluate(units) == IN_PROGRESS, "active sides remain in progress", "expected IN_PROGRESS")


func _test_no_active_enemies_is_victory() -> void:
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0)
	_set_hp(enemy, 0)
	_assert(_evaluate([player, enemy]) == VICTORY, "enemy exhaustion is victory", "expected VICTORY")


func _test_no_active_players_is_defeat() -> void:
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0)
	_set_hp(player, 0)
	_assert(_evaluate([player, enemy]) == DEFEAT, "player exhaustion is defeat", "expected DEFEAT")


func _test_invalid_configurations_remain_in_progress() -> void:
	var defeated_player := _unit(&"player", BattleUnitState.Side.PLAYER, 0)
	var defeated_enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0)
	_set_hp(defeated_player, 0)
	_set_hp(defeated_enemy, 0)
	_assert(
		_evaluate([]) == IN_PROGRESS
		and _evaluate([defeated_player, defeated_enemy]) == IN_PROGRESS,
		"invalid configurations remain in progress",
		"empty or simultaneously inactive sides must not claim a result"
	)


func _test_final_enemy_hit_latches_victory() -> void:
	var arena := await _instantiate_arena()
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0, 9)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_set_hp(enemy, 6)
	_configure(arena, [player, enemy])
	_perform_damage(arena)
	_assert(
		_get_outcome(arena) == VICTORY,
		"final enemy hit latches victory",
		"expected VICTORY immediately after resolution"
	)
	_free_arena(arena)


func _test_final_player_hit_latches_defeat() -> void:
	var arena := await _instantiate_arena()
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 9)
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0, 8)
	_set_hp(player, 6)
	_configure(arena, [enemy, player])
	_perform_damage(arena)
	_assert(
		_get_outcome(arena) == DEFEAT,
		"final player hit latches defeat",
		"expected DEFEAT immediately after resolution"
	)
	_free_arena(arena)


func _test_completed_battle_is_immutable() -> void:
	var arena := await _instantiate_arena()
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0, 9)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_set_hp(enemy, 6)
	_configure(arena, [player, enemy])
	_perform_damage(arena)
	var log_count := (arena.call("get_battle_log_entries") as Array).size()
	var round_before := int(arena.get("round_number"))
	_perform_damage(arena)
	_assert(
		(arena.call("get_battle_log_entries") as Array).size() == log_count
		and int(arena.get("round_number")) == round_before
		and enemy.current_hp == 0
		and _get_outcome(arena) == VICTORY,
		"completed battle is immutable",
		"terminal calls must not mutate HP, log, round, or outcome"
	)
	_free_arena(arena)


func _test_reconfigure_resets_outcome() -> void:
	var arena := await _instantiate_arena()
	var player := _unit(&"player", BattleUnitState.Side.PLAYER, 0, 9)
	var enemy := _unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_set_hp(enemy, 6)
	_configure(arena, [player, enemy])
	_perform_damage(arena)
	var fresh_enemy := _unit(&"fresh_enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_configure(arena, [player, fresh_enemy])
	_assert(
		_get_outcome(arena) == IN_PROGRESS,
		"reconfigure resets outcome",
		"new battle must start IN_PROGRESS"
	)
	_free_arena(arena)


func _test_result_presentation_is_binary() -> void:
	var victory_arena := await _instantiate_arena()
	var victor := _unit(&"victor", BattleUnitState.Side.PLAYER, 0, 9)
	var final_enemy := _unit(&"final_enemy", BattleUnitState.Side.ENEMY, 0, 8)
	_set_hp(final_enemy, 6)
	_configure(victory_arena, [victor, final_enemy])
	_perform_damage(victory_arena)
	var victory_panel := victory_arena.get_node_or_null("%BattleResultPanel") as Control
	var victory_label := victory_arena.get_node_or_null("%BattleResultLabel") as Label

	var defeat_arena := await _instantiate_arena()
	var final_player := _unit(&"final_player", BattleUnitState.Side.PLAYER, 0, 8)
	var defeating_enemy := _unit(&"defeating_enemy", BattleUnitState.Side.ENEMY, 0, 9)
	_set_hp(final_player, 6)
	_configure(defeat_arena, [defeating_enemy, final_player])
	_perform_damage(defeat_arena)
	var defeat_panel := defeat_arena.get_node_or_null("%BattleResultPanel") as Control
	var defeat_label := defeat_arena.get_node_or_null("%BattleResultLabel") as Label

	_assert(
		victory_panel != null and victory_panel.visible
		and victory_label != null and victory_label.text == "Victory"
		and defeat_panel != null and defeat_panel.visible
		and defeat_label != null and defeat_label.text == "Defeat",
		"result presentation is binary",
		"expected persistent exact Victory and Defeat labels"
	)
	_free_arena(victory_arena)
	_free_arena(defeat_arena)


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC2.4 battle result tests: PASS (%d/%d)" % [
			EXPECTED_TEST_COUNT,
			EXPECTED_TEST_COUNT,
		])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
