class_name CaptureAc7_5BattleVisualStates
extends SceneTree
const EVIDENCE: String = "res://Docs/Specs/AC7/Evidence/AC7.5/"
var _failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var arena := (load("res://Scenes/battle_arena.tscn") as PackedScene).instantiate() as BattleArena
	root.add_child(arena)
	await _settle()
	var bar := arena.get_node("%BattleActionBar") as Control
	for width: int in [1152, 1024]:
		root.content_scale_size = Vector2i(width, 648)
		root.size = Vector2i(width, 648)
		arena.configure_units(arena.call("_create_debug_units"))
		await _settle()
		var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
		var skill := rows.get_child(0) as Button
		var target := arena.get_enemy_slots()[0] as Control
		var before: Dictionary = arena.get_skill_presentation_snapshot()
		await _move(skill.get_global_rect().get_center())
		_expect(arena.get_skill_presentation_snapshot() == before, "pointer observation preserves transaction")
		_expect(target.get_meta("visual_target_border") == &"preview", "pointer previews legal targets")
		await _capture("hover-%d.png" % width)
		await _click(skill)
		target.grab_focus()
		await _key(KEY_ENTER)
		_expect(target.get_meta("visual_selected"), "keyboard selects target")
		var selected: Dictionary = arena.get_skill_presentation_snapshot()
		await _move((rows.get_child(1) as Control).get_global_rect().get_center())
		_expect(arena.get_skill_presentation_snapshot() == selected, "other hover preserves selection")
		await _capture("selected-%d.png" % width)
		arena.call("_on_turn_order_preview_changed", target.get_meta("unit_id"))
		await _capture("ribbon-selected-%d.png" % width)
		arena.call("_on_turn_order_preview_changed", &"")
		await _click(bar.get_node("%CancelButton"))
		await _click(bar.get_node("%DefaultAttackButton"))
		await _click(target)
		_expect(target.get_meta("visual_target_glyph") == &"attack" and target.get_meta("visual_selected"), "pointer selects Attack target")
		await _capture("attack-%d.png" % width)
		await _click(bar.get_node("%DefaultSwapButton"))
		var ally := arena.get_player_slots()[1] as Control
		ally.grab_focus()
		await _key(KEY_SPACE)
		_expect(ally.get_meta("visual_target_glyph") == &"swap" and ally.get_meta("visual_selected"), "Space selects Swap target")
		await _capture("swap-%d.png" % width)
		await _click(bar.get_node("%CancelButton"))
		await _move(Vector2(4, 4))
		if is_instance_valid(root.gui_get_focus_owner()):
			root.gui_get_focus_owner().release_focus()
		await _settle()
		skill.grab_focus()
		await _settle()
		_expect(target.get_meta("visual_target_border") == &"preview", "focus previews same legal target")
		await _key(KEY_TAB)
		await _key(KEY_TAB, true)
		_expect(skill.has_focus(), "Tab and Shift Tab round trip")
		arena.configure_units(arena.call("_create_debug_units"))
		await _settle()
		_expect(target.get_meta("visual_target_border") == &"", "same identity reset clears preview")
		await _capture("reset-%d.png" % width)
		var definition := RunCharacterCatalog.create_by_class_id(&"wirefang_skirmisher")
		var actor := BattleUnitState.new(&"actor", "Wirefang", 0, 0, 10, 20, definition.get_skills())
		var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 1)
		arena.configure_units([actor, enemy])
		await _settle()
		var self_skill := (bar.get_node("%SkillInspectorSkills") as HBoxContainer).get_child(2) as Button
		await _click(self_skill)
		_expect(arena.get_player_slots()[0].get_meta("visual_target_border") == &"valid", "zero target displays affected actor")
		await _move(Vector2(4, 4))
		await _capture("self-%d.png" % width)
		await _click(bar.get_node("%CancelButton"))
		arena.get_player_slots()[0].grab_focus()
		await _settle()
		await _capture("focus-%d.png" % width)
		arena.configure_units([actor])
		await _settle()
		var attack := bar.get_node("%DefaultAttackButton") as Button
		attack.grab_focus()
		await _settle()
		_expect(attack.has_focus() and (attack.get_node("NoTargetBadge") as Label).visible, "no-target default explains on focus")
		var revision: int = arena.get_battle_revision()
		await _key(KEY_ENTER)
		_expect(arena.get_battle_revision() == revision and int(arena.get("_default_action_mode")) == 0, "unavailable Enter does not activate")
		await _capture("no-target-%d.png" % width)
		arena.configure_units([actor, enemy])
		actor.set_skill_cooldown(&"quick_mark", 2)
		enemy.current_hp = 0
		arena.notify_authoritative_battle_change()
		await _settle()
		var locked := (bar.get_node("%SkillInspectorSkills") as HBoxContainer).get_child(0) as Button
		await _move(locked.get_global_rect().get_center())
		await _capture("unavailable-%d.png" % width)
		arena.configure_units(arena.call("_create_debug_units"))
		await _settle()
		var rally := (bar.get_node("%SkillInspectorSkills") as HBoxContainer).get_child(1) as Button
		await _move(rally.get_global_rect().get_center())
		_expect(arena.get_player_slots()[4].get_meta("visual_target_border") == &"preview", "ally preview includes actor")
		await _capture("allies-%d.png" % width)
		var multi_definition := RunCharacterCatalog.create_by_class_id(&"snarewright")
		var controller := BattleUnitState.new(&"controller", "Snarewright", 0, 0, 10, 20, multi_definition.get_skills())
		var first_enemy := BattleUnitState.new(&"first", "First", 1, 0, 2)
		var second_enemy := BattleUnitState.new(&"second", "Second", 1, 1, 1)
		arena.configure_units([controller, first_enemy, second_enemy])
		await _settle()
		var multi := (bar.get_node("%SkillInspectorSkills") as HBoxContainer).get_child(2) as Button
		await _click(multi)
		await _click(arena.get_enemy_slots()[0])
		arena.get_enemy_slots()[1].grab_focus()
		await _key(KEY_SPACE)
		_expect(arena.get_enemy_slots()[0].get_meta("visual_selected") and arena.get_enemy_slots()[1].get_meta("visual_selected"), "multi target keeps both selected")
		await _move(Vector2(4, 4))
		await _capture("multi-%d.png" % width)
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	print("AC7.5 rendered input/layout QA: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)
func _capture(filename: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(EVIDENCE + filename) == OK, "saved " + filename)
func _settle() -> void:
	for frame: int in range(4):
		await process_frame


func _move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion)
	await _settle()


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	await _move(point)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await _settle()


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.shift_pressed = shift
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await _settle()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
