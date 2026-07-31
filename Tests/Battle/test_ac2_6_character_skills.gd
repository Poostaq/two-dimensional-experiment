class_name Ac2_6CharacterSkillTests
extends SceneTree

const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 19

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_active_and_passive_identity()
	_test_blank_definition_validation()
	_test_invalid_kind_validation()
	_test_zero_through_four_skills_are_valid()
	_test_invalid_roster_elements_are_rejected()
	_test_duplicate_and_oversized_rosters_are_rejected()
	_test_roster_is_copied_for_both_sides()
	_test_runtime_safe_rejection()
	_test_defensive_skill_object_copying()
	await _test_exact_debug_fixtures()
	await _test_persistent_inspector_scene_contract()
	await _test_neutral_and_populated_inspection()
	await _test_zero_skill_and_empty_slot_behavior()
	await _test_reconfiguration_clears_inspection()
	await _test_retained_defeat_updates_status()
	await _test_four_skill_tile_contract()
	await _test_non_actionable_skill_selection()
	await _test_skill_selection_lifecycle_and_viewport()
	await _test_four_skill_layout_fits_viewport()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _test_active_and_passive_identity() -> void:
	var active := _test_skill(&"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE)
	var passive := _test_skill(&"frontline_guard", "Frontline Guard", CharacterSkill.Kind.PASSIVE)
	_assert(active.skill_id == &"shield_bash" and active.display_name == "Shield Bash"
		and active.kind == CharacterSkill.Kind.ACTIVE and passive.kind == CharacterSkill.Kind.PASSIVE,
		"Typed skill identity", "valid definitions must preserve identity and kind")


func _test_blank_definition_validation() -> void:
	_assert(not _is_valid_test_definition(&"", "Name", CharacterSkill.Kind.ACTIVE)
		and not _is_valid_test_definition(&" ", "Name", CharacterSkill.Kind.ACTIVE)
		and not _is_valid_test_definition(&"\t", "Name", CharacterSkill.Kind.ACTIVE)
		and not _is_valid_test_definition(&"valid", "", CharacterSkill.Kind.ACTIVE)
		and not _is_valid_test_definition(&"valid", " ", CharacterSkill.Kind.ACTIVE)
		and not _is_valid_test_definition(&"valid", "\t", CharacterSkill.Kind.ACTIVE),
		"Blank definitions are invalid", "empty and whitespace-only values must be rejected")


func _test_invalid_kind_validation() -> void:
	_assert(not _is_valid_test_definition(&"valid", "Valid", -1)
		and not _is_valid_test_definition(&"valid", "Valid", 2),
		"Unknown kinds are invalid", "only Active and Passive are accepted")


func _test_zero_through_four_skills_are_valid() -> void:
	var valid := true
	for count: int in 5:
		valid = valid and BattleUnitState.is_valid_skill_roster(_skills(count))
	_assert(valid, "Zero through four skills are valid", "all allowed sizes must pass")


func _test_invalid_roster_elements_are_rejected() -> void:
	var valid_skill := _test_skill(&"valid", "Valid", CharacterSkill.Kind.ACTIVE)
	_assert(not BattleUnitState.is_valid_skill_roster([valid_skill, null])
		and not BattleUnitState.is_valid_skill_roster([valid_skill, "wrong type"]),
		"Invalid roster elements are rejected", "null and wrong-type entries reject the roster")


func _test_duplicate_and_oversized_rosters_are_rejected() -> void:
	var first := _test_skill(&"duplicate", "First", CharacterSkill.Kind.ACTIVE)
	var second := _test_skill(&"duplicate", "Second", CharacterSkill.Kind.PASSIVE)
	_assert(not BattleUnitState.is_valid_skill_roster([first, second])
		and not BattleUnitState.is_valid_skill_roster(_skills(5)),
		"Duplicate and oversized rosters are rejected", "duplicate IDs and a fifth skill are invalid")


func _test_roster_is_copied_for_both_sides() -> void:
	var source: Array[CharacterSkill] = _skills(2)
	var player := BattleUnitState.new(&"player", "Player", BattleUnitState.Side.PLAYER, 0, 9, 20, source)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 8, 20, source)
	source.clear()
	_assert(player.skills.size() == 2 and enemy.skills.size() == 2
		and player.skills[0].skill_id == &"skill_0" and enemy.skills[0].skill_id == &"skill_0"
		and player.skills[0] != enemy.skills[0],
		"Rosters are copied for both sides", "caller mutation must not alter either independently copied roster")


