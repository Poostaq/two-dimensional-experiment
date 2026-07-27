class_name Ac2_2SpeedOrderTests
extends SceneTree

const UNIT_SCRIPT_PATH := "res://Scripts/Battle/battle_unit_state.gd"
const QUEUE_SCRIPT_PATH := "res://Scripts/Battle/battle_turn_queue.gd"
const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 12

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_higher_speed_first()
	_test_player_tie_order()
	_test_enemy_tie_order()
	_test_player_precedes_enemy_on_tie()
	_test_mixed_fixture_order()
	_test_rebuild_is_stable()
	await _test_invalid_speed_empty_state()
	await _test_duplicate_slot_empty_state()
	await _test_initial_current_unit_display()
	await _test_advance_button_moves_once()
	await _test_highlight_moves()
	await _test_round_wraps()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _unit(id: StringName, side: int, slot_index: int, speed: int) -> BattleUnitState:
	return BattleUnitState.new(id, str(id), side, slot_index, speed)


func _build(units: Array[BattleUnitState]) -> Array[BattleUnitState]:
	return BattleTurnQueue.build(units)


func _ids(units: Array[BattleUnitState]) -> Array[StringName]:
	var result: Array[StringName] = []
	for unit: BattleUnitState in units:
		result.append(unit.get("unit_id") as StringName)
	return result


func _instantiate_arena() -> Control:
	var packed: PackedScene = load(ARENA_PATH) as PackedScene
	if packed == null:
		return null
	var arena: Control = packed.instantiate() as Control
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _test_higher_speed_first() -> void:
	var ordered: Array = _build([_unit(&"slow", BattleUnitState.Side.PLAYER, 0, 2), _unit(&"fast", BattleUnitState.Side.ENEMY, 0, 9)])
	_assert(_ids(ordered) == [&"fast", &"slow"], "higher speed first", "expected fast then slow")


func _test_player_tie_order() -> void:
	var units: Array[BattleUnitState] = []
	for slot_index: int in range(5, -1, -1):
		units.append(_unit(StringName("p%d" % slot_index), BattleUnitState.Side.PLAYER, slot_index, 5))
	_assert(_ids(_build(units)) == [&"p0", &"p1", &"p2", &"p3", &"p4", &"p5"], "player tie order", "player slots must order 0 through 5")


func _test_enemy_tie_order() -> void:
	var units: Array[BattleUnitState] = []
	for slot_index: int in range(5, -1, -1):
		units.append(_unit(StringName("e%d" % slot_index), BattleUnitState.Side.ENEMY, slot_index, 5))
	_assert(_ids(_build(units)) == [&"e0", &"e1", &"e2", &"e3", &"e4", &"e5"], "enemy tie order", "enemy slots must order 0 through 5")


func _test_player_precedes_enemy_on_tie() -> void:
	var units: Array[BattleUnitState] = [_unit(&"enemy", BattleUnitState.Side.ENEMY, 0, 5), _unit(&"player", BattleUnitState.Side.PLAYER, 5, 5)]
	var ordered: Array[BattleUnitState] = _build(units)
	_assert(_ids(ordered) == [&"player", &"enemy"], "player precedes enemy on tie", "player side must win equal-speed side tie")


func _test_mixed_fixture_order() -> void:
	var arena: Control = await _instantiate_arena()
	var actual: Array[StringName] = []
	if arena != null and arena.has_method("get_turn_queue"):
		actual = _ids(arena.call("get_turn_queue") as Array)
	var expected: Array[StringName] = [&"player_4", &"enemy_4", &"player_0", &"enemy_0", &"enemy_1", &"player_1", &"player_2", &"enemy_2", &"player_3", &"enemy_3", &"player_5", &"enemy_5"]
	_assert(actual == expected, "mixed fixture order", "expected %s, got %s" % [expected, actual])
	if arena != null:
		arena.queue_free()


func _test_rebuild_is_stable() -> void:
	var units: Array[BattleUnitState] = [_unit(&"b", BattleUnitState.Side.ENEMY, 3, 4), _unit(&"a", BattleUnitState.Side.PLAYER, 3, 4), _unit(&"c", BattleUnitState.Side.PLAYER, 0, 8)]
	var original: Array[BattleUnitState] = units.duplicate()
	var first: Array[StringName] = _ids(_build(units))
	var second: Array[StringName] = _ids(_build(units))
	_assert(first == second and units == original, "rebuild is stable", "rebuild changed order or mutated input")


