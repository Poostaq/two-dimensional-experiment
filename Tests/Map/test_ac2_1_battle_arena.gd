class_name Ac2_1BattleArenaTests
extends SceneTree

const GAME_WORLD_PATH := "res://Scenes/game_world.tscn"
const BATTLE_ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 12

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_player_side_has_six_slots()
	_test_enemy_side_has_six_slots()
	_test_slot_indices_are_unique()
	_test_default_enemy_fixture_has_front_and_back()
	await _test_combat_enters_battle()
	await _test_boss_enters_battle()
	_test_safe_cannot_enter_battle()
	await _test_overlay_closes_on_battle_entry()
	await _test_navigation_is_blocked_during_battle()
	await _test_duplicate_request_is_ignored()
	await _test_debug_exit_preserves_map_state()
	await _test_run_reset_clears_battle()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _instantiate_arena() -> Control:
	var packed := load(BATTLE_ARENA_PATH) as PackedScene
	if packed == null:
		return null
	var arena := packed.instantiate() as Control
	if arena != null:
		root.add_child(arena)
	return arena


func _instantiate_world() -> Node:
	var packed := load(GAME_WORLD_PATH) as PackedScene
	if packed == null:
		return null
	var controller := packed.instantiate()
	root.add_child(controller)
	await process_frame
	return controller


func _open_typed_encounter(controller: Node, encounter_type: String) -> Node:
	controller.call("_open_encounter", Vector2i(0, 1), encounter_type)
	await process_frame
	return controller.call("get_active_encounter")


func _request_battle(overlay: Node, encounter_type: String) -> void:
	overlay.emit_signal("battle_requested", Vector2i(0, 1), encounter_type)
	await process_frame


func _test_player_side_has_six_slots() -> void:
	var arena := _instantiate_arena()
	_assert(arena != null, "player side has six slots", "battle arena scene must instantiate")
	if arena != null:
		var slots: Array = arena.call("get_player_slots")
		_assert(slots.size() == 6, "player side has six slots", "expected 6, got %d" % slots.size())
		var background := arena.get_node("Background") as Control
		var margin := arena.get_node("Margin") as Control
		_assert(background.anchor_right == 1.0 and background.anchor_bottom == 1.0 and background.offset_right == 0.0 and background.offset_bottom == 0.0, "player side has six slots", "background must fill the viewport")
		_assert(margin.anchor_right == 1.0 and margin.anchor_bottom == 1.0 and margin.offset_right == 0.0 and margin.offset_bottom == 0.0, "player side has six slots", "arena content must fill the viewport")
		arena.queue_free()


func _test_enemy_side_has_six_slots() -> void:
	var arena := _instantiate_arena()
	_assert(arena != null, "enemy side has six slots", "battle arena scene must instantiate")
	if arena != null:
		var slots: Array = arena.call("get_enemy_slots")
		_assert(slots.size() == 6, "enemy side has six slots", "expected 6, got %d" % slots.size())
		arena.queue_free()


func _test_slot_indices_are_unique() -> void:
	var arena := _instantiate_arena()
	_assert(arena != null, "slot indices are unique", "battle arena scene must instantiate")
	if arena != null:
		for method_name: String in ["get_player_slots", "get_enemy_slots"]:
			var indices: Array[int] = []
			for slot: Control in arena.call(method_name):
				indices.append(int(slot.get_meta("slot_index", -1)))
			indices.sort()
			_assert(indices == [0, 1, 2, 3, 4, 5], "slot indices are unique", "%s returned %s" % [method_name, indices])
		arena.queue_free()


func _test_default_enemy_fixture_has_front_and_back() -> void:
	var arena := _instantiate_arena()
	var enemy_units: Array[BattleUnitState] = []
	for unit: BattleUnitState in arena.call("get_turn_queue"):
		if unit.side == BattleUnitState.Side.ENEMY:
			enemy_units.append(unit)
	var enemy_ids: Array[StringName] = []
	var enemy_slots: Array[int] = []
	for unit: BattleUnitState in enemy_units:
		enemy_ids.append(unit.unit_id)
		enemy_slots.append(unit.slot_index)
	enemy_slots.sort()
	var unoccupied_count := 0
	for slot: Control in arena.call("get_enemy_slots"):
		if String(slot.get_meta("unit_id", &"")).is_empty():
			unoccupied_count += 1
	_assert(
		enemy_ids.size() == 2
		and enemy_ids.has(&"enemy_0")
		and enemy_ids.has(&"enemy_4")
		and enemy_slots == [0, 4]
		and unoccupied_count == 4,
		"default enemy fixture has front and back",
		"expected enemy_0/slot 0, enemy_4/slot 4, and four unoccupied slots; got IDs=%s slots=%s unoccupied=%d" % [enemy_ids, enemy_slots, unoccupied_count]
	)
	arena.queue_free()


func _test_combat_enters_battle() -> void:
	var controller := await _instantiate_world()
	var overlay := await _open_typed_encounter(controller, HexMapModel.ENCOUNTER_COMBAT)
	var eligible := overlay != null and overlay.has_method("can_enter_battle") and bool(overlay.call("can_enter_battle"))
	_assert(eligible, "combat enters battle", "combat overlay must be eligible")
	if overlay != null and overlay.has_signal("battle_requested"):
		await _request_battle(overlay, HexMapModel.ENCOUNTER_COMBAT)
	var active := controller.has_method("has_active_battle") and bool(controller.call("has_active_battle"))
	_assert(active, "combat enters battle", "combat request must create a battle")
	if active:
		var arena: Node = controller.call("get_active_battle")
		_assert(arena.get("encounter_type") == HexMapModel.ENCOUNTER_COMBAT, "combat enters battle", "arena must retain canonical combat type")
	controller.queue_free()


