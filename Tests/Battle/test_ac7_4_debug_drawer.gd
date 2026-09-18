class_name Ac7_4DebugDrawerTests
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _run() -> void:
	var arena := (load("res://Scenes/battle_arena.tscn") as PackedScene).instantiate() as Control
	root.add_child(arena)
	arena.call("configure_units", load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	await process_frame
	var drawer := arena.get_node_or_null("%BattleDebugDrawer") as Control
	_assert(is_instance_valid(drawer), "authored drawer exists")
	if is_instance_valid(drawer) and drawer.has_method("set_open"):
		await _test_drawer(arena, drawer)
		await _test_logs_commands(arena, drawer)
		await _test_reward_modal(arena, drawer)
		await _test_live_actions(arena, drawer)
	else:
		_assert(false, "drawer controller API exists")
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	if _failures.is_empty():
		print("AC7.4 debug drawer: PASS")
	quit(0 if _failures.is_empty() else 1)

func _snapshot(arena: Control) -> Dictionary:
	var queue: Array[StringName] = []
	var hp: Array[int] = []
	for unit: BattleUnitState in arena.get_turn_queue():
		queue.append(unit.unit_id)
		hp.append(unit.current_hp)
	return {"queue": queue, "hp": hp, "round": arena.round_number,
		"revision": arena.get_battle_revision(), "selected": arena.get_selected_skill_id(),
		"transaction": arena.get_skill_presentation_snapshot(),
		"log": arena.get_battle_log_entries().size()}

func _rectangles(arena: Control) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for control: Control in arena.get_player_slots() + arena.get_enemy_slots():
		result.append(control.get_global_rect())
	for path: String in ["%PlayerFormation", "%EnemyFormation", "%TurnOrderRibbon", "%BattleActionBar", "%BattleResultPanel"]:
		result.append((arena.get_node(path) as Control).get_global_rect())
	return result

func _test_drawer(arena: Control, drawer: Control) -> void:
	var handle := drawer.get_node("%DebugHandle") as Button
	var close := drawer.get_node("%CloseButton") as Button
	_assert(not drawer.is_open() and handle.visible, "collapsed by default")
	for width: int in [1152, 1024]:
		root.size = Vector2i(width, 648)
		arena.size = Vector2(width, 648)
		await process_frame
		await process_frame
		var before: Dictionary = _snapshot(arena)
		var rects: Array[Rect2] = _rectangles(arena)
		handle.grab_focus()
		drawer.set_open(true)
		await process_frame
		await process_frame
		_assert(drawer.is_open() and close.has_focus(), "open focuses Close")
		_assert(_rectangles(arena) == rects, "open does not reflow at " + str(width))
		drawer.set_open(false)
		await process_frame
		_assert(handle.has_focus() and not close.is_visible_in_tree(), "close restores handle")
		_assert(_rectangles(arena) == rects, "close does not reflow")
		_assert(_snapshot(arena) == before, "drawer interactions preserve combat")
		var live := drawer.get_node("%LiveState") as Label
		_assert(live.text.contains("Round 1"), "live round is populated")
		var queue := drawer.get_node("%InitiativeQueue") as Label
		_assert(queue.text.contains(String(arena.get_current_unit().unit_id)), "queue contains stable actor identity")
		drawer.set_open(true)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape)
		await process_frame
		_assert(not drawer.is_open(), "Escape closes drawer")
		_assert(_snapshot(arena) == before, "Escape preserves selection")
	# An invalid return target falls back to the handle.
	var temporary := Button.new()
	arena.add_child(temporary)
	temporary.grab_focus()
	drawer.set_open(true)
	temporary.queue_free()
	await process_frame
	drawer.set_open(false)
	_assert(handle.has_focus(), "freed focus returns to handle")

