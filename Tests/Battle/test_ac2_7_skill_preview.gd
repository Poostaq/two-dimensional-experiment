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
	await _test_tooltip_scene_and_hover_content()
	await _test_tooltip_lifecycle_and_non_actionability()
	await _test_tooltip_placement_and_event_guards()
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


func _test_tooltip_scene_and_hover_content() -> void:
	var arena := await _instantiate_arena()
	_expect(is_instance_valid(arena), "battle arena should instantiate for tooltip UI")
	if not is_instance_valid(arena):
		return
	_expect(arena.get_node_or_null("%SkillPreviewPanel") == null, "fixed skill preview panel should be removed")
	for node_name: String in [
		"SkillTooltipPanel",
		"SkillTooltipNameLabel",
		"SkillTooltipKindLabel",
		"SkillTooltipEffectLabel",
		"SkillTooltipTargetingLabel",
		"SkillTooltipRequirementsLabel",
		"SkillTooltipCooldownLabel",
	]:
		var node := arena.get_node_or_null("%%%s" % node_name)
		_expect(is_instance_valid(node), "scene-owned tooltip node %s should exist" % node_name)
	var tooltip := arena.get_node_or_null("%SkillTooltipPanel") as PanelContainer
	if not is_instance_valid(tooltip):
		arena.queue_free()
		await process_frame
		return
	_expect(not tooltip.visible, "tooltip should start hidden")
	arena.inspect_unit(&"player_0")
	var active_button := _skill_button(arena, &"shield_bash")
	_expect(is_instance_valid(active_button), "active skill button should exist")
	if is_instance_valid(active_button):
		_emit_skill_hover(active_button, true)
		await process_frame
		_expect(tooltip.visible, "active tooltip should show on hover without clicking")
		_expect(_tooltip_text(arena) == [
			"Shield Bash",
			"Active",
			"Effect: Deal 7 damage.",
			"Targeting: Closest active enemy.",
			"Requirements: User must occupy a front-row slot.",
			"Cooldown: 1 turn after use.",
		], "active tooltip should render exact content")
		_emit_skill_hover(active_button, false)
		_expect(not tooltip.visible, "active tooltip should hide immediately on exit")
		_expect(_tooltip_text(arena) == ["", "", "", "", "", ""], "exit should clear tooltip text")
	var passive_button := _skill_button(arena, &"frontline_guard")
	_expect(is_instance_valid(passive_button), "passive skill button should exist")
	if is_instance_valid(passive_button):
		_emit_skill_hover(passive_button, true)
		await process_frame
		_expect(_tooltip_text(arena) == [
			"Frontline Guard",
			"Passive",
			"Effect: Reduce the next damage taken by an adjacent ally by 3.",
			"Targeting: Adjacent active allies.",
			"Requirements: User must occupy a front-row slot.",
			"Cooldown: None",
		], "passive tooltip should render exact content including None")
		_emit_skill_hover(passive_button, false)
	arena.queue_free()
	await process_frame


func _test_tooltip_lifecycle_and_non_actionability() -> void:
	var arena := await _instantiate_arena()
	_expect(is_instance_valid(arena), "battle arena should instantiate for tooltip lifecycle")
	if not is_instance_valid(arena):
		return
	var tooltip := arena.get_node_or_null("%SkillTooltipPanel") as PanelContainer
	var has_handlers := (
		arena.has_method("_on_skill_button_mouse_entered")
		and arena.has_method("_on_skill_button_mouse_exited")
	)
	_expect(is_instance_valid(tooltip), "tooltip panel should exist for lifecycle checks")
	_expect(has_handlers, "battle arena should expose guarded hover handlers")
	if not is_instance_valid(tooltip) or not has_handlers:
		arena.queue_free()
		await process_frame
		return
	arena.inspect_unit(&"player_0")
	var active_button := _skill_button(arena, &"shield_bash")
	var passive_button := _skill_button(arena, &"frontline_guard")
	_expect(is_instance_valid(active_button) and is_instance_valid(passive_button), "lifecycle skill buttons should exist")
	if not is_instance_valid(active_button) or not is_instance_valid(passive_button):
		arena.queue_free()
		await process_frame
		return
	var turn_before := arena.get_current_unit().unit_id
	var round_before := arena.round_number
	var log_count_before := arena.get_battle_log_entries().size()
	var hp_before := _snapshot_hp(arena)
	var inspected_before := arena.get_inspected_unit_id()
	var selected_before := arena.get_selected_skill_id()
	_emit_skill_hover(active_button, true)
	await process_frame
	_expect(arena.get_current_unit().unit_id == turn_before, "hover should not change turn")
	_expect(arena.round_number == round_before, "hover should not change round")
	_expect(arena.get_battle_log_entries().size() == log_count_before, "hover should not add log entries")
	_expect(_snapshot_hp(arena) == hp_before, "hover should not change HP")
	_expect(arena.get_inspected_unit_id() == inspected_before, "hover should not change inspected unit")
	_expect(arena.get_selected_skill_id() == selected_before, "hover should not select a skill")
	active_button.pressed.emit()
	_expect(arena.get_selected_skill_id() == &"shield_bash", "click selection should remain available")
	_emit_skill_hover(active_button, false)
	_expect(not tooltip.visible, "click should not pin tooltip after exit")
	_emit_skill_hover(active_button, true)
	_emit_skill_hover(passive_button, true)
	_emit_skill_hover(active_button, false)
	await process_frame
	_expect(tooltip.visible, "stale exit should not hide newer hovered tooltip")
	_expect(_tooltip_text(arena)[0] == "Frontline Guard", "newer hover should own tooltip content")
	_emit_skill_hover(passive_button, true)
	await process_frame
	_expect(tooltip.visible and _tooltip_text(arena)[0] == "Frontline Guard", "duplicate enter should be safe")
	arena.inspect_unit(&"player_4")
	_expect(not tooltip.visible, "character change should hide tooltip")
	var player_four_button := _skill_button(arena, &"quick_strike")
	_emit_skill_hover(player_four_button, true)
	await process_frame
	arena.configure_units(_single_unit_roster())
	_expect(not tooltip.visible, "reconfiguration should hide tooltip")
	arena.queue_free()
	await process_frame


