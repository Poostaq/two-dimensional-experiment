class_name CaptureAc7_1LivingLanes
extends SceneTree

const EVIDENCE: String = "res://Docs/Specs/AC7/Evidence/AC7.1/"
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1152, 648)
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var units: Array[BattleUnitState] = []
	var ids: Array[StringName] = RunCharacterCatalog.get_goblin_class_ids()
	for side: int in range(2):
		for index: int in range(6):
			var character: RunCharacter = RunCharacterCatalog.create_by_class_id(ids[index])
			var unit := BattleUnitState.new(StringName("%d_%d" % [side, index]), character.display_name,
				side, index, character.base_speed, character.max_hp, character.get_skills())
			units.append(unit)
	units[1].display_name = "Wirefang Skirmisher of the Eastern Warren"
	arena.configure_units(units)
	var source: RefCounted = load("res://Scripts/Battle/battle_keyword_source.gd").create(&"1_0", &"fixture", 2)
	for unit: BattleUnitState in units:
		unit.add_armor(4)
		unit.apply_advantage(source, 1)
		unit.apply_snared(source, 1)
		unit.apply_bleed(source, 2)
		unit.add_speed_modifier(&"fixture", -1, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1)
	arena.notify_authoritative_battle_change()
	await _capture(arena, "living-lanes-dense-1152.png")
	await _click(arena.get_node("%DefaultAttackButton") as Control)
	await _click(arena.get_enemy_slots()[0])
	await _capture(arena, "living-lanes-dense-target-1152.png")
	await _click(arena.get_node("%DefaultActionCancelButton") as Control)
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await _capture(arena, "living-lanes-dense-1280.png")
	root.content_scale_size = Vector2i(1152, 648)
	root.size = Vector2i(1152, 648)
	var actor := BattleUnitState.new(&"actor", "Vanguard", 0, 0, 10)
	actor.power = 6
	var ally := BattleUnitState.new(&"ally", "Rear Guard", 0, 3, 8)
	var enemy := BattleUnitState.new(&"enemy", "Opponent", 1, 0, 5)
	var defeated := BattleUnitState.new(&"defeated", "Fallen Scout", 1, 4, 4)
	defeated.current_hp = 0
	arena.configure_units([actor, ally, enemy, defeated])
	await _capture(arena, "living-lanes-sparse-1152.png")
	await _click(arena.get_node("%DefaultAttackButton") as Control)
	await _click(arena.get_enemy_slots()[0])
	_expect((arena.get_node("%DefaultActionConfirmButton") as Button).disabled == false,
		"real pointer input selects attack and target")
	await _capture(arena, "living-lanes-target-1152.png")
	await _click(arena.get_node("%DefaultActionCancelButton") as Control)
	_expect(enemy.current_hp == 20, "cancel leaves target HP unchanged")
	var attack := arena.get_node("%DefaultAttackButton") as Button
	attack.grab_focus()
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	root.push_input(key)
	await process_frame
	key = InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = false
	root.push_input(key)
	await process_frame
	await _click(arena.get_enemy_slots()[0])
	await _click(arena.get_node("%DefaultActionConfirmButton") as Control)
	_expect(enemy.current_hp == 14, "keyboard attack plus pointer target/confirm commits damage")
	_expect((arena.get_enemy_slots()[0].get_node("UnitInfo/HealthLabel") as Label).text == "HP 14/20",
		"committed action refreshes HP")
	arena.configure_units([actor, ally, enemy, defeated])
	await process_frame
	await _click(arena.get_node("%DefaultSwapButton") as Control)
	await _click(arena.get_player_slots()[3])
	await _click(arena.get_node("%DefaultActionConfirmButton") as Control)
	_expect(actor.slot_index == 3 and ally.slot_index == 0, "real pointer swap exchanges occupants")
	await _capture(arena, "living-lanes-swapped-1152.png")
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	print("AC7.1 rendered input/layout QA: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)


func _capture(arena: BattleArena, filename: String) -> void:
	for frame: int in range(4):
		await process_frame
	var bounds := Rect2(Vector2.ZERO, Vector2(root.size))
	var main := arena.get_node("Margin/VBox") as Control
	_expect(bounds.encloses(main.get_global_rect()), filename + " entire battle HUD fits")
	for slot: Control in arena.get_player_slots() + arena.get_enemy_slots():
		_expect(bounds.encloses(slot.get_global_rect()), filename + " slot fits")
		for child: Node in slot.get_node("UnitInfo/StatusRow").get_children():
			var badge := child as Control
			if badge.is_visible_in_tree():
				_expect(slot.get_global_rect().encloses(badge.get_global_rect()), filename + " status fits its slot")
	print(filename, " viewport ", root.size, " HUD ", main.size)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var error: Error = root.get_texture().get_image().save_png(EVIDENCE + filename)
		_expect(error == OK, "screenshot saved: " + filename)


func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
