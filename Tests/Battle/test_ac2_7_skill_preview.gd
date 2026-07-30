class_name Ac2_7SkillPreviewTests
extends SceneTree

const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_PREVIEWS := {
	&"shield_bash": ["Shield Bash", CharacterSkill.Kind.ACTIVE, "Deal 7 damage.", "Closest active enemy.", "User must occupy a front-row slot.", "1 turn after use."],
	&"frontline_guard": ["Frontline Guard", CharacterSkill.Kind.PASSIVE, "Reduce the next damage taken by an adjacent ally by 3.", "Adjacent active allies.", "User must occupy a front-row slot.", "None"],
	&"quick_step": ["Quick Step", CharacterSkill.Kind.ACTIVE, "Gain 2 Speed until the end of the next turn.", "Self.", "None", "2 turns after use."],
	&"quick_strike": ["Quick Strike", CharacterSkill.Kind.ACTIVE, "Deal 5 damage.", "Closest active enemy.", "None", "None"],
	&"rally": ["Rally", CharacterSkill.Kind.ACTIVE, "Grant all active allies 2 Speed until the end of the round.", "All active allies, including the user.", "None", "2 turns after use."],
	&"evasion": ["Evasion", CharacterSkill.Kind.PASSIVE, "Prevent the first damage instance received each round.", "Self.", "None", "None"],
	&"momentum": ["Momentum", CharacterSkill.Kind.PASSIVE, "Gain 1 Speed after taking an action, lasting until battle ends.", "Self.", "User must remain active.", "None"],
	&"savage_blow": ["Savage Blow", CharacterSkill.Kind.ACTIVE, "Deal 12 damage.", "Closest active enemy.", "User must be above 50% HP.", "2 turns after use."],
	&"blood_scent": ["Blood Scent", CharacterSkill.Kind.PASSIVE, "Deal 3 additional damage to injured enemies.", "Enemies below 50% HP.", "Target must be below 50% HP.", "None"],
	&"brace": ["Brace", CharacterSkill.Kind.PASSIVE, "Reduce the first damage received each round by 2.", "Self.", "None", "None"],
	&"shadow_lunge": ["Shadow Lunge", CharacterSkill.Kind.ACTIVE, "Deal 10 damage.", "Farthest active enemy.", "User must occupy a back-row slot.", "Unavailable for the first turn of battle; none after use."],
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_structured_preview_contract()
	_test_blank_preview_rejection()
	_test_preview_duplication()
	await _test_exact_fixture_previews()
	await _test_preview_scene_and_content()
	await _test_preview_lifecycle_and_non_actionability()
	await _test_target_viewport_layout()
	if _failures.is_empty():
		print("AC2.7 tests passed")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_structured_preview_contract() -> void:
	var skill := CharacterSkill.create(
		&"shield_bash",
		"Shield Bash",
		CharacterSkill.Kind.ACTIVE,
		"Deal 7 damage.",
		"Closest active enemy.",
		"User must occupy a front-row slot.",
		"1 turn after use."
	)
	_expect(is_instance_valid(skill), "complete structured preview should be valid")
	if not is_instance_valid(skill):
		return
	_expect(skill.effect_text == "Deal 7 damage.", "effect text should be exact")
	_expect(skill.targeting_text == "Closest active enemy.", "targeting text should be exact")
	_expect(
		skill.requirements_text == "User must occupy a front-row slot.",
		"requirements text should be exact"
	)
	_expect(skill.cooldown_text == "1 turn after use.", "cooldown text should be exact")


func _test_blank_preview_rejection() -> void:
	var valid := ["Effect", "Target", "Requirement", "None"]
	for blank_index: int in 4:
		var fields := valid.duplicate()
		fields[blank_index] = " \t "
		var skill := CharacterSkill.create(
			&"invalid_preview",
			"Invalid Preview",
			CharacterSkill.Kind.ACTIVE,
			fields[0],
			fields[1],
			fields[2],
			fields[3]
		)
		_expect(skill == null, "blank preview field %d should be rejected" % blank_index)
	var explicit_none := CharacterSkill.create(
		&"explicit_none",
		"Explicit None",
		CharacterSkill.Kind.PASSIVE,
		"Prevent one hit.",
		"Self.",
		"None",
		"None"
	)
	_expect(is_instance_valid(explicit_none), "literal None should be valid authored content")


func _test_preview_duplication() -> void:
	var source := CharacterSkill.create(
		&"brace",
		"Brace",
		CharacterSkill.Kind.PASSIVE,
		"Reduce the first damage received each round by 2.",
		"Self.",
		"None",
		"None"
	)
	var copy := source.duplicate_skill()
	_expect(copy != source, "duplicate should be a distinct object")
	_expect(copy.effect_text == source.effect_text, "duplicate should preserve effect")
	_expect(copy.targeting_text == source.targeting_text, "duplicate should preserve targeting")
	_expect(copy.requirements_text == source.requirements_text, "duplicate should preserve requirements")
	_expect(copy.cooldown_text == source.cooldown_text, "duplicate should preserve cooldown")


func _test_exact_fixture_previews() -> void:
	var arena := await _instantiate_arena()
	_expect(is_instance_valid(arena), "battle arena should instantiate")
	if not is_instance_valid(arena):
		return
	var seen_ids: Array[StringName] = []
	var player_active := false
	var player_passive := false
	var enemy_active := false
	var enemy_passive := false
	for unit_id: StringName in [
		&"player_0", &"player_1", &"player_2", &"player_3", &"player_4", &"player_5",
		&"enemy_0", &"enemy_1", &"enemy_2", &"enemy_3", &"enemy_4", &"enemy_5",
	]:
		var unit := arena.get_unit_by_id(unit_id)
		_expect(is_instance_valid(unit), "fixture unit %s should exist" % unit_id)
		if not is_instance_valid(unit):
			continue
		for skill: CharacterSkill in unit.skills:
			seen_ids.append(skill.skill_id)
			_expect(EXPECTED_PREVIEWS.has(skill.skill_id), "unexpected fixture skill %s" % skill.skill_id)
			if not EXPECTED_PREVIEWS.has(skill.skill_id):
				continue
			var expected: Array = EXPECTED_PREVIEWS[skill.skill_id]
			_expect(_skill_preview_signature(skill) == expected, "preview mismatch for %s" % skill.skill_id)
			if unit.side == BattleUnitState.Side.PLAYER:
				player_active = player_active or skill.kind == CharacterSkill.Kind.ACTIVE
				player_passive = player_passive or skill.kind == CharacterSkill.Kind.PASSIVE
			else:
				enemy_active = enemy_active or skill.kind == CharacterSkill.Kind.ACTIVE
				enemy_passive = enemy_passive or skill.kind == CharacterSkill.Kind.PASSIVE
	_expect(seen_ids.size() == 11, "fixtures should expose exactly eleven skills")
	for expected_id: StringName in EXPECTED_PREVIEWS:
		_expect(seen_ids.has(expected_id), "fixture should contain %s" % expected_id)
	_expect(player_active and player_passive, "player fixtures should include active and passive skills")
	_expect(enemy_active and enemy_passive, "enemy fixtures should include active and passive skills")
	arena.queue_free()
	await process_frame


func _test_preview_scene_and_content() -> void:
	var arena := await _instantiate_arena()
	_expect(is_instance_valid(arena), "battle arena should instantiate for preview UI")
	if not is_instance_valid(arena):
		return
	for node_name: String in [
		"SkillSelectionRegion",
		"SkillPreviewPanel",
		"SkillPreviewPromptLabel",
		"SkillPreviewNameLabel",
		"SkillPreviewKindLabel",
		"SkillPreviewEffectLabel",
		"SkillPreviewTargetingLabel",
		"SkillPreviewRequirementsLabel",
		"SkillPreviewCooldownLabel",
	]:
		var node := arena.get_node_or_null("%%%s" % node_name)
		_expect(is_instance_valid(node), "scene-owned preview node %s should exist" % node_name)
	var prompt := arena.get_node_or_null("%SkillPreviewPromptLabel") as Label
	arena.inspect_unit(&"player_0")
	_expect(is_instance_valid(prompt) and prompt.visible, "inspected character should show preview prompt")
	if is_instance_valid(prompt):
		_expect(prompt.text == "Select a skill to inspect its description.", "preview prompt should be exact")
	arena.select_skill(&"shield_bash")
	_expect(_preview_text(arena) == [
		"Shield Bash",
		"Active",
		"Effect: Deal 7 damage.",
		"Targeting: Closest active enemy.",
		"Requirements: User must occupy a front-row slot.",
		"Cooldown: 1 turn after use.",
	], "active preview should render exact content")
	arena.select_skill(&"frontline_guard")
	_expect(_preview_text(arena) == [
		"Frontline Guard",
		"Passive",
		"Effect: Reduce the next damage taken by an adjacent ally by 3.",
		"Targeting: Adjacent active allies.",
		"Requirements: User must occupy a front-row slot.",
		"Cooldown: None",
	], "passive preview should render exact content including None")
	arena.queue_free()
	await process_frame


func _test_preview_lifecycle_and_non_actionability() -> void:
	var arena := await _instantiate_arena()
	_expect(is_instance_valid(arena), "battle arena should instantiate for lifecycle")
	if not is_instance_valid(arena):
		return
	arena.inspect_unit(&"player_0")
	var turn_before := arena.get_current_unit().unit_id
	var round_before := arena.round_number
	var log_count_before := arena.get_battle_log_entries().size()
	var hp_before := _snapshot_hp(arena)
	arena.select_skill(&"shield_bash")
	_expect(arena.get_current_unit().unit_id == turn_before, "inspection should not change turn")
	_expect(arena.round_number == round_before, "inspection should not change round")
	_expect(arena.get_battle_log_entries().size() == log_count_before, "inspection should not add log entries")
	_expect(_snapshot_hp(arena) == hp_before, "inspection should not change HP")
	arena.advance_turn()
	_expect(arena.get_selected_skill_id() == &"shield_bash", "turn advance should preserve preview")
	arena.inspect_unit(&"player_4")
	_expect(arena.get_selected_skill_id().is_empty(), "character change should clear selected skill")
	_expect((arena.get_node("%SkillPreviewPromptLabel") as Label).visible, "character change should restore prompt")
	arena.select_skill(&"rally")
	var empty_event := InputEventMouseButton.new()
	empty_event.button_index = MOUSE_BUTTON_LEFT
	empty_event.pressed = true
	var empty_slot := arena.get_player_slots()[0]
	empty_slot.set_meta("unit_id", &"")
	arena.call("_on_slot_gui_input", empty_event, empty_slot)
	_expect(arena.get_selected_skill_id() == &"rally", "empty slot should preserve preview")
	var selected_unit := arena.get_unit_by_id(&"player_4")
	selected_unit.current_hp = 0
	arena.call("_refresh_turn_ui")
	_expect(arena.get_selected_skill_id() == &"rally", "retained defeat should preserve preview")
	_expect((arena.get_node("%SkillInspectorStatusLabel") as Label).text == "Defeated", "retained defeat should show Defeated")
	arena.inspect_unit(&"missing")
	_expect(arena.get_inspected_unit_id().is_empty(), "invalid unit should clear inspection")
	_expect(arena.get_selected_skill_id().is_empty(), "invalid unit should clear selected skill")
	arena.inspect_unit(&"enemy_0")
	arena.select_skill(&"blood_scent")
	arena.configure_units(_single_unit_roster())
	_expect(arena.get_inspected_unit_id().is_empty(), "reconfiguration should clear inspection")
	_expect(arena.get_selected_skill_id().is_empty(), "reconfiguration should clear preview")
	arena.queue_free()
	await process_frame
	var fresh := await _instantiate_arena()
	_expect(fresh.get_inspected_unit_id().is_empty(), "new battle should start neutral")
	_expect(fresh.get_selected_skill_id().is_empty(), "new battle should have no preview selection")
	fresh.queue_free()
	await process_frame


func _test_target_viewport_layout() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	var arena := await _instantiate_arena()
	arena.inspect_unit(&"player_4")
	arena.select_skill(&"quick_strike")
	await process_frame
	await process_frame
	var inspector := arena.get_node("%SkillInspectorPanel") as Control
	var preview := arena.get_node("%SkillPreviewPanel") as Control
	var inspector_rect := inspector.get_global_rect()
	var preview_rect := preview.get_global_rect()
	var preview_ratio := preview_rect.size.x / inspector_rect.size.x
	_expect(preview_ratio >= 0.25 and preview_ratio <= 0.33, "preview ratio must be 0.25-0.33, got %.3f" % preview_ratio)
	_expect(inspector_rect.position.x >= 0.0 and inspector_rect.end.x <= 1152.0, "inspector must fit horizontally")
	_expect(inspector_rect.position.y >= 0.0 and inspector_rect.end.y <= 648.0, "inspector must fit vertically")
	var skills := arena.get_node("%SkillInspectorSkills") as HBoxContainer
	_expect(skills.get_child_count() == 4, "four-skill fixture should show four buttons")
	for child: Node in skills.get_children():
		var button := child as Control
		_expect(button.visible and inspector_rect.encloses(button.get_global_rect()), "%s must stay visible inside inspector" % button.name)
	for node_name: String in [
		"SkillPreviewNameLabel",
		"SkillPreviewKindLabel",
		"SkillPreviewEffectLabel",
		"SkillPreviewTargetingLabel",
		"SkillPreviewRequirementsLabel",
		"SkillPreviewCooldownLabel",
	]:
		var label := arena.get_node("%%%s" % node_name) as Label
		_expect(label.visible, "%s must be visible" % node_name)
		_expect(inspector_rect.encloses(label.get_global_rect()), "%s must stay inside inspector" % node_name)
		_expect(label.size.x > 0.0 and label.size.y > 0.0, "%s must have rendered size" % node_name)
		_expect(label.get_minimum_size().y <= label.size.y + 0.5, "%s text must not be clipped" % node_name)
	var ancestor: Node = arena.get_node("%SkillInspectorBody").get_parent()
	var has_scroll_ancestor := false
	while is_instance_valid(ancestor) and ancestor != inspector:
		has_scroll_ancestor = has_scroll_ancestor or ancestor is ScrollContainer
		ancestor = ancestor.get_parent()
	_expect(not has_scroll_ancestor, "inspector must not use scrolling as a layout workaround")
	arena.queue_free()
	await process_frame


func _snapshot_hp(arena: BattleArena) -> Dictionary:
	var result := {}
	for unit_id: StringName in [
		&"player_0", &"player_1", &"player_2", &"player_3", &"player_4", &"player_5",
		&"enemy_0", &"enemy_1", &"enemy_2", &"enemy_3", &"enemy_4", &"enemy_5",
	]:
		var unit := arena.get_unit_by_id(unit_id)
		if is_instance_valid(unit):
			result[unit_id] = unit.current_hp
	return result


func _single_unit_roster() -> Array[BattleUnitState]:
	return [BattleUnitState.new(&"fresh", "Fresh", BattleUnitState.Side.PLAYER, 0, 9)]


func _preview_text(arena: BattleArena) -> Array[String]:
	var result: Array[String] = []
	for node_name: String in [
		"SkillPreviewNameLabel",
		"SkillPreviewKindLabel",
		"SkillPreviewEffectLabel",
		"SkillPreviewTargetingLabel",
		"SkillPreviewRequirementsLabel",
		"SkillPreviewCooldownLabel",
	]:
		var label := arena.get_node_or_null("%%%s" % node_name) as Label
		result.append(label.text if is_instance_valid(label) and label.visible else "")
	return result


func _skill_preview_signature(skill: CharacterSkill) -> Array:
	return [
		skill.display_name,
		skill.kind,
		skill.effect_text,
		skill.targeting_text,
		skill.requirements_text,
		skill.cooldown_text,
	]


func _instantiate_arena() -> BattleArena:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as BattleArena if packed != null else null
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