func _test_logs_commands(arena: Control, drawer: Control) -> void:
	var actor := BattleUnitState.new(&"actor", "Same name", 0, 0, 10, 30)
	var enemy := BattleUnitState.new(&"enemy", "Same name", 1, 0, 5, 30)
	var units: Array[BattleUnitState] = [actor, enemy]
	arena.configure_units(units)
	await process_frame
	var damage := drawer.get_node("%AdvanceTurnDebugButton") as Button
	var rows := drawer.get_node("%BattleLogEntries") as VBoxContainer
	damage.pressed.emit()
	_assert(enemy.current_hp == 30 and arena.get_battle_log_entries().is_empty(), "closed command guarded")
	drawer.set_open(true)
	damage.pressed.emit()
	await process_frame
	_assert(enemy.current_hp == 23, "one command deals exactly seven damage")
	_assert(arena.get_battle_log_entries().size() == 1 and rows.get_child_count() == 1, "one chronological log row")
	_assert(arena.get_current_unit() == enemy, "one turn advance")
	var row := rows.get_child(0) as Label
	row.mouse_entered.emit()
	_assert(arena.get("_hovered_log_index") == 0, "damage hover forwards history identity")
	drawer.append_log_row({"index": 1, "sequence": 1, "text": "newer", "previewable": true})
	var newer := rows.get_child(1) as Label
	newer.mouse_entered.emit()
	row.mouse_exited.emit()
	_assert(drawer.get("_preview_index") == 1, "late older exit preserves preview source")
	drawer.set_open(false)
	_assert(arena.get("_hovered_log_index") == -1, "close clears hover")
	var row_identity: int = row.get_instance_id()
	arena.call("_refresh_action_bar")
	_assert(rows.get_child(0).get_instance_id() == row_identity, "state refresh preserves rows")
	drawer.append_log_row({"index": 2, "sequence": 2, "text": "message", "previewable": false})
	var diagnostics := drawer.get_node("DrawerPanel/DrawerContents/DiagnosticsScroll") as ScrollContainer
	diagnostics.scroll_vertical = 100
	arena.configure_units(units)
	await process_frame
	await process_frame
	_assert(diagnostics.scroll_vertical == 0, "reset returns diagnostics to top")
	_assert(not drawer.is_open() and rows.get_child_count() == 0, "reset beats deferred scroll and clears rows")
	_assert((drawer.get_node("%LiveState") as Label).text.contains("Round 1"), "reset refreshes state")
	arena.set("_action_in_progress", true)
	arena.call("_refresh_turn_ui")
	drawer.set_open(true)
	var before: Dictionary = _snapshot(arena)
	damage.pressed.emit()
	_assert(damage.disabled and _snapshot(arena) == before, "resolving command guarded")
	arena.set("_action_in_progress", false)
	var empty_units: Array[BattleUnitState] = []
	arena.configure_units(empty_units)
	await process_frame
	_assert(damage.disabled, "empty queue command unavailable")

func _test_reward_modal(arena: Control, drawer: Control) -> void:
	arena.configure(Vector2i.ZERO, WorldEncounterType.COMBAT)
	var actor := BattleUnitState.new(&"actor", "Actor", 0, 0, 10, 30)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 5, 1)
	var units: Array[BattleUnitState] = [actor, enemy]
	arena.configure_units(units)
	drawer.set_open(true)
	arena.perform_debug_damage()
	await process_frame
	var handle := drawer.get_node("%DebugHandle") as Button
	_assert(arena.is_battle_complete() and not drawer.is_open() and not handle.visible, "reward modal collapses and excludes drawer")
	var reward: BattleRewardOption = arena.get_reward_options()[0]
	arena.select_reward(reward.reward_id)
	arena.confirm_reward_selection()
	await process_frame
	drawer.set_open(true)
	_assert(not drawer.is_open() and not handle.visible, "recruitment placement keeps drawer excluded")
	arena.restore_pending_recruitment(reward)
	await process_frame
	_assert(not handle.visible, "recruitment cancel returns to blocking reward modal")
	arena.configure_units(units)
	await process_frame
	_assert(handle.visible and not drawer.is_open(), "next battle restores collapsed handle")

func _assert_live_matches(arena: Control, drawer: Control) -> void:
	var view: Dictionary = drawer.get("_view")
	var queue: Array = arena.get_turn_queue()
	var rows: Array = view["queue_rows"]
	_assert(rows.size() == queue.size(), "diagnostic queue has every authoritative row")
	for index: int in mini(rows.size(), queue.size()):
		_assert(rows[index]["unit_id"] == queue[index].unit_id, "diagnostic order " + str(index))
		_assert(rows[index]["current"] == (queue[index] == arena.get_current_unit()), "diagnostic current marker " + str(index))
		_assert(rows[index]["effective_speed"] == queue[index].get_effective_speed(), "diagnostic effective speed")
	_assert(view["round"] == arena.round_number and view["revision"] == arena.get_battle_revision(), "live round and revision match")

func _test_live_actions(arena: Control, drawer: Control) -> void:
	arena.configure_units(load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	var bar := arena.get_node("%BattleActionBar") as Control
	var live := drawer.get_node("%LiveState") as Label
	var actor: BattleUnitState = arena.get_current_unit()
	var skill: CharacterSkill = actor.skills[0]
	arena.select_skill(skill.skill_id)
	_assert(live.text.contains(skill.display_name), "selected skill appears in diagnostics")
	var target: BattleUnitState = arena.get_unit_by_id(&"enemy_0")
	arena.select_skill_target(target.unit_id)
	_assert(live.text.contains(arena.get_skill_presentation_snapshot()["summary"]), "selected target summary stays live")
	(bar.get_node("%DefaultSwapButton") as Button).pressed.emit()
	arena.call("_select_default_action_target", &"player_1", 1)
	_assert(live.text.contains("Default Swap") and live.text.contains("player_1"), "Swap and target stay live")
	(bar.get_node("%CancelButton") as Button).pressed.emit()
	_assert(live.text.contains("Action: None"), "cancel clears diagnostic action")
	_assert_live_matches(arena, drawer)
	arena.remove_battle_unit(&"enemy_0")
	_assert_live_matches(arena, drawer)
	var first_round: int = arena.round_number
	for index: int in arena.get_turn_queue().size():
		arena.advance_turn()
		_assert_live_matches(arena, drawer)
	_assert(arena.round_number > first_round, "queue fixture crosses round rollover")