func _test_tooltip_placement_and_event_guards() -> void:
	root.size = Vector2i(1152, 648)
	await process_frame
	var arena := await _instantiate_arena()
	_expect(is_instance_valid(arena), "battle arena should instantiate for tooltip placement")
	if not is_instance_valid(arena):
		return
	var tooltip := arena.get_node_or_null("%SkillTooltipPanel") as PanelContainer
	var has_handlers := (
		arena.has_method("_on_skill_button_mouse_entered")
		and arena.has_method("_position_skill_tooltip")
	)
	_expect(is_instance_valid(tooltip), "tooltip panel should exist for placement checks")
	_expect(has_handlers, "battle arena should expose tooltip placement handlers")
	if not is_instance_valid(tooltip) or not has_handlers:
		arena.queue_free()
		await process_frame
		return
	var unit := arena.get_unit_by_id(&"player_0")
	var skill: CharacterSkill = unit.skills[0] if is_instance_valid(unit) and not unit.skills.is_empty() else null
	_expect(is_instance_valid(skill), "placement fixture skill should exist")
	if not is_instance_valid(skill):
		arena.queue_free()
		await process_frame
		return
	var anchor := Button.new()
	anchor.custom_minimum_size = Vector2(88.0, 88.0)
	anchor.size = Vector2(88.0, 88.0)
	arena.add_child(anchor)
	anchor.position = Vector2(500.0, 400.0)
	arena.call("_on_skill_button_mouse_entered", skill, anchor)
	await process_frame
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(1152.0, 648.0))
	var button_rect := anchor.get_global_rect()
	var tooltip_rect := tooltip.get_global_rect()
	_expect(viewport_rect.encloses(tooltip_rect), "tooltip should stay inside target viewport")
	_expect(tooltip_rect.end.y <= button_rect.position.y - 8.0 + 0.5, "tooltip should prefer above")
	_expect(absf(tooltip_rect.get_center().x - button_rect.get_center().x) <= 0.5, "unclamped tooltip should center")
	anchor.position = Vector2(500.0, 4.0)
	arena.call("_on_skill_button_mouse_entered", skill, anchor)
	await process_frame
	button_rect = anchor.get_global_rect()
	tooltip_rect = tooltip.get_global_rect()
	_expect(tooltip_rect.position.y >= button_rect.end.y + 8.0 - 0.5, "tooltip should flip below")
	anchor.position = Vector2(0.0, 400.0)
	arena.call("_on_skill_button_mouse_entered", skill, anchor)
	await process_frame
	tooltip_rect = tooltip.get_global_rect()
	_expect(tooltip_rect.position.x >= 12.0, "left-edge tooltip should clamp to margin")
	anchor.position = Vector2(1064.0, 400.0)
	arena.call("_on_skill_button_mouse_entered", skill, anchor)
	await process_frame
	tooltip_rect = tooltip.get_global_rect()
	_expect(tooltip_rect.end.x <= 1140.0, "right-edge tooltip should clamp to margin")
	arena.call("_on_skill_button_mouse_entered", null, anchor)
	_expect(not tooltip.visible, "invalid skill should hide tooltip")
	anchor.queue_free()
	await process_frame
	var stale_generation := int(arena.get("_skill_tooltip_generation"))
	arena.call("_position_skill_tooltip", anchor, stale_generation)
	_expect(not tooltip.visible, "freed anchor should not restore tooltip")
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


func _emit_skill_hover(button: Button, entered: bool) -> void:
	if entered:
		button.mouse_entered.emit()
	else:
		button.mouse_exited.emit()


func _skill_button(arena: BattleArena, skill_id: StringName) -> Button:
	var skills := arena.get_node("%SkillInspectorSkills") as HBoxContainer
	for child: Node in skills.get_children():
		var button := child as Button
		if is_instance_valid(button) and button.get_meta("skill_id", &"") == skill_id:
			return button
	return null


func _tooltip_text(arena: BattleArena) -> Array[String]:
	var result: Array[String] = []
	for node_name: String in [
		"SkillTooltipNameLabel",
		"SkillTooltipKindLabel",
		"SkillTooltipEffectLabel",
		"SkillTooltipTargetingLabel",
		"SkillTooltipRequirementsLabel",
		"SkillTooltipCooldownLabel",
	]:
		var label := arena.get_node_or_null("%%%s" % node_name) as Label
		result.append(label.text if is_instance_valid(label) else "")
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
