class_name Ac7_3UnifiedActionBarTests
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var arena := (load("res://Scenes/battle_arena.tscn") as PackedScene).instantiate() as Control
	root.add_child(arena)
	await process_frame
	var bar := arena.get_node_or_null("%BattleActionBar") as Control
	_assert(is_instance_valid(bar), "one authored unified action bar")
	if is_instance_valid(bar):
		await _test_actions(arena, bar)
		await _test_lifecycle(arena, bar)
		await _test_rosters_and_focus(arena, bar)
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	if _failures.is_empty():
		print("AC7.3 unified action bar: PASS")
	quit(0 if _failures.is_empty() else 1)

func _test_actions(arena: Control, bar: Control) -> void:
	var attack := bar.get_node("%DefaultAttackButton") as Button
	var swap := bar.get_node("%DefaultSwapButton") as Button
	var confirm := bar.get_node("%ConfirmButton") as Button
	var cancel := bar.get_node("%CancelButton") as Button
	var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
	_assert(attack.accessibility_name == "Default Attack" and swap.accessibility_name == "Default Swap", "accessible names")
	_assert(attack.custom_minimum_size == Vector2(44, 44) and swap.custom_minimum_size == Vector2(44, 44), "compact hit targets")
	_assert(not attack.tooltip_text.is_empty() and not swap.tooltip_text.is_empty(), "default tooltips")
	for step: int in 20:
		if arena.call("get_inspected_unit_id") == &"player_4":
			break
		arena.call("advance_turn")
	_assert(rows.get_child_count() == 4, "full four-skill roster")
	var skill := rows.get_child(0) as Button
	var passive := rows.get_child(2) as Button
	var revision: int = arena.call("get_battle_revision")
	var actor: BattleUnitState = arena.call("get_current_unit")
	var first_id: StringName = skill.get_meta("skill_id")
	skill.pressed.emit()
	_assert(arena.call("get_selected_skill_id") == first_id, "skill selected")
	attack.pressed.emit()
	_assert(arena.call("get_selected_skill_id") == &"" and attack.button_pressed, "Attack replaces skill selection")
	_assert(arena.call("get_skill_transaction_state") == BattleSkillTransaction.State.IDLE, "Attack clears skill transaction")
	var before: Dictionary = arena.call("get_skill_presentation_snapshot")
	skill.mouse_entered.emit()
	_assert(arena.call("get_skill_presentation_snapshot") == before, "skill hover preserves default action")
	skill.mouse_exited.emit()
	swap.pressed.emit()
	_assert(swap.button_pressed and not attack.button_pressed, "Swap replaces Attack")
	skill.pressed.emit()
	_assert(not swap.button_pressed and not attack.button_pressed, "skill replaces defaults")
	_assert(int(arena.get("_default_action_mode")) == 0, "only skill targeting remains")
	passive.pressed.emit()
	_assert(not confirm.visible or confirm.disabled, "passive cannot confirm")
	_assert(arena.call("get_skill_transaction_state") == BattleSkillTransaction.State.IDLE, "passive clears pending targeting")
	attack.pressed.emit()
	cancel.pressed.emit()
	_assert(not attack.button_pressed and not swap.button_pressed and arena.call("get_selected_skill_id") == &"", "cancel clears selection")
	_assert(arena.call("get_battle_revision") == revision and arena.call("get_current_unit") == actor, "selection and cancel do not commit")
	skill.grab_focus()
	await process_frame
	arena.call("_refresh_turn_ui")
	await process_frame
	_assert(rows.get_child(0) == skill and skill.has_focus(), "benign refresh retains focused tile")
	arena.call("advance_turn")
	_assert(not attack.button_pressed and not swap.button_pressed, "turn clears selection")

func _assert(condition: bool, label: String) -> void:
	if not condition:
		_failures.append(label)