func _test_runtime_safe_rejection() -> void:
	var blank_id := _create_test_skill(&" ", "Name", CharacterSkill.Kind.ACTIVE)
	var blank_name := _create_test_skill(&"valid", " ", CharacterSkill.Kind.ACTIVE)
	var invalid_kind := _create_test_skill(&"valid", "Name", -1)
	var unit := BattleUnitState.new(&"unit", "Unit", BattleUnitState.Side.PLAYER, 0, 8)
	var duplicate: Array[CharacterSkill] = [
		_test_skill(&"same", "One", CharacterSkill.Kind.ACTIVE),
		_test_skill(&"same", "Two", CharacterSkill.Kind.PASSIVE),
	]
	var invalid_entry: Array = [_test_skill(&"valid", "Valid", CharacterSkill.Kind.ACTIVE), null]
	var rejected := not unit.set_skills(duplicate) and not unit.set_skills(invalid_entry) and not unit.set_skills(_skills(5))
	_assert(blank_id == null and blank_name == null and invalid_kind == null and rejected and unit.skills.is_empty(),
		"Runtime-safe rejection", "invalid definitions and rosters must fail without relying on assertions")


func _test_defensive_skill_object_copying() -> void:
	var source := _test_skill(&"source", "Source", CharacterSkill.Kind.ACTIVE)
	var roster: Array[CharacterSkill] = [source]
	var unit := BattleUnitState.new(&"unit", "Unit", BattleUnitState.Side.PLAYER, 0, 8, 20, roster)
	source._skill_id = &"mutated"
	source._display_name = "Mutated"
	source._kind = CharacterSkill.Kind.PASSIVE
	var returned := unit.skills
	returned.clear()
	var stored := unit.skills[0]
	_assert(unit.skills.size() == 1 and stored.skill_id == &"source" and stored.display_name == "Source"
		and stored.kind == CharacterSkill.Kind.ACTIVE,
		"Defensive skill object copying", "caller-held objects and returned arrays must not mutate stored metadata")


func _test_exact_debug_fixtures() -> void:
	var arena := await _instantiate_arena()
	var expected := {
		&"player_0": [[&"shield_bash", 0], [&"frontline_guard", 1]], &"player_1": [],
		&"player_2": [[&"quick_step", 0]], &"player_3": [],
		&"player_4": [[&"quick_strike", 0], [&"rally", 0], [&"evasion", 1], [&"momentum", 1]], &"player_5": [],
		&"enemy_0": [[&"savage_blow", 0], [&"blood_scent", 1]], &"enemy_1": [],
		&"enemy_2": [[&"brace", 1]], &"enemy_3": [], &"enemy_4": [[&"shadow_lunge", 0]], &"enemy_5": [],
	}
	var actual: Dictionary = {}
	for unit_id: StringName in expected:
		var unit := arena.call("get_unit_by_id", unit_id) as BattleUnitState
		if is_instance_valid(unit):
			actual[unit_id] = _skill_signature(unit.skills)
		else:
			actual[unit_id] = null
	_assert(actual == expected, "Exact debug fixtures", "all twelve fixture rosters must match")
	_free_arena(arena)


func _test_persistent_inspector_scene_contract() -> void:
	var arena := await _instantiate_arena()
	var panel := arena.get_node_or_null("%SkillInspectorPanel")
	_assert(panel is PanelContainer and panel.owner != null
		and arena.get_node_or_null("%SkillInspectorPromptLabel") is Label
		and arena.get_node_or_null("%SkillInspectorUnitNameLabel") is Label
		and arena.get_node_or_null("%SkillInspectorStatusLabel") is Label
		and arena.get_node_or_null("%SkillInspectorCountLabel") is Label
		and arena.get_node_or_null("%SkillInspectorBody") is HBoxContainer
		and arena.get_node_or_null("%SkillInspectorCharacterBlock") is VBoxContainer
		and arena.get_node_or_null("%SkillInspectorSkills") is HBoxContainer
		and arena.get_node_or_null("%SkillInspectorEmptyLabel") is Label,
		"Persistent inspector scene contract", "the exact scene-owned subtree must exist")
	_free_arena(arena)


func _test_neutral_and_populated_inspection() -> void:
	var arena := await _instantiate_arena()
	var prompt := arena.get_node_or_null("%SkillInspectorPromptLabel") as Label
	var neutral: bool = arena.call("get_inspected_unit_id") == &"" and prompt.visible
	arena.call("inspect_unit", &"player_4")
	var rows := arena.get_node_or_null("%SkillInspectorSkills") as HBoxContainer
	var populated := (arena.get_node_or_null("%SkillInspectorUnitNameLabel") as Label).text == "Player Back 2"
	populated = populated and (arena.get_node_or_null("%SkillInspectorCountLabel") as Label).text == "Skills: 4/4"
	populated = populated and rows.get_child_count() == 4
	arena.call("inspect_unit", &"enemy_0")
	populated = populated and (arena.get_node_or_null("%SkillInspectorUnitNameLabel") as Label).text == "Enemy Front 1"
	_assert(neutral and populated, "Neutral and populated inspection", "both sides must render from neutral state")
	_free_arena(arena)


