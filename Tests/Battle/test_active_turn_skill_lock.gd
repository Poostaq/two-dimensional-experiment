class_name ActiveTurnSkillLockTests
extends SceneTree

const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 5

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_initial_turn_locks_skill_panel_to_current_unit()
	await _test_non_current_slot_click_cannot_override_active_unit()
	await _test_turn_advance_syncs_skill_panel_for_player_and_enemy()
	await _test_current_unit_removal_rebuilds_queue_and_syncs_skill_panel()
	await _test_no_current_unit_or_battle_end_clears_skill_panel()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _test_initial_turn_locks_skill_panel_to_current_unit() -> void:
	var arena := await _instantiate_arena()
	arena.call("configure_units", _typed_units([
		_unit(&"player_fast", "Player Fast", BattleUnitState.Side.PLAYER, 0, 10),
		_unit(&"enemy_slow", "Enemy Slow", BattleUnitState.Side.ENEMY, 0, 8),
	]))
	var current := arena.call("get_current_unit") as BattleUnitState
	var initial_owner_synced: bool = (
		is_instance_valid(current)
		and current.unit_id == &"player_fast"
		and arena.call("get_inspected_unit_id") == current.unit_id
	)
	current.current_hp = 0
	arena.call("_refresh_turn_ui")
	var status_label := arena.get_node_or_null("%SkillInspectorStatusLabel") as Label
	_assert(
		initial_owner_synced
			and is_instance_valid(status_label)
			and status_label.text == "Defeated",
		"Initial turn locks skill panel to current unit",
		"configuration must inspect current and same-turn authoritative refreshes must update presentation"
	)
	_free_arena(arena)


func _test_non_current_slot_click_cannot_override_active_unit() -> void:
	var arena := await _instantiate_arena()
	arena.call("configure_units", _typed_units([
		_unit(&"player_fast", "Player Fast", BattleUnitState.Side.PLAYER, 0, 10),
		_unit(&"enemy_slow", "Enemy Slow", BattleUnitState.Side.ENEMY, 0, 8),
	]))
	var enemy_slot := _find_slot(arena.call("get_enemy_slots") as Array, &"enemy_slow")
	var skill_rows := arena.get_node_or_null("%SkillInspectorSkills") as HBoxContainer
	var original_skill_button := (
		skill_rows.get_child(0) as Button
		if is_instance_valid(skill_rows) and skill_rows.get_child_count() > 0
		else null
	)
	var selected_skill_before: StringName = arena.call("get_selected_skill_id")
	var presentation_before: Dictionary = arena.call("get_skill_presentation_snapshot")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	if is_instance_valid(enemy_slot):
		enemy_slot.gui_input.emit(click)
	var original_button_retained: bool = (
		is_instance_valid(original_skill_button)
		and original_skill_button.get_parent() == skill_rows
		and skill_rows.get_child_count() == 1
		and skill_rows.get_child(0) == original_skill_button
	)
	_assert(
		is_instance_valid(enemy_slot)
			and arena.call("get_inspected_unit_id") == &"player_fast"
			and original_button_retained
			and arena.call("get_selected_skill_id") == selected_skill_before
			and arena.call("get_skill_presentation_snapshot") == presentation_before,
		"Non-current slot click cannot override active unit",
		"a rejected non-current click must preserve inspector ownership and UI identity/state"
	)
	_free_arena(arena)


