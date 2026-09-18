class_name CaptureAc7_2TurnOrderRibbon
extends SceneTree

const EVIDENCE: String = "res://Docs/Specs/AC7/Evidence/AC7.2/"
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.content_scale_size = Vector2i(1152, 648)
	root.size = Vector2i(1152, 648)
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var ribbon: Control = arena.get_node("%TurnOrderRibbon")
	var dense: Array[BattleUnitState] = []
	var classes: Array[StringName] = RunCharacterCatalog.get_goblin_class_ids()
	for side: int in range(2):
		for index: int in range(6):
			var character: RunCharacter = RunCharacterCatalog.create_by_class_id(classes[index])
			var unit := BattleUnitState.new(StringName("%d_%d" % [side, index]), character.display_name,
				side, index, 10 - index, character.max_hp, character.get_skills())
			dense.append(unit)
	dense[1].display_name = "Wirefang Skirmisher of the Eastern Warren"
	arena.configure_units(dense)
	var source: RefCounted = load("res://Scripts/Battle/battle_keyword_source.gd").create(&"1_0", &"fixture", 2)
	for unit: BattleUnitState in dense:
		unit.add_armor(4)
		unit.apply_advantage(source, 1)
		unit.apply_snared(source, 1)
		unit.apply_bleed(source, 2)
		unit.add_speed_modifier(&"fixture", -1, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1)
	arena.notify_authoritative_battle_change()
	await _settle()
	await _capture(arena, "ribbon-dense-1152.png")
	var current: Control = ribbon.call("get_entry_control", &"0_0")
	await _move(current.get_global_rect().get_center())
	_assert_preview(arena, &"0_0")
	await _capture(arena, "ribbon-current-preview.png")
	var enemy_entry: Control = ribbon.call("get_entry_control", &"1_0")
	await _move(enemy_entry.get_global_rect().get_center())
	_assert_preview(arena, &"1_0")
	await _capture(arena, "ribbon-enemy-preview.png")
	# Move pointer away; keyboard traversal alone must control preview.
	await _move(Vector2(2, 2))
	current.grab_focus()
	var ids: Array = ribbon.call("get_entry_ids")
	for index: int in range(ids.size()):
		var entry: Control = ribbon.call("get_entry_control", ids[index])
		_expect(entry.has_focus(), "Tab follows queue: " + String(ids[index]))
		_assert_preview(arena, ids[index])
		if index > 0:
			var scroll: Control = ribbon.get_node("UpcomingScroll")
			_expect(scroll.get_global_rect().grow(1).encloses(entry.get_global_rect()), "focused entry scrolled into view")
		if index == ids.size() - 1:
			await _capture(arena, "ribbon-keyboard-scrolled.png")
		await _key(KEY_TAB)
	_expect(not ribbon.is_ancestor_of(root.gui_get_focus_owner()), "Tab exits ribbon")
	await _key(KEY_TAB, true)
	_expect((ribbon.call("get_entry_control", ids.back()) as Control).has_focus(), "Shift-Tab reenters last ribbon entry")
	var before_revision: int = arena.get_battle_revision()
	await _key(KEY_ENTER)
	_expect(arena.get_battle_revision() == before_revision, "Enter on ribbon does not act")
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await _capture(arena, "ribbon-dense-1280.png")
	root.content_scale_size = Vector2i(1152, 648)
	root.size = Vector2i(1152, 648)
	var actor := BattleUnitState.new(&"actor", "Vanguard", 0, 0, 10)
	var ally := BattleUnitState.new(&"ally", "Rear Guard", 0, 3, 8)
	var enemy := BattleUnitState.new(&"enemy", "Opponent", 1, 0, 5)
	arena.configure_units([actor, ally, enemy])
	await _settle()
	# Real target input must pass through the new mouse-ignoring overlay.
	await _click(arena.get_node("%BattleActionBar").get_node("%DefaultAttackButton"))
	await _click(arena.get_enemy_slots()[0])
	var selected: Dictionary = arena.get_skill_presentation_snapshot().duplicate(true)
	enemy_entry = ribbon.call("get_entry_control", &"enemy")
	await _move(enemy_entry.get_global_rect().get_center())
	_assert_preview(arena, &"enemy")
	_expect(not (arena.get_node("%BattleActionBar").get_node("%ConfirmButton") as Button).disabled, "ribbon preserves selected attack target")
	_expect(arena.get_skill_presentation_snapshot() == selected, "ribbon leaves transaction unchanged")
	await _capture(arena, "ribbon-target-overlap.png")
	await _click(arena.get_node("%BattleActionBar").get_node("%CancelButton"))
	_expect(enemy.current_hp == 20, "cancel unchanged")
	# Preview overlaps an active skill target indicator as well.
	var character: RunCharacter = RunCharacterCatalog.create_by_class_id(&"scrapshield_bruiser")
	var skilled := BattleUnitState.new(&"actor", "Bruiser", 0, 0, 10, 20, character.get_skills())
	arena.configure_units([skilled, ally, enemy])
	_expect(arena.begin_skill_action(&"actor", skilled.skills[0].skill_id), "skill targeting begins")
	_expect(arena.select_skill_target(&"enemy"), "skill target selected")
	await _settle()
	selected = arena.get_skill_presentation_snapshot().duplicate(true)
	enemy_entry = ribbon.call("get_entry_control", &"enemy")
	await _move(enemy_entry.get_global_rect().get_center())
	_assert_preview(arena, &"enemy")
	_expect(arena.get_skill_presentation_snapshot() == selected, "selected skill target survives ribbon")
	await _capture(arena, "ribbon-skill-target-overlap.png")
	arena.cancel_skill_action()
	arena.advance_turn()
	await _move(Vector2(2, 2))
	_assert_preview(arena, &"")
	await _capture(arena, "ribbon-after-turn.png")
	enemy.current_hp = 0
	arena.notify_authoritative_battle_change()
	await _capture(arena, "ribbon-after-defeat.png")
	arena.configure_units([actor, ally])
	_assert_preview(arena, &"")
	await _capture(arena, "ribbon-after-reset.png")
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	print("AC7.2 rendered input/layout QA: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)


func _capture(arena: BattleArena, filename: String) -> void:
	await _settle()
	var bounds := Rect2(Vector2.ZERO, Vector2(root.content_scale_size))
	var main: Control = arena.get_node("Margin/VBox")
	_expect(bounds.encloses(main.get_global_rect()), filename + " HUD fits viewport")
	for slot: Control in arena.get_player_slots() + arena.get_enemy_slots():
		_expect(bounds.encloses(slot.get_global_rect()), filename + " slot fits")
		var preview: Control = slot.get_node("TurnOrderPreviewOverlay")
		if preview.visible:
			var outline: Control = preview.get_node("Outline")
			var name_label: Control = slot.get_node("UnitInfo/UnitNameLabel")
			_expect(outline.get_global_rect().encloses(name_label.get_global_rect()), filename + " preview outline avoids text")
		for child: Node in slot.get_node("UnitInfo/StatusRow").get_children():
			var badge := child as Control
			if badge.is_visible_in_tree():
				_expect(slot.get_global_rect().encloses(badge.get_global_rect()), filename + " status fits")
	var ribbon: Control = arena.get_node("%TurnOrderRibbon")
	_expect(bounds.encloses(ribbon.get_global_rect()), filename + " ribbon fits")
	var host: Control = ribbon.get_node("CurrentEntryHost")
	_expect(bounds.encloses(host.get_global_rect()), filename + " pinned current stays visible")
	print(filename, " viewport ", root.content_scale_size, " HUD ", main.size)
	for child: Node in main.get_children():
		if child is Control and child.visible:
			print("  ", child.name, " ", child.position, " ", child.size)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(EVIDENCE + filename) == OK, "saved " + filename)


func _assert_preview(arena: BattleArena, expected: StringName) -> void:
	var count: int = 0
	for slot: Control in arena.get_player_slots() + arena.get_enemy_slots():
		if (slot.get_node("TurnOrderPreviewOverlay") as Control).visible:
			count += 1
			_expect(slot.get_meta("unit_id") == expected, "real input previews correct ID")
	_expect(count == (0 if expected.is_empty() else 1), "real input preview count " + String(expected))


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