func _test_zero_skill_and_empty_slot_behavior() -> void:
	var arena := await _instantiate_arena()
	arena.call("inspect_unit", &"player_1")
	var before: StringName = arena.call("get_inspected_unit_id")
	var empty_event := InputEventMouseButton.new()
	empty_event.button_index = MOUSE_BUTTON_LEFT
	empty_event.pressed = true
	var empty_slot := (arena.call("get_player_slots") as Array)[0] as Control
	empty_slot.set_meta("unit_id", &"")
	arena.call("_on_slot_gui_input", empty_event, empty_slot)
	_assert(before == &"player_1" and arena.call("get_inspected_unit_id") == before
		and (arena.get_node_or_null("%SkillInspectorEmptyLabel") as Label).visible,
		"Zero-skill and empty-slot behavior", "empty state is explicit and empty slots are no-ops")
	_free_arena(arena)


func _test_reconfiguration_clears_inspection() -> void:
	var arena := await _instantiate_arena()
	arena.call("inspect_unit", &"player_4")
	arena.call("configure_units", _typed_units([BattleUnitState.new(&"fresh", "Fresh", BattleUnitState.Side.PLAYER, 0, 9)]))
	_assert(arena.call("get_inspected_unit_id") == &""
		and (arena.get_node_or_null("%SkillInspectorPromptLabel") as Label).visible,
		"Reconfiguration clears inspection", "reused arenas must return to neutral")
	_free_arena(arena)


func _test_retained_defeat_updates_status() -> void:
	var arena := await _instantiate_arena()
	var player := BattleUnitState.new(&"player", "Player", BattleUnitState.Side.PLAYER, 0, 9)
	var enemy_skills: Array[CharacterSkill] = [_test_skill(&"brace", "Brace", CharacterSkill.Kind.PASSIVE)]
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 8, 20, enemy_skills)
	enemy.current_hp = 6
	arena.call("configure_units", _typed_units([player, enemy]))
	arena.call("inspect_unit", &"enemy")
	arena.call("perform_debug_damage")
	_assert(arena.call("get_inspected_unit_id") == &"enemy"
		and (arena.get_node_or_null("%SkillInspectorStatusLabel") as Label).text == "Defeated"
		and (arena.get_node_or_null("%SkillInspectorSkills") as HBoxContainer).get_child_count() == 1,
		"Retained defeat updates status", "defeated retained units keep rows and show Defeated")
	_free_arena(arena)


func _test_four_skill_tile_contract() -> void:
	var arena := await _instantiate_arena()
	arena.call("inspect_unit", &"player_4")
	var skills := arena.get_node_or_null("%SkillInspectorSkills") as HBoxContainer
	var expected := [
		[&"quick_strike", "1", "Quick Strike", "Active"],
		[&"rally", "2", "Rally", "Active"],
		[&"evasion", "3", "Evasion", "Passive"],
		[&"momentum", "4", "Momentum", "Passive"],
	]
	var valid := is_instance_valid(skills) and skills.get_child_count() == 4
	if valid:
		for index: int in expected.size():
			var button := skills.get_child(index) as Button
			valid = valid and is_instance_valid(button) and button.custom_minimum_size == Vector2(88.0, 88.0)
			valid = valid and int(button.get_meta("skill_index", 0)) == index + 1
			valid = valid and button.get_meta("skill_id", &"") == expected[index][0]
			valid = valid and (button.get_node("NumberLabel") as Label).text == expected[index][1]
			valid = valid and (button.get_node("NameLabel") as Label).text == expected[index][2]
			valid = valid and (button.get_node("KindLabel") as Label).text == expected[index][3]
	_assert(valid, "Four-skill tile contract", "player_4 must render four exact numbered square buttons")
	_free_arena(arena)