func _test_turn_advance_syncs_skill_panel_for_player_and_enemy() -> void:
	var arena := await _instantiate_arena()
	arena.call("configure_units", _typed_units([
		_unit(&"player_first", "Player First", BattleUnitState.Side.PLAYER, 0, 10),
		_unit(&"enemy_second", "Enemy Second", BattleUnitState.Side.ENEMY, 0, 9),
		_unit(&"player_third", "Player Third", BattleUnitState.Side.PLAYER, 1, 8),
	]))
	var initial_player_synced: bool = arena.call("get_inspected_unit_id") == &"player_first"
	arena.call("advance_turn")
	var enemy_synced: bool = arena.call("get_inspected_unit_id") == &"enemy_second"
	arena.call("advance_turn")
	var next_player_synced: bool = arena.call("get_inspected_unit_id") == &"player_third"
	_assert(
		initial_player_synced and enemy_synced and next_player_synced,
		"Turn advance syncs skill panel for player and enemy",
		"each turn advance must inspect its player or enemy current unit"
	)
	_free_arena(arena)


func _test_current_unit_removal_rebuilds_queue_and_syncs_skill_panel() -> void:
	var arena := await _instantiate_arena()
	arena.call("configure_units", _typed_units([
		_unit(&"player_current", "Player Current", BattleUnitState.Side.PLAYER, 0, 10),
		_unit(&"enemy_next", "Enemy Next", BattleUnitState.Side.ENEMY, 0, 9),
		_unit(&"player_last", "Player Last", BattleUnitState.Side.PLAYER, 1, 8),
	]))
	var removed: bool = arena.call("remove_battle_unit", &"player_current")
	var current := arena.call("get_current_unit") as BattleUnitState
	_assert(
		removed
			and is_instance_valid(current)
			and current.unit_id == &"enemy_next"
			and arena.call("get_inspected_unit_id") == current.unit_id,
		"Current unit removal rebuilds queue and syncs skill panel",
		"removing the current unit must inspect the rebuilt queue head"
	)
	_free_arena(arena)


func _test_no_current_unit_or_battle_end_clears_skill_panel() -> void:
	var arena := await _instantiate_arena()
	arena.call("configure_units", _typed_units([]))
	var no_current_cleared: bool = (
		arena.call("get_current_unit") == null
		and arena.call("get_inspected_unit_id") == &""
		and (arena.get_node_or_null("%SkillInspectorPromptLabel") as Label).visible
	)
	var enemy := _unit(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 8)
	enemy.current_hp = 1
	arena.call("configure_units", _typed_units([
		_unit(&"player", "Player", BattleUnitState.Side.PLAYER, 0, 10),
		enemy,
	]))
	arena.call("perform_debug_damage")
	var battle_end_cleared: bool = (
		arena.call("is_battle_complete")
		and arena.call("get_inspected_unit_id") == &""
		and (arena.get_node_or_null("%SkillInspectorPromptLabel") as Label).visible
	)
	_assert(
		no_current_cleared and battle_end_cleared,
		"No current unit or battle end clears skill panel",
		"missing current units and completed battles must show the neutral prompt"
	)
	_free_arena(arena)


func _unit(
	unit_id: StringName,
	display_name: String,
	side: BattleUnitState.Side,
	slot_index: int,
	speed: int
) -> BattleUnitState:
	var skills: Array[CharacterSkill] = [
		CharacterSkill.new(
			StringName("%s_skill" % unit_id),
			"%s Skill" % display_name,
			CharacterSkill.Kind.ACTIVE,
			"Test effect.",
			"Test target.",
			"None",
			"None"
		),
	]
	return BattleUnitState.new(unit_id, display_name, side, slot_index, speed, 20, skills)


func _typed_units(values: Array) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for value: Variant in values:
		result.append(value as BattleUnitState)
	return result


func _find_slot(slots: Array, unit_id: StringName) -> Control:
	for value: Variant in slots:
		var slot := value as Control
		if is_instance_valid(slot) and slot.get_meta("unit_id", &"") == unit_id:
			return slot
	return null


func _instantiate_arena() -> Control:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as Control if packed != null else null
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _free_arena(arena: Control) -> void:
	if is_instance_valid(arena):
		arena.queue_free()


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("Active-turn skill lock tests: PASS (%d/%d)" % [
			EXPECTED_TEST_COUNT,
			EXPECTED_TEST_COUNT,
		])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