func _test_invalid_speed_empty_state() -> void:
	var invalid_units: Array[BattleUnitState] = [_unit(&"invalid", BattleUnitState.Side.PLAYER, 0, 11)]
	_assert(_build(invalid_units).is_empty(), "invalid speed rejected", "speed 11 must return an empty queue")
	var arena: Control = await _instantiate_arena()
	if arena != null and arena.has_method("configure_units"):
		arena.call("configure_units", invalid_units)
	_assert(_has_empty_state(arena), "invalid speed rejected", "arena did not enter exact empty state")
	if arena != null:
		arena.queue_free()


func _test_duplicate_slot_empty_state() -> void:
	var duplicates: Array[BattleUnitState] = [_unit(&"first", BattleUnitState.Side.PLAYER, 0, 4), _unit(&"second", BattleUnitState.Side.PLAYER, 0, 5)]
	_assert(_build(duplicates).is_empty(), "duplicate slot rejected", "duplicate side and slot must return an empty queue")
	var arena: Control = await _instantiate_arena()
	if arena != null and arena.has_method("configure_units"):
		arena.call("configure_units", duplicates)
	_assert(_has_empty_state(arena), "duplicate slot rejected", "arena did not enter exact empty state")
	if arena != null:
		arena.queue_free()


func _has_empty_state(arena: Control) -> bool:
	if arena == null or not arena.has_method("get_turn_queue") or not arena.has_method("get_current_unit"):
		return false
	var label: Label = arena.get_node_or_null("%CurrentUnitLabel") as Label
	var button: Button = arena.get_node_or_null("%AdvanceTurnDebugButton") as Button
	var round_before: int = int(arena.get("round_number"))
	arena.call("advance_turn")
	var highlighted: int = 0
	for slot: Control in (arena.call("get_player_slots") as Array[Control]) + (arena.call("get_enemy_slots") as Array[Control]):
		if bool(slot.get_meta("is_current_unit", false)):
			highlighted += 1
	return (arena.call("get_turn_queue") as Array).is_empty() and arena.call("get_current_unit") == null and label != null and label.text == "No active units" and button != null and button.disabled and highlighted == 0 and int(arena.get("round_number")) == round_before


func _test_initial_current_unit_display() -> void:
	var arena: Control = await _instantiate_arena()
	var current: RefCounted = arena.call("get_current_unit") as RefCounted if arena != null and arena.has_method("get_current_unit") else null
	var label: Label = arena.get_node_or_null("%CurrentUnitLabel") as Label if arena != null else null
	var correct: bool = current != null and current.get("unit_id") == &"player_4" and label != null and label.text.contains("Player Back 2") and label.text.contains("Speed 9")
	_assert(correct, "initial current unit display", "queue head and visible label must identify player_4")
	if arena != null:
		arena.queue_free()


func _test_advance_button_moves_once() -> void:
	var arena: Control = await _instantiate_arena()
	var button: Button = arena.get_node_or_null("%AdvanceTurnDebugButton") as Button if arena != null else null
	if button != null:
		button.pressed.emit()
		await process_frame
	var current: RefCounted = arena.call("get_current_unit") as RefCounted if arena != null and arena.has_method("get_current_unit") else null
	_assert(current != null and current.get("unit_id") == &"enemy_4", "advance button moves once", "one press must advance from player_4 to enemy_4")
	if arena != null:
		arena.queue_free()


func _test_highlight_moves() -> void:
	var arena: Control = await _instantiate_arena()
	var before: Control = _highlighted_slot(arena)
	if arena != null and arena.has_method("advance_turn"):
		arena.call("advance_turn")
	var after: Control = _highlighted_slot(arena)
	_assert(before != null and after != null and before != after and not bool(before.get_meta("is_current_unit", false)) and bool(after.get_meta("is_current_unit", false)), "highlight moves", "exact highlight must move to the new unit")
	if arena != null:
		arena.queue_free()


func _highlighted_slot(arena: Control) -> Control:
	if arena == null:
		return null
	for slot: Control in (arena.call("get_player_slots") as Array[Control]) + (arena.call("get_enemy_slots") as Array[Control]):
		if bool(slot.get_meta("is_current_unit", false)):
			return slot
	return null


func _test_round_wraps() -> void:
	var arena: Control = await _instantiate_arena()
	if arena != null and arena.has_method("advance_turn"):
		for index: int in 12:
			arena.call("advance_turn")
	var current: RefCounted = arena.call("get_current_unit") as RefCounted if arena != null and arena.has_method("get_current_unit") else null
	var round_label: Label = arena.get_node_or_null("%RoundLabel") as Label if arena != null else null
	var correct: bool = current != null and current.get("unit_id") == &"player_4" and int(arena.get("round_number")) == 2 and round_label != null and round_label.text == "Round 2"
	_assert(correct, "round wraps", "twelfth advance must select queue head in Round 2")
	if arena != null:
		arena.queue_free()


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC2.2 speed order tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