func _test_non_actionable_skill_selection() -> void:
	var arena := await _instantiate_arena()
	arena.call("inspect_unit", &"player_4")
	var before_round: int = arena.round_number
	var before_current: BattleUnitState = arena.call("get_current_unit")
	var before_hp: Array[int] = []
	for unit_id: StringName in [&"player_4", &"enemy_0"]:
		before_hp.append((arena.call("get_unit_by_id", unit_id) as BattleUnitState).current_hp)
	var before_log: Array = arena.call("get_battle_log_entries")
	var before_outcome: int = arena.call("get_battle_outcome")
	var skills := arena.get_node_or_null("%SkillInspectorSkills") as HBoxContainer
	(skills.get_child(1) as Button).pressed.emit()
	var selected_count := 0
	for child: Node in skills.get_children():
		if bool(child.get_meta("selected", false)):
			selected_count += 1
	_assert(arena.call("get_selected_skill_id") == &"rally" and selected_count == 1
		and bool(skills.get_child(1).get_meta("selected", false))
		and arena.round_number == before_round and arena.call("get_current_unit") == before_current
		and (arena.call("get_unit_by_id", &"player_4") as BattleUnitState).current_hp == before_hp[0]
		and (arena.call("get_unit_by_id", &"enemy_0") as BattleUnitState).current_hp == before_hp[1]
		and arena.call("get_battle_log_entries") == before_log and arena.call("get_battle_outcome") == before_outcome,
		"Non-actionable skill selection", "selection must only highlight one button and change inspector state")
	_free_arena(arena)


func _test_skill_selection_lifecycle_and_viewport() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	var arena := await _instantiate_arena()
	arena.call("inspect_unit", &"player_4")
	arena.call("select_skill", &"rally")
	arena.call("inspect_unit", &"enemy_0")
	var changed_character_clears: bool = arena.call("get_selected_skill_id") == &""
	arena.call("select_skill", &"savage_blow")
	var enemy := arena.call("get_unit_by_id", &"enemy_0") as BattleUnitState
	enemy.current_hp = 0
	arena.call("_refresh_turn_ui")
	var retained: bool = arena.call("get_selected_skill_id") == &"savage_blow"
	retained = retained and (arena.get_node_or_null("%SkillInspectorStatusLabel") as Label).text == "Defeated"
	retained = retained and (arena.get_node_or_null("%SkillInspectorSkills") as HBoxContainer).get_child_count() == 2
	arena.call("configure_units", _typed_units([BattleUnitState.new(&"fresh", "Fresh", BattleUnitState.Side.PLAYER, 0, 9)]))
	var cleared: bool = arena.call("get_inspected_unit_id") == &"" and arena.call("get_selected_skill_id") == &""
	var battle_log := arena.get_node_or_null("Margin/VBox/BattleLogPanel") as Control
	_assert(changed_character_clears and retained and cleared and battle_log.position.y + battle_log.size.y <= 648.0,
		"Skill selection lifecycle and viewport", "character changes clear selection, retained defeat preserves it, and reconfigure clears it")
	_free_arena(arena)


func _test_four_skill_layout_fits_viewport() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	var arena := await _instantiate_arena()
	arena.call("inspect_unit", &"player_4")
	await process_frame
	var main_vbox := arena.get_node_or_null("Margin/VBox") as Control
	var battle_log := arena.get_node_or_null("Margin/VBox/BattleLogPanel") as Control
	_assert(main_vbox.size.y <= 648.0 and battle_log.position.y + battle_log.size.y <= 648.0,
		"Four-skill layout fits viewport", "VBox %.1f, log bottom %.1f must be <= 648" % [main_vbox.size.y, battle_log.position.y + battle_log.size.y])
	_free_arena(arena)


func _typed_units(values: Array) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for value: Variant in values:
		result.append(value as BattleUnitState)
	return result


func _test_skill(id: StringName, name: String, kind: int) -> CharacterSkill:
	return CharacterSkill.new(id, name, kind, "Test effect.", "Test target.", "None", "None")


func _create_test_skill(id: StringName, name: String, kind: int) -> CharacterSkill:
	return CharacterSkill.create(id, name, kind, "Test effect.", "Test target.", "None", "None")


func _is_valid_test_definition(id: StringName, name: String, kind: int) -> bool:
	return CharacterSkill.is_valid_definition(
		id, name, kind, "Test effect.", "Test target.", "None", "None"
	)


func _skills(count: int) -> Array[CharacterSkill]:
	var result: Array[CharacterSkill] = []
	for index: int in count:
		result.append(_test_skill(StringName("skill_%d" % index), "Skill %d" % index,
			CharacterSkill.Kind.ACTIVE if index % 2 == 0 else CharacterSkill.Kind.PASSIVE))
	return result


func _skill_signature(skills: Array[CharacterSkill]) -> Array:
	var result: Array = []
	for skill: CharacterSkill in skills:
		result.append([skill.skill_id, int(skill.kind)])
	return result


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
		print("AC2.6 character skill tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
