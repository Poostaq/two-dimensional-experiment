class_name Ac3_4DefaultActionsTests
extends SceneTree

const ARENA_PATH: String = "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT: int = 5

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_controls_are_separate_from_character_skills()
	await _test_default_attack_pointer_flow()
	await _test_adjacent_swap_pointer_flow()
	await _test_invalid_swap_does_not_mutate()
	await _test_turn_change_clears_default_action()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _test_controls_are_separate_from_character_skills() -> void:
	var arena: BattleArena = await _instantiate_arena()
	var skills: Array[CharacterSkill] = []
	for index: int in range(4):
		skills.append(CharacterSkill.new(
			StringName("skill_%d" % index), "Skill %d" % index,
			CharacterSkill.Kind.ACTIVE, "Effect.", "Target.", "None", "None"
		))
	arena.configure_units(_typed_units([
		_unit(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 10, skills),
		_unit(&"ally", "Ally", BattleUnitState.Side.PLAYER, 1, 8),
		_unit(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5),
	]))
	var skill_row := arena.get_node_or_null("%SkillInspectorSkills") as HBoxContainer
	_assert(
		is_instance_valid(arena.get_node_or_null("%DefaultAttackButton"))
			and is_instance_valid(arena.get_node_or_null("%DefaultSwapButton"))
			and is_instance_valid(skill_row)
			and skill_row.get_child_count() == 4,
		"default controls coexist with four character skills"
	)
	_free_arena(arena)


func _test_default_attack_pointer_flow() -> void:
	var arena: BattleArena = await _instantiate_arena()
	var actor := _unit(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 10)
	actor.power = 6
	var target := _unit(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5)
	target.defense = 2
	arena.configure_units(_typed_units([actor, target]))
	(arena.get_node("%DefaultAttackButton") as Button).pressed.emit()
	_click_slot(_find_slot(arena.get_enemy_slots(), target.unit_id))
	var before_hp: int = target.current_hp
	(arena.get_node("%DefaultActionConfirmButton") as Button).pressed.emit()
	_assert(
		before_hp == target.max_hp
			and target.current_hp == target.max_hp - 4
			and arena.get_action_records().back().kind == BattleActionRecord.Kind.DEFAULT_ATTACK,
		"default attack previews then confirms through the UI"
	)
	_free_arena(arena)


func _test_adjacent_swap_pointer_flow() -> void:
	var arena: BattleArena = await _instantiate_arena()
	var actor := _unit(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 10)
	var ally := _unit(&"ally", "Ally", BattleUnitState.Side.PLAYER, 3, 8)
	var enemy := _unit(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5)
	arena.configure_units(_typed_units([actor, ally, enemy]))
	(arena.get_node("%DefaultSwapButton") as Button).pressed.emit()
	_click_slot(_find_slot(arena.get_player_slots(), ally.unit_id))
	(arena.get_node("%DefaultActionConfirmButton") as Button).pressed.emit()
	_assert(
		actor.slot_index == 3
			and ally.slot_index == 0
			and arena.get_action_records().back().kind == BattleActionRecord.Kind.DEFAULT_SWAP,
		"default swap exchanges adjacent allied slots through the UI"
	)
	_free_arena(arena)


func _test_invalid_swap_does_not_mutate() -> void:
	var arena: BattleArena = await _instantiate_arena()
	var actor := _unit(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 10)
	var ally := _unit(&"ally", "Ally", BattleUnitState.Side.PLAYER, 2, 8)
	var enemy := _unit(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5)
	arena.configure_units(_typed_units([actor, ally, enemy]))
	(arena.get_node("%DefaultSwapButton") as Button).pressed.emit()
	_click_slot(_find_slot(arena.get_player_slots(), ally.unit_id))
	var confirm := arena.get_node("%DefaultActionConfirmButton") as Button
	_assert(
		actor.slot_index == 0
			and ally.slot_index == 2
			and arena.get_action_records().is_empty()
			and confirm.disabled,
		"non-adjacent swap cannot mutate or confirm"
	)
	_free_arena(arena)


func _test_turn_change_clears_default_action() -> void:
	var arena: BattleArena = await _instantiate_arena()
	arena.configure_units(_typed_units([
		_unit(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 10),
		_unit(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5),
	]))
	(arena.get_node("%DefaultAttackButton") as Button).pressed.emit()
	arena.advance_turn()
	_assert(
		not (arena.get_node("%DefaultActionConfirmation") as HBoxContainer).visible,
		"turn changes clear default action selection"
	)
	_free_arena(arena)


func _unit(
	unit_id: StringName,
	display_name: String,
	side: BattleUnitState.Side,
	slot_index: int,
	speed: int,
	skills: Array[CharacterSkill] = []
) -> BattleUnitState:
	return BattleUnitState.new(unit_id, display_name, side, slot_index, speed, 20, skills)


func _typed_units(values: Array) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for value: Variant in values:
		result.append(value as BattleUnitState)
	return result


func _find_slot(slots: Array[Control], unit_id: StringName) -> Control:
	for slot: Control in slots:
		if slot.get_meta("unit_id", &"") == unit_id:
			return slot
	return null


func _click_slot(slot: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	slot.gui_input.emit(click)


func _instantiate_arena() -> BattleArena:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	return arena


func _free_arena(arena: BattleArena) -> void:
	arena.queue_free()


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _report() -> void:
	if _failures.is_empty():
		print("AC3.4 default actions: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
