class_name Ac7_1LivingLanesTests
extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var units: Array[BattleUnitState] = []
	for side: int in range(2):
		for index: int in range(6):
			units.append(BattleUnitState.new(StringName("%d_%d" % [side, index]),
				"Character %d %d" % [side, index], side, index, 10 - index))
	arena.configure_units(units)
	for lane_name: String in ["PlayerBackline", "PlayerFrontline", "EnemyFrontline", "EnemyBackline"]:
		var lane := arena.find_child(lane_name, true, false)
		_expect(is_instance_valid(lane), "lane exists: " + lane_name)
	for side: int in range(2):
		var slots: Array[Control] = arena.get_player_slots() if side == 0 else arena.get_enemy_slots()
		_expect(slots.size() == 6, "six slots per side")
		for index: int in range(slots.size()):
			var slot: Control = slots[index]
			_expect(int(slot.get_meta("slot_index", -1)) == index, "numeric slot ordering")
			_expect(slot.get_meta("unit_id") == units[side * 6 + index].unit_id, "correct occupant")
			_expect(slot.has_method("render_unit"), "reusable unit renderer")
			_expect(slot.has_node("UnitInfo/HealthBar"), "visible HP bar")
			_expect(slot.has_node("UnitInfo/CharacterRow/Figure"), "character figure")
			var lane_suffix: String = "Frontline" if index < 3 else "Backline"
			_expect(String(slot.get_parent().name).ends_with(lane_suffix), "correct front/back membership")
	if arena.get_player_slots()[0].has_method("render_unit"):
		await _test_refresh_and_swap(arena)
		await _test_statuses(arena)
		_test_catalog()
	arena.queue_free()
	await process_frame
	if _failures.is_empty():
		print("AC7.1 living lanes: PASS")
	else:
		for failure: String in _failures:
			print("FAILED: " + failure)
	quit(0 if _failures.is_empty() else 1)


func _test_refresh_and_swap(arena: BattleArena) -> void:
	var actor := BattleUnitState.new(&"actor", "Actor", 0, 0, 10)
	var ally := BattleUnitState.new(&"ally", "Ally", 0, 3, 10)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 5)
	actor.current_hp = 13
	ally.add_armor(3)
	var units: Array[BattleUnitState] = [actor, ally, enemy]
	arena.configure_units(units)
	var original_slot: Control = arena.get_player_slots()[0]
	_expect(_label(original_slot, "HealthLabel") == "HP 13/20", "numeric HP refresh")
	_expect(_label(arena.get_player_slots()[1], "StateLabel") == "Empty", "empty visible")
	(arena.get_node("%DefaultSwapButton") as Button).pressed.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	arena.get_player_slots()[3].gui_input.emit(click)
	(arena.get_node("%DefaultActionConfirmButton") as Button).pressed.emit()
	_expect(actor.slot_index == 3 and ally.slot_index == 0, "swap routes through original input")
	_expect(arena.get_player_slots()[0] == original_slot, "slot view identity survives swap")
	_expect(_label(original_slot, "UnitNameLabel") == "Ally", "identity follows swapped unit")
	_expect(_label(arena.get_player_slots()[3], "HealthLabel") == "HP 13/20", "HP follows swapped unit")
	_expect(_visible_statuses(original_slot).has("armor"), "armor follows swapped unit")
	actor.current_hp = 0
	arena.notify_authoritative_battle_change()
	var defeated: Control = arena.get_player_slots()[3]
	_expect(_label(defeated, "StateLabel") == "Defeated", "defeated marker")
	_expect(_label(defeated, "UnitNameLabel") == "Actor", "defeated identity retained")
	_expect(_visible_statuses(defeated).is_empty(), "defeated has no active badges")
	arena.remove_battle_unit(actor.unit_id)
	_expect(_label(defeated, "StateLabel") == "Empty", "removal clears view")
	_expect(_label(defeated, "UnitNameLabel").is_empty(), "removal clears name")
	arena.configure_units([enemy])
	_expect(_visible_statuses(original_slot).is_empty(), "battle reset clears stale status")
	await process_frame