func _test_boss_enters_battle() -> void:
	var controller := await _instantiate_world()
	var overlay := await _open_typed_encounter(controller, HexMapModel.ENCOUNTER_BOSS)
	var eligible := overlay != null and overlay.has_method("can_enter_battle") and bool(overlay.call("can_enter_battle"))
	_assert(eligible, "boss enters battle", "boss overlay must be eligible")
	if overlay != null and overlay.has_signal("battle_requested"):
		await _request_battle(overlay, HexMapModel.ENCOUNTER_BOSS)
	var active := controller.has_method("has_active_battle") and bool(controller.call("has_active_battle"))
	_assert(active, "boss enters battle", "boss request must create a battle")
	if active:
		var arena: Node = controller.call("get_active_battle")
		_assert(arena.get("encounter_type") == HexMapModel.ENCOUNTER_BOSS, "boss enters battle", "arena must retain canonical boss type")
	controller.queue_free()


func _test_safe_cannot_enter_battle() -> void:
	var packed := load("res://Scenes/encounter_overlay.tscn") as PackedScene
	var overlay := packed.instantiate()
	root.add_child(overlay)
	overlay.call("configure", Vector2i(0, 1), HexMapModel.ENCOUNTER_SAFE)
	var has_eligibility_api := overlay.has_method("can_enter_battle")
	_assert(has_eligibility_api and not bool(overlay.call("can_enter_battle")) if has_eligibility_api else false, "safe cannot enter battle", "safe must remain ineligible")
	overlay.call("configure", Vector2i(0, 1), "Combat")
	_assert(has_eligibility_api and not bool(overlay.call("can_enter_battle")) if has_eligibility_api else false, "safe cannot enter battle", "noncanonical type must remain ineligible")
	overlay.queue_free()


func _test_overlay_closes_on_battle_entry() -> void:
	var controller := await _instantiate_world()
	var overlay := await _open_typed_encounter(controller, HexMapModel.ENCOUNTER_COMBAT)
	if overlay != null and overlay.has_signal("battle_requested"):
		await _request_battle(overlay, HexMapModel.ENCOUNTER_COMBAT)
	var closed := not bool(controller.call("has_active_encounter"))
	_assert(closed, "overlay closes on battle entry", "encounter overlay must close")
	controller.queue_free()


func _test_navigation_is_blocked_during_battle() -> void:
	var controller := await _instantiate_world()
	var overlay := await _open_typed_encounter(controller, HexMapModel.ENCOUNTER_COMBAT)
	if overlay != null and overlay.has_signal("battle_requested"):
		await _request_battle(overlay, HexMapModel.ENCOUNTER_COMBAT)
	var before_coord: Vector2i = controller.get("player_coord")
	var before_count: int = controller.get("move_count")
	var moved: bool = controller.call("request_move", Vector2i(0, 1))
	_assert(not moved and controller.get("player_coord") == before_coord and controller.get("move_count") == before_count, "navigation is blocked during battle", "battle must block map mutation")
	controller.queue_free()


func _test_duplicate_request_is_ignored() -> void:
	var controller := await _instantiate_world()
	var overlay := await _open_typed_encounter(controller, HexMapModel.ENCOUNTER_COMBAT)
	if overlay != null and overlay.has_signal("battle_requested"):
		await _request_battle(overlay, HexMapModel.ENCOUNTER_COMBAT)
	var has_api := controller.has_method("get_active_battle") and controller.has_method("_on_battle_requested")
	var first: Node = controller.call("get_active_battle") if has_api else null
	if has_api:
		controller.call("_on_battle_requested", Vector2i(0, 1), HexMapModel.ENCOUNTER_BOSS)
		await process_frame
	_assert(has_api and controller.call("get_active_battle") == first if has_api else false, "duplicate request is ignored", "active arena must not be replaced")
	controller.queue_free()


func _test_debug_exit_preserves_map_state() -> void:
	var controller := await _instantiate_world()
	controller.set("player_coord", Vector2i(1, 1))
	controller.set("move_count", 4)
	var overlay := await _open_typed_encounter(controller, HexMapModel.ENCOUNTER_COMBAT)
	if overlay != null and overlay.has_signal("battle_requested"):
		await _request_battle(overlay, HexMapModel.ENCOUNTER_COMBAT)
	var has_api := controller.has_method("exit_active_battle") and controller.has_method("has_active_battle")
	if has_api:
		controller.call("exit_active_battle")
		await process_frame
	_assert(has_api and not bool(controller.call("has_active_battle")) if has_api else false, "debug exit preserves map state", "arena must be removed")
	_assert(controller.get("player_coord") == Vector2i(1, 1) and controller.get("move_count") == 4, "debug exit preserves map state", "map state changed")
	controller.queue_free()


func _test_run_reset_clears_battle() -> void:
	var controller := await _instantiate_world()
	var overlay := await _open_typed_encounter(controller, HexMapModel.ENCOUNTER_COMBAT)
	if overlay != null and overlay.has_signal("battle_requested"):
		await _request_battle(overlay, HexMapModel.ENCOUNTER_COMBAT)
	controller.call("set_run_id", "ac2-1-reset")
	var has_api := controller.has_method("has_active_battle")
	_assert(has_api and not bool(controller.call("has_active_battle")) if has_api else false, "run reset clears battle", "active arena survived reset")
	_assert(controller.get("player_coord") == Vector2i.ZERO and controller.get("move_count") == 0, "run reset clears battle", "normal reset contract failed")
	controller.queue_free()


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC2.1 battle arena tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
