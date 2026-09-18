class_name CaptureAc7_3UnifiedActionBar
extends SceneTree

const EVIDENCE: String = "res://Docs/Specs/AC7/Evidence/AC7.3/"
var _failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Vector2i(1152, 648)
	root.size = Vector2i(1152, 648)
	var arena := (load("res://Scenes/battle_arena.tscn") as PackedScene).instantiate() as BattleArena
	root.add_child(arena)
	await _settle()
	for step: int in 20:
		if arena.get_inspected_unit_id() == &"player_4":
			break
		arena.advance_turn()
	var bar := arena.get_node("%BattleActionBar") as Control
	var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
	await _capture(arena, "bar-four-skills.png")
	await _move(Vector2(2, 2))
	(rows.get_child(0) as Button).grab_focus()
	await _settle()
	_expect((bar.get_node("%SkillTooltipPanel") as Control).visible, "keyboard exposes skill details")
	await _capture(arena, "bar-keyboard-details.png")
	await _key(KEY_ENTER)
	_expect(arena.get_selected_skill_id() == &"quick_strike", "Enter selects skill")
	await _click(arena.get_enemy_slots()[0])
	_expect(not (bar.get_node("%ConfirmButton") as Button).disabled, "real skill target enables Confirm")
	await _capture(arena, "bar-skill-target.png")
	await _click(bar.get_node("%DefaultAttackButton"))
	_expect(arena.get_selected_skill_id() == &"", "real Attack clears skill selection")
	await _click(arena.get_enemy_slots()[0])
	await _capture(arena, "bar-attack-target.png")
	await _click(bar.get_node("%CancelButton"))
	await _click(bar.get_node("%DefaultSwapButton"))
	# player_4 is in slot 4; slot 1 is its adjacent frontline ally.
	await _click(arena.get_player_slots()[1])
	_expect(not (bar.get_node("%ConfirmButton") as Button).disabled, "real Swap target enables Confirm")
	await _capture(arena, "bar-swap-target.png")
	await _click(bar.get_node("%CancelButton"))
	await _move(Vector2(2, 2))
	root.content_scale_size = Vector2i(1024, 648)
	root.size = Vector2i(1024, 648)
	await _settle()
	(rows.get_child(0) as Button).grab_focus()
	for index: int in 4:
		var button := rows.get_child(index) as Button
		_expect(button.has_focus(), "Tab reaches skill " + str(index))
		var scroll := rows.get_parent() as ScrollContainer
		_expect(scroll.get_global_rect().grow(1).encloses(button.get_global_rect()), "focused skill stays visible")
		await _key(KEY_TAB)
	_expect((bar.get_node("%DefaultAttackButton") as Button).has_focus(), "Tab reaches Attack")
	await _key(KEY_TAB)
	_expect((bar.get_node("%DefaultSwapButton") as Button).has_focus(), "Tab reaches Swap")
	await _key(KEY_TAB)
	_expect(not bar.is_ancestor_of(root.gui_get_focus_owner()), "Tab leaves bar")
	await _capture(arena, "bar-constrained-1024.png")
	var current_actor: BattleUnitState = arena.get_current_unit()
	current_actor.set_skill_cooldown(&"rally", 2)
	arena.notify_authoritative_battle_change()
	(rows.get_child(1) as Button).grab_focus()
	await _settle()
	_expect((bar.get_node("%SkillTooltipAvailabilityLabel") as Label).text.contains("2"), "keyboard exposes live cooldown reason")
	await _capture(arena, "bar-cooldown.png")
	root.content_scale_size = Vector2i(1152, 648)
	root.size = Vector2i(1152, 648)
	var actor := BattleUnitState.new(&"zero", "No skills", 0, 0, 10)
	var enemy := BattleUnitState.new(&"enemy", "Opponent", 1, 0, 5)
	arena.configure_units([actor, enemy])
	await _settle()
	_expect(not (bar.get_node("%DefaultAttackButton") as Button).disabled, "zero skills can Attack")
	_expect((bar.get_node("%DefaultSwapButton") as Button).disabled, "no ally disables Swap")
	await _capture(arena, "bar-zero-skills.png")
	await _click(bar.get_node("%DefaultAttackButton"))
	await _click(arena.get_enemy_slots()[0])
	var hp: int = enemy.current_hp
	await _click(bar.get_node("%ConfirmButton"))
	_expect(enemy.current_hp < hp and arena.get_action_records().size() == 1, "real confirmation commits once")
	await _capture(arena, "bar-enemy-turn.png")
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	print("AC7.3 rendered input/layout QA: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)

func _capture(arena: BattleArena, filename: String) -> void:
	await _settle()
	var bounds := Rect2(Vector2.ZERO, Vector2(root.content_scale_size))
	var bar := arena.get_node("%BattleActionBar") as Control
	_expect(bounds.encloses(arena.get_node("Margin/VBox").get_global_rect()), filename + " entire HUD fits")
	_expect(bounds.encloses(bar.get_global_rect()), filename + " bar fits")
	for name: String in ["DefaultAttackButton", "DefaultSwapButton", "ConfirmButton", "CancelButton"]:
		var control := bar.get_node("%" + name) as Control
		if control.is_visible_in_tree():
			_expect(bounds.encloses(control.get_global_rect()), filename + " " + name + " fits")
	var tooltip := bar.get_node("%SkillTooltipPanel") as Control
	if tooltip.visible:
		_expect(bounds.encloses(tooltip.get_global_rect()), filename + " tooltip fits")
	print(filename, " bar ", bar.get_global_rect())
	if DisplayServer.get_name() != "headless":
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
