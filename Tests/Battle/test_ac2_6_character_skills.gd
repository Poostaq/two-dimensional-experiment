class_name Ac2_6CharacterSkillTests
extends SceneTree

const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 13

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
	await _test_exact_debug_fixtures()
	await _test_persistent_inspector_scene_contract()
	await _test_neutral_and_populated_inspection()
	await _test_zero_skill_and_empty_slot_behavior()
	await _test_reconfiguration_clears_inspection()
	await _test_retained_defeat_updates_status()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _test_active_and_passive_identity() -> void:
	var active := CharacterSkill.new(&"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE)
	var passive := CharacterSkill.new(&"frontline_guard", "Frontline Guard", CharacterSkill.Kind.PASSIVE)
	_assert(active.skill_id == &"shield_bash" and active.display_name == "Shield Bash"
		and active.kind == CharacterSkill.Kind.ACTIVE and passive.kind == CharacterSkill.Kind.PASSIVE,
		"Typed skill identity", "valid definitions must preserve identity and kind")


func _test_blank_definition_validation() -> void:
	_assert(not CharacterSkill.is_valid_definition(&"", "Name", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&" ", "Name", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&"\t", "Name", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&"valid", "", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&"valid", " ", CharacterSkill.Kind.ACTIVE)
		and not CharacterSkill.is_valid_definition(&"valid", "\t", CharacterSkill.Kind.ACTIVE),
		"Blank definitions are invalid", "empty and whitespace-only values must be rejected")


func _test_invalid_kind_validation() -> void:
	_assert(not CharacterSkill.is_valid_definition(&"valid", "Valid", -1)
		and not CharacterSkill.is_valid_definition(&"valid", "Valid", 2),
		"Unknown kinds are invalid", "only Active and Passive are accepted")


func _test_zero_through_four_skills_are_valid() -> void:
	var valid := true
	for count: int in 5:
		valid = valid and BattleUnitState.is_valid_skill_roster(_skills(count))
	_assert(valid, "Zero through four skills are valid", "all allowed sizes must pass")


func _test_invalid_roster_elements_are_rejected() -> void:
	var valid_skill := CharacterSkill.new(&"valid", "Valid", CharacterSkill.Kind.ACTIVE)
	_assert(not BattleUnitState.is_valid_skill_roster([valid_skill, null])
		and not BattleUnitState.is_valid_skill_roster([valid_skill, "wrong type"]),
		"Invalid roster elements are rejected", "null and wrong-type entries reject the roster")


func _test_duplicate_and_oversized_rosters_are_rejected() -> void:
	var first := CharacterSkill.new(&"duplicate", "First", CharacterSkill.Kind.ACTIVE)
	var second := CharacterSkill.new(&"duplicate", "Second", CharacterSkill.Kind.PASSIVE)
	_assert(not BattleUnitState.is_valid_skill_roster([first, second])
		and not BattleUnitState.is_valid_skill_roster(_skills(5)),
		"Duplicate and oversized rosters are rejected", "duplicate IDs and a fifth skill are invalid")


func _test_roster_is_copied_for_both_sides() -> void:
	var source: Array[CharacterSkill] = _skills(2)
	var player := BattleUnitState.new(&"player", "Player", BattleUnitState.Side.PLAYER, 0, 9, 20, source)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 8, 20, source)
	source.clear()
	_assert(player.skills.size() == 2 and enemy.skills.size() == 2 and player.skills[0] == enemy.skills[0],
		"Rosters are copied for both sides", "caller mutation must not alter either roster")


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
		actual[unit_id] = _skill_signature(unit.skills) if is_instance_valid(unit) else null
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
		and arena.get_node_or_null("%SkillInspectorSkills") is VBoxContainer
		and arena.get_node_or_null("%SkillInspectorEmptyLabel") is Label,
		"Persistent inspector scene contract", "the exact scene-owned subtree must exist")
	_free_arena(arena)


func _test_neutral_and_populated_inspection() -> void:
	var arena := await _instantiate_arena()
	var prompt := arena.get_node_or_null("%SkillInspectorPromptLabel") as Label
	var neutral: bool = arena.call("get_inspected_unit_id") == &"" and prompt.visible
	arena.call("inspect_unit", &"player_4")
	var rows := arena.get_node_or_null("%SkillInspectorSkills") as VBoxContainer
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
	var enemy_skills: Array[CharacterSkill] = [CharacterSkill.new(&"brace", "Brace", CharacterSkill.Kind.PASSIVE)]
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 8, 20, enemy_skills)
	enemy.current_hp = 6
	arena.call("configure_units", _typed_units([player, enemy]))
	arena.call("inspect_unit", &"enemy")
	arena.call("perform_debug_damage")
	_assert(arena.call("get_inspected_unit_id") == &"enemy"
		and (arena.get_node_or_null("%SkillInspectorStatusLabel") as Label).text == "Defeated"
		and (arena.get_node_or_null("%SkillInspectorSkills") as VBoxContainer).get_child_count() == 1,
		"Retained defeat updates status", "defeated retained units keep rows and show Defeated")
	_free_arena(arena)


func _typed_units(values: Array) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for value: Variant in values:
		result.append(value as BattleUnitState)
	return result


func _skills(count: int) -> Array[CharacterSkill]:
	var result: Array[CharacterSkill] = []
	for index: int in count:
		result.append(CharacterSkill.new(StringName("skill_%d" % index), "Skill %d" % index,
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