func _test_statuses(arena: BattleArena) -> void:
	var actor := BattleUnitState.new(&"actor", "Status bearer", 0, 0, 10)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 5)
	arena.configure_units([actor, enemy])
	var source: RefCounted = load("res://Scripts/Battle/battle_keyword_source.gd").create(&"enemy", &"test", 2)
	actor.add_armor(4)
	actor.apply_advantage(source, arena.round_number)
	actor.apply_snared(source, arena.round_number)
	actor.apply_bleed(source, 2)
	actor.add_speed_modifier(&"speed", -2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, arena.round_number)
	arena.notify_authoritative_battle_change()
	var slot: Control = arena.get_player_slots()[0]
	var expected: Array[String] = ["armor", "advantage", "snared", "bleed", "speed"]
	_expect(_visible_statuses(slot) == expected, "all active statuses in deterministic order")
	_expect(slot.tooltip_text.contains("Advantage") and slot.tooltip_text.contains("Bleed"),
		"slot tooltip expands status abbreviations")
	var before_hp: int = actor.current_hp
	slot.call("render_unit", actor, arena.round_number)
	slot.call("render_unit", actor, arena.round_number)
	_expect(_visible_statuses(slot) == expected, "repeated rendering has no duplicates")
	_expect(actor.current_hp == before_hp and actor.get_armor() == 4, "rendering is read-only")
	actor.spend_armor(4)
	actor.consume_advantage(arena.round_number)
	actor.clear_round_keywords(arena.round_number)
	actor.expire_speed_modifiers_for_round(arena.round_number)
	actor.resolve_bleed_after_committed_action()
	actor.resolve_bleed_after_committed_action()
	arena.notify_authoritative_battle_change()
	_expect(_visible_statuses(slot).is_empty(), "consumption and expiry remove badges")
	actor.current_hp = 7
	arena.notify_authoritative_battle_change()
	_expect((slot.get_node("UnitInfo/HealthBar") as ProgressBar).value == 7, "damage updates bar")
	actor.current_hp = 15
	arena.notify_authoritative_battle_change()
	_expect(_label(slot, "HealthLabel") == "HP 15/20", "healing updates HP")
	actor.add_speed_modifier(&"up", 2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1)
	actor.add_speed_modifier(&"down", -2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1)
	arena.notify_authoritative_battle_change()
	_expect(_visible_statuses(slot) == ["speed"], "net-zero active speed modifiers remain visible")
	_expect((slot.get_node("UnitInfo/StatusRow/speed") as Label).text.contains("±0"), "net-zero speed label")
	await process_frame


func _test_catalog() -> void:
	var catalog: Script = load("res://Scripts/UI/battle_unit_presentation.gd")
	var roles: Array[String] = ["Bruiser", "Skirmisher", "Controller", "Support", "Striker", "Support"]
	var ids: Array[StringName] = RunCharacterCatalog.get_goblin_class_ids()
	for index: int in range(ids.size()):
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(ids[index])
		var unit := BattleUnitState.new(&"generated_instance", "Renamed", 0, 0, 8, 20, character.get_skills())
		_expect(catalog.call("role_for", unit) == roles[index], "authored role survives renamed identity")
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"brakka_rustbanner")
	var commander_unit := BattleUnitState.new(&"renamed_commander", "Renamed", 0, 1, 8, 20, commander.get_skills())
	_expect(catalog.call("role_for", commander_unit) == "Commander", "commander overrides shared bruiser skills")
	var unknown := BattleUnitState.new(&"unknown", "Unknown", 0, 0, 8)
	_expect(catalog.call("role_for", unknown) == "Combatant", "unknown fallback")


func _visible_statuses(slot: Control) -> Array[String]:
	var result: Array[String] = []
	for badge: Node in slot.get_node("UnitInfo/StatusRow").get_children():
		if badge is Control and (badge as Control).visible:
			result.append(String(badge.get_meta("status_id", "")))
	return result


func _label(slot: Control, child_name: String) -> String:
	return (slot.get_node("UnitInfo/" + child_name) as Label).text


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
