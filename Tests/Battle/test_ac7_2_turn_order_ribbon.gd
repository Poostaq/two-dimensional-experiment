class_name Ac7_2TurnOrderRibbonTests
extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var ribbon: Control = arena.find_child("TurnOrderRibbon", true, false)
	_expect(is_instance_valid(ribbon), "new ribbon exists")
	for slot: Control in arena.get_player_slots() + arena.get_enemy_slots():
		_expect(slot.has_node("TurnOrderPreviewOverlay"), "new preview overlay exists")
	if is_instance_valid(ribbon) and ribbon.has_method("get_entry_ids"):
		await _test_ribbon(arena, ribbon)
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	print("AC7.2 turn-order ribbon: ", "PASS" if _failures.is_empty() else "FAIL")
	quit(0 if _failures.is_empty() else 1)


func _test_ribbon(arena: BattleArena, ribbon: Control) -> void:
	var actor := BattleUnitState.new(&"actor", "Same Name", 0, 0, 10)
	var enemy := BattleUnitState.new(&"enemy", "Same Name", 1, 0, 8)
	var ally := BattleUnitState.new(&"ally", "Ally", 0, 3, 6)
	arena.configure_units([actor, enemy, ally])
	await process_frame
	_expect(ribbon.call("get_entry_ids") == [&"actor", &"enemy", &"ally"], "queue and duplicate-name identity")
	var a: Control = ribbon.call("get_entry_control", &"actor")
	var b: Control = ribbon.call("get_entry_control", &"enemy")
	_assert_now(ribbon, &"actor")
	var before: Dictionary = _combat_snapshot(arena)
	a.mouse_entered.emit()
	_assert_preview(arena, &"actor")
	b.mouse_entered.emit()
	a.mouse_exited.emit()
	_assert_preview(arena, &"enemy")
	b.mouse_exited.emit()
	_assert_preview(arena, &"")
	a.grab_focus()
	_assert_preview(arena, &"actor")
	b.mouse_entered.emit()
	_assert_preview(arena, &"enemy")
	_assert_now(ribbon, &"actor")
	b.mouse_exited.emit()
	_assert_preview(arena, &"actor")
	a.pressed.emit()
	_expect(_combat_snapshot(arena) == before, "preview and activation never mutate combat")
	actor.current_hp -= 1
	arena.notify_authoritative_battle_change()
	_expect(ribbon.call("get_entry_control", &"actor") == a and a.has_focus(), "benign refresh preserves instance and focus")
	_assert_preview(arena, &"actor")
	a.release_focus()
	_assert_preview(arena, &"")
	# Selected skill transaction must coexist with ribbon preview.
	var skilled: RunCharacter = RunCharacterCatalog.create_by_class_id(&"scrapshield_bruiser")
	if is_instance_valid(skilled):
		var skill_actor := BattleUnitState.new(&"actor", "Skilled", 0, 0, 10, 20, skilled.get_skills())
		arena.configure_units([skill_actor, enemy, ally])
		arena.select_skill(skill_actor.skills[0].skill_id)
		before = _combat_snapshot(arena)
		a = ribbon.call("get_entry_control", &"actor")
		a.mouse_entered.emit()
		a.mouse_exited.emit()
		_expect(_combat_snapshot(arena) == before, "skill selection preserved")
	arena.configure_units([actor, enemy, ally])
	a = ribbon.call("get_entry_control", &"actor")
	a.grab_focus()
	arena.advance_turn()
	_expect(ribbon.call("get_entry_ids") == [&"enemy", &"ally"], "acted units excluded from display")
	_assert_now(ribbon, &"enemy")
	_assert_preview(arena, &"")
	arena.advance_turn()
	_expect(ribbon.call("get_entry_ids") == [&"ally"], "last current-round actor only")
	arena.advance_turn()
	_expect(ribbon.call("get_entry_ids") == [&"actor", &"enemy", &"ally"], "round rebuild displayed")
	_assert_now(ribbon, &"actor")
	# A reset can reuse the same IDs; old input ownership must still disappear.
	a = ribbon.call("get_entry_control", &"actor")
	a.grab_focus()
	arena.configure_units([actor, enemy, ally])
	_assert_preview(arena, &"")
	b = ribbon.call("get_entry_control", &"enemy")
	b.grab_focus()
	enemy.current_hp = 0
	arena.notify_authoritative_battle_change()
	_expect(ribbon.call("get_entry_ids") == [&"actor", &"ally"], "defeated excluded without queue mutation")
	_assert_preview(arena, &"")
	_expect(arena.get_turn_queue().size() == 3, "display filtering does not rewrite authoritative queue")
	var ally_control: Control = ribbon.call("get_entry_control", &"ally")
	ally_control.mouse_entered.emit()
	arena.remove_battle_unit(&"ally")
	_assert_preview(arena, &"")
	_expect(ribbon.call("get_entry_ids") == [&"actor"], "removed ID absent")
	# Preview follows a relocated occupant on a same-turn authoritative refresh.
	enemy.current_hp = 20
	arena.configure_units([actor, enemy, ally])
	ally_control = ribbon.call("get_entry_control", &"ally")
	ally_control.mouse_entered.emit()
	actor.slot_index = 3
	ally.slot_index = 0
	arena.notify_authoritative_battle_change()
	_assert_preview(arena, &"ally")
	_expect((arena.get_player_slots()[0].get_node("TurnOrderPreviewOverlay") as Control).visible, "preview follows occupant not cached slot")
	# Existing preparation boundary must clear and hide ribbon content.
	arena.configure(Vector2i.ZERO, WorldEncounterType.COMBAT)
	var record_script: Script = load("res://Scripts/Battle/battle_preparation_record.gd")
	var offered: RefCounted = record_script.offered(&"ribbon-prep", Vector2i.ZERO,
		WorldEncounterType.COMBAT, String(arena.get_setup_identity().get("canonical_key")))
	_expect(arena.configure_preparation(offered), "valid preparation fixture accepted")
	_assert_preview(arena, &"")
	_expect(ribbon.call("get_entry_ids").is_empty(), "preparation blocks ribbon")
	arena.configure_units([])
	_assert_preview(arena, &"")
	_assert_now(ribbon, &"")
	_expect(ribbon.call("get_entry_ids").is_empty(), "empty queue safe")
	# Dense fixture locks tie ordering and all twelve entries.
	var dense: Array[BattleUnitState] = []
	var expected: Array[StringName] = []
	for side: int in range(2):
		for index: int in range(6):
			var id := StringName("%d_%d" % [side, index])
			dense.append(BattleUnitState.new(id, "Unit", side, index, 5))
			expected.append(id)
	arena.configure_units(dense)
	_expect(ribbon.call("get_entry_ids") == expected, "twelve entries preserve authoritative tie order")
	var entry: Control = ribbon.call("get_entry_control", &"1_5")
	entry.grab_focus()
	arena.configure_units([BattleUnitState.new(&"winner", "Winner", 0, 0, 10), BattleUnitState.new(&"victim", "Victim", 1, 0, 1)])
	var winner: BattleUnitState = arena.get_current_unit()
	winner.power = 100
	arena.preview_default_attack(&"winner", &"victim")
	arena.confirm_default_attack(&"winner", &"victim", arena.get_battle_revision())
	_expect(arena.is_battle_complete(), "terminal fixture completes combat")
	_assert_now(ribbon, &"")
	_assert_preview(arena, &"")
	_expect(ribbon.call("get_entry_ids").is_empty(), "terminal ribbon has no actor")
	await process_frame