func _test_lifecycle(arena: Control, bar: Control) -> void:
	var skill: CharacterSkill = arena.call("_create_skill", &"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE, "Deal 7 damage.", "One enemy.", "Front row.", "1 action.")
	var actor := BattleUnitState.new(&"actor", "Actor", 0, 0, 10, 20, [skill])
	var ally := BattleUnitState.new(&"ally", "Ally", 0, 3, 8)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 5, 50)
	var units: Array[BattleUnitState] = [actor, ally, enemy]
	arena.call("configure_units", units)
	var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
	var button := rows.get_child(0) as Button
	var tooltip := bar.get_node("%SkillTooltipPanel") as Control
	button.pressed.emit()
	arena.call("select_skill_target", &"enemy")
	var before: Dictionary = arena.call("get_skill_presentation_snapshot")
	button.mouse_entered.emit()
	_assert(arena.call("get_skill_presentation_snapshot") == before, "hover preserves locked skill target")
	button.mouse_exited.emit()
	(bar.get_node("%ConfirmButton") as Button).pressed.emit()
	_assert(enemy.current_hp == 43 and (arena.call("get_action_records") as Array).size() == 1, "shared Confirm commits skill exactly once")
	# Reset the same actor IDs: no old UI or focus may survive.
	arena.call("configure_units", units)
	button = rows.get_child(0) as Button
	button.mouse_entered.emit()
	actor.set_skill_cooldown(&"shield_bash", 2)
	arena.call("notify_authoritative_battle_change")
	_assert((bar.get_node("%DetailReadout") as Label).text.contains("2"), "visible detail reason refreshes with cooldown")
	_assert(button.accessibility_name.contains("2"), "cooldown reason is exposed")
	button.mouse_entered.emit()
	actor.current_hp = 0
	arena.call("notify_authoritative_battle_change")
	_assert(not tooltip.visible, "actor defeat clears tooltip without roster change")
	actor.current_hp = 20
	actor.set_skill_cooldown(&"shield_bash", 0)
	arena.call("configure_units", units)
	button = rows.get_child(0) as Button
	button.mouse_entered.emit()
	arena.call("configure", Vector2i.ZERO, WorldEncounterType.COMBAT)
	var identity: RefCounted = arena.call("get_setup_identity")
	var record: RefCounted = load("res://Scripts/Battle/battle_preparation_record.gd").offered(&"prep", Vector2i.ZERO, WorldEncounterType.COMBAT, String(identity.get("canonical_key")))
	_assert(arena.call("configure_preparation", record), "preparation fixture accepted")
	_assert(not tooltip.visible and (bar.get_node("%DefaultAttackButton") as Button).disabled, "preparation clears tooltip and disables defaults immediately")
	button.pressed.emit()
	_assert(arena.call("get_selected_skill_id") == &"", "preparation blocks skill activation")
	arena.call("configure_units", units)
	var attack := bar.get_node("%DefaultAttackButton") as Button
	attack.pressed.emit()
	arena.call("_select_default_action_target", &"enemy", 0)
	var hp: int = enemy.current_hp
	arena.call("notify_authoritative_battle_change")
	(bar.get_node("%ConfirmButton") as Button).pressed.emit()
	_assert(enemy.current_hp == hp and (arena.call("get_action_records") as Array).is_empty(), "stale default confirmation commits nothing")
	_assert((bar.get_node("%ActionMessageLabel") as Label).text.contains("Battle state changed"), "stale default reason preserved")
	arena.call("remove_battle_unit", &"actor")
	_assert(not tooltip.visible, "actor removal clears tooltip")
	arena.call("configure_units", units)
	actor.current_hp = 20
	enemy.current_hp = 1
	attack.pressed.emit()
	arena.call("_select_default_action_target", &"enemy", 0)
	(bar.get_node("%ConfirmButton") as Button).pressed.emit()
	_assert(arena.call("is_battle_complete") and not tooltip.visible and attack.disabled, "completion clears details and disables controls")

func _test_rosters_and_focus(arena: Control, bar: Control) -> void:
	for count: int in 5:
		var skills: Array[CharacterSkill] = []
		for index: int in count:
			skills.append(CharacterSkill.new(StringName("skill_%d" % index), "Skill %d" % index, CharacterSkill.Kind.PASSIVE, "Passive effect.", "Self.", "None", "None"))
		var units: Array[BattleUnitState] = [
			BattleUnitState.new(&"actor", "Actor", 0, 0, 10, 20, skills),
			BattleUnitState.new(&"enemy", "Enemy", 1, 0, 5)
		]
		arena.call("configure_units", units)
		var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
		_assert(rows.get_child_count() == count, "render roster size " + str(count))
		_assert(not (bar.get_node("%DefaultAttackButton") as Button).disabled, "defaults survive roster size " + str(count))
	var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
	var first := rows.get_child(0) as Button
	var second := rows.get_child(1) as Button
	var tooltip_name := bar.get_node("%SkillTooltipNameLabel") as Label
	first.grab_focus()
	await process_frame
	second.mouse_entered.emit()
	_assert(tooltip_name.text == "Skill 1", "pointer takes precedence over keyboard details")
	first.mouse_exited.emit()
	_assert(tooltip_name.text == "Skill 1", "late exit preserves newer detail source")
	second.mouse_exited.emit()
	_assert(tooltip_name.text == "Skill 0", "keyboard details resume on pointer exit")
	var revision: int = arena.call("get_battle_revision")
	for iteration: int in 3:
		arena.call("_refresh_action_bar")
	_assert(arena.call("get_battle_revision") == revision and (arena.call("get_action_records") as Array).is_empty(), "repeated rendering is read-only")