func _combat_snapshot(arena: BattleArena) -> Dictionary:
	var hp: Array[int] = []
	var ids: Array[StringName] = []
	for unit: BattleUnitState in arena.get_turn_queue():
		hp.append(unit.current_hp)
		ids.append(unit.unit_id)
	return {"hp": hp, "queue": ids, "actor": arena.get_current_unit().unit_id,
		"revision": arena.get_battle_revision(), "round": arena.round_number,
		"skill": arena.get_selected_skill_id(), "inspected": arena.get_inspected_unit_id(),
		"transaction": arena.get_skill_presentation_snapshot().duplicate(true),
		"history": arena.get_committed_action_history_snapshot().size()}


func _assert_now(ribbon: Control, current_id: StringName) -> void:
	var count: int = 0
	for id: StringName in ribbon.call("get_entry_ids"):
		var entry: Control = ribbon.call("get_entry_control", id)
		var now: Control = entry.get_node("NowLabel")
		var frame: Control = entry.get_node("CurrentFrame")
		_expect(now.visible == frame.visible, "NOW and independent current frame agree")
		if now.visible:
			count += 1
			_expect(id == current_id, "correct NOW identity")
	_expect(count == (0 if current_id.is_empty() else 1), "exactly one NOW when active")


func _assert_preview(arena: BattleArena, expected: StringName) -> void:
	var count: int = 0
	for slot: Control in arena.get_player_slots() + arena.get_enemy_slots():
		var overlay: Control = slot.get_node("TurnOrderPreviewOverlay")
		if overlay.visible:
			count += 1
			_expect(slot.get_meta("unit_id", &"") == expected, "preview follows stable ID")
	_expect(count == (0 if expected.is_empty() else 1), "exactly one or zero previews: " + String(expected))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
