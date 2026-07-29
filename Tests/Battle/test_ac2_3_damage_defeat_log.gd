class_name Ac2_3DamageDefeatLogTests
extends SceneTree

const UNIT_PATH := "res://Scripts/Battle/battle_unit_state.gd"
const QUEUE_PATH := "res://Scripts/Battle/battle_turn_queue.gd"
const TARGET_PATH := "res://Scripts/Battle/battle_target_selector.gd"
const DAMAGE_PATH := "res://Scripts/Battle/battle_damage_resolver.gd"
const LOG_PATH := "res://Scripts/Battle/battle_log_entry.gd"
const ARENA_PATH := "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT := 18
const STARTING_HP := 20
const DEBUG_DAMAGE := 7

var _failures: Array[String] = []
var _unit_script: GDScript
var _queue_script: GDScript
var _target_script: GDScript
var _damage_script: GDScript
var _log_script: GDScript


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_unit_script = load(UNIT_PATH) as GDScript
	_queue_script = load(QUEUE_PATH) as GDScript
	_target_script = load(TARGET_PATH) as GDScript if ResourceLoader.exists(TARGET_PATH) else null
	_damage_script = load(DAMAGE_PATH) as GDScript if ResourceLoader.exists(DAMAGE_PATH) else null
	_log_script = load(LOG_PATH) as GDScript if ResourceLoader.exists(LOG_PATH) else null
	_test_debug_units_start_at_full_hp()
	_test_fixed_damage_reduces_hp()
	_test_damage_clamps_at_zero()
	_test_same_row_targeting()
	_test_front_column_targeting_tie()
	_test_slot_index_targeting_tie()
	_test_defeated_target_is_ignored()
	await _test_defeated_slot_remains_visible()
	_test_defeated_unit_leaves_queue()
	await _test_defeat_preserves_next_actor()
	await _test_one_action_one_turn()
	await _test_one_action_one_log_entry()
	await _test_defeat_log_entry()
	await _test_no_opponent_no_op()
	await _test_resolution_feedback()
	await _test_hover_feedback()
	await _test_hover_exit_restores_current()
	await _test_reconfigure_resets_battle_state()
	_report()
	quit(1 if not _failures.is_empty() else 0)


func _unit(id: StringName, side: int, slot_index: int, speed: int = 5) -> RefCounted:
	return _unit_script.new(id, str(id), side, slot_index, speed) as RefCounted


func _has_property(object: Object, property_name: StringName) -> bool:
	for property: Dictionary in object.get_property_list():
		if property.get("name") == property_name:
			return true
	return false


func _set_hp(unit: RefCounted, hp: int) -> void:
	if _has_property(unit, &"current_hp"):
		unit.set("current_hp", hp)


func _instantiate_arena() -> Control:
	var packed := load(ARENA_PATH) as PackedScene
	var arena := packed.instantiate() as Control if packed != null else null
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _typed_units(units: Array) -> Array[BattleUnitState]:
	var typed: Array[BattleUnitState] = []
	for unit: Variant in units:
		typed.append(unit as BattleUnitState)
	return typed


func _configure(arena: Control, units: Array) -> void:
	if arena != null and arena.has_method("configure_units"):
		arena.call("configure_units", _typed_units(units))


func _test_debug_units_start_at_full_hp() -> void:
	var unit := _unit(&"unit", 0, 0)
	var valid := _has_property(unit, &"max_hp") and _has_property(unit, &"current_hp")
	if valid:
		valid = int(unit.get("max_hp")) == STARTING_HP and int(unit.get("current_hp")) == STARTING_HP and bool(unit.call("is_active"))
	_assert(valid, "debug units start at full HP", "expected active 20/20 HP")


func _test_fixed_damage_reduces_hp() -> void:
	var attacker := _unit(&"attacker", 0, 0)
	var receiver := _unit(&"receiver", 1, 0)
	var result: Variant = _damage_script.call("apply_damage", attacker, receiver, DEBUG_DAMAGE) if _damage_script != null else null
	_assert(result != null and int(result.get("applied_damage")) == 7 and int(receiver.get("current_hp")) == 13, "fixed damage reduces HP", "expected one 7 damage hit to leave 13 HP")


func _test_damage_clamps_at_zero() -> void:
	var attacker := _unit(&"attacker", 0, 0)
	var receiver := _unit(&"receiver", 1, 0)
	_set_hp(receiver, 6)
	var result: Variant = _damage_script.call("apply_damage", attacker, receiver, DEBUG_DAMAGE) if _damage_script != null else null
	_assert(result != null and int(result.get("applied_damage")) == 6 and int(receiver.get("current_hp")) == 0 and bool(result.get("caused_defeat")), "damage clamps at zero", "expected applied -6 and defeat")


func _select(attacker: RefCounted, units: Array) -> RefCounted:
	return _target_script.call("find_closest_enemy", attacker, _typed_units(units)) as RefCounted if _target_script != null else null


func _test_same_row_targeting() -> void:
	var attacker := _unit(&"attacker", 0, 1)
	var same_row := _unit(&"same_row", 1, 1)
	var other_row := _unit(&"other_row", 1, 0)
	_assert(_select(attacker, [other_row, same_row]) == same_row, "same row targeting", "same row must win")


func _test_front_column_targeting_tie() -> void:
	var attacker := _unit(&"attacker", 0, 1)
	var front := _unit(&"front", 1, 0)
	var back := _unit(&"back", 1, 5)
	_assert(_select(attacker, [back, front]) == front, "front column targeting tie", "front column must win equal row distance")


func _test_slot_index_targeting_tie() -> void:
	var attacker := _unit(&"attacker", 0, 1)
	var slot_zero := _unit(&"slot_0", 1, 0)
	var slot_two := _unit(&"slot_2", 1, 2)
	_assert(_select(attacker, [slot_two, slot_zero]) == slot_zero, "slot index targeting tie", "lowest slot must win final tie")


func _test_defeated_target_is_ignored() -> void:
	var attacker := _unit(&"attacker", 0, 0)
	var defeated := _unit(&"defeated", 1, 0)
	var active := _unit(&"active", 1, 1)
	_set_hp(defeated, 0)
	_assert(_select(attacker, [defeated, active]) == active, "defeated target ignored", "inactive target must be skipped")


func _test_defeated_slot_remains_visible() -> void:
	var arena := await _instantiate_arena()
	var attacker := _unit(&"attacker", 0, 0, 9)
	var receiver := _unit(&"receiver", 1, 0, 8)
	_set_hp(receiver, 0)
	_configure(arena, [attacker, receiver])
	var label := arena.get_node_or_null("%EnemyFormation/Slot0/UnitInfo/HealthLabel") as Label if arena != null else null
	_assert(label != null and label.text == "Defeated — HP 0/20", "defeated slot remains visible", "expected exact defeated HP presentation")
	_free_arena(arena)


func _test_defeated_unit_leaves_queue() -> void:
	var active := _unit(&"active", 0, 0)
	var defeated := _unit(&"defeated", 1, 0)
	_set_hp(defeated, 0)
	var ordered: Array = _queue_script.call("build", _typed_units([active, defeated])) if _queue_script != null else []
	_assert(ordered == [active], "defeated unit leaves queue", "queue must contain only active unit")


func _test_defeat_preserves_next_actor() -> void:
	var arena := await _instantiate_arena()
	var attacker := _unit(&"attacker", 0, 0, 9)
	var receiver := _unit(&"receiver", 1, 0, 8)
	var next_actor := _unit(&"next", 0, 1, 7)
	var remaining_enemy := _unit(&"remaining_enemy", 1, 1, 1)
	_set_hp(receiver, 6)
	_configure(arena, [attacker, receiver, next_actor, remaining_enemy])
	if arena != null and arena.has_method("perform_debug_damage"):
		arena.call("perform_debug_damage")
	var current: Variant = arena.call("get_current_unit") if arena != null else null
	_assert(current != null and current.get("unit_id") == &"next", "defeat preserves next actor", "expected next active unit without repeat or skip")
	_free_arena(arena)


func _test_one_action_one_turn() -> void:
	var arena := await _instantiate_arena()
	var before: Variant = arena.call("get_current_unit") if arena != null else null
	if arena != null and arena.has_method("perform_debug_damage"):
		arena.call("perform_debug_damage")
	var after: Variant = arena.call("get_current_unit") if arena != null else null
	_assert(before != null and after != null and before != after, "one action one turn", "accepted action must advance exactly once")
	_free_arena(arena)


func _test_one_action_one_log_entry() -> void:
	var arena := await _instantiate_arena()
	if arena != null and arena.has_method("perform_debug_damage"):
		arena.call("perform_debug_damage")
	var entries: Array = arena.call("get_battle_log_entries") if arena != null and arena.has_method("get_battle_log_entries") else []
	_assert(entries.size() == 1 and int(entries[0].get("applied_damage")) == 7, "one action one log entry", "expected exactly one 7-damage event")
	_free_arena(arena)


func _test_defeat_log_entry() -> void:
	var arena := await _instantiate_arena()
	var attacker := _unit(&"attacker", 0, 0, 9)
	var receiver := _unit(&"receiver", 1, 0, 8)
	_set_hp(receiver, 6)
	_configure(arena, [attacker, receiver])
	if arena != null and arena.has_method("perform_debug_damage"):
		arena.call("perform_debug_damage")
	var entries: Array = arena.call("get_battle_log_entries") if arena != null and arena.has_method("get_battle_log_entries") else []
	_assert(entries.size() == 1 and bool(entries[0].get("caused_defeat")) and int(entries[0].get("applied_damage")) == 6, "defeat log entry", "expected defeating applied-damage event")
	_free_arena(arena)


func _test_no_opponent_no_op() -> void:
	var arena := await _instantiate_arena()
	var attacker := _unit(&"attacker", 0, 0)
	_configure(arena, [attacker])
	var round_before := int(arena.get("round_number")) if arena != null else -1
	if arena != null and arena.has_method("perform_debug_damage"):
		arena.call("perform_debug_damage")
	var button := arena.get_node_or_null("%AdvanceTurnDebugButton") as Button if arena != null else null
	var entries: Array = arena.call("get_battle_log_entries") if arena != null and arena.has_method("get_battle_log_entries") else []
	_assert(button != null and button.disabled and entries.is_empty() and int(attacker.get("current_hp")) == 20 and int(arena.get("round_number")) == round_before, "no opponent no-op", "must disable and mutate nothing")
	_free_arena(arena)


func _test_resolution_feedback() -> void:
	var arena := await _instantiate_arena()
	if arena != null and arena.has_method("perform_debug_damage"):
		arena.call("perform_debug_damage")
	var attacker: Variant = arena.call("get_unit_by_id", &"player_4") if arena != null and arena.has_method("get_unit_by_id") else null
	var receiver: Variant = _target_for_first_fixture(arena)
	_assert(_feedback_matches(arena, attacker, receiver, "-7"), "resolution feedback", "expected green attacker, red receiver, and -7")
	_free_arena(arena)


func _test_hover_feedback() -> void:
	var arena := await _arena_with_one_entry()
	if arena != null and arena.has_method("preview_log_entry"):
		arena.call("preview_log_entry", 0)
	var entries: Array = arena.call("get_battle_log_entries") if arena != null and arena.has_method("get_battle_log_entries") else []
	var entry: Variant = entries[0] if not entries.is_empty() else null
	var attacker: Variant = arena.call("get_unit_by_id", entry.get("attacker_id")) if arena != null and entry != null else null
	var receiver: Variant = arena.call("get_unit_by_id", entry.get("receiver_id")) if arena != null and entry != null else null
	_assert(_feedback_matches(arena, attacker, receiver, "-7"), "hover feedback", "historical entry must reproduce participants and damage")
	_free_arena(arena)


func _test_hover_exit_restores_current() -> void:
	var arena := await _arena_with_one_entry()
	if arena != null and arena.has_method("preview_log_entry"):
		arena.call("preview_log_entry", 0)
		arena.call("clear_log_entry_preview")
	await create_timer(0.9).timeout
	var current: Variant = arena.call("get_current_unit") if arena != null else null
	var slot := _slot_for(arena, current)
	_assert(slot != null and slot.get_meta("highlight_role", &"") == &"current", "hover exit restores current", "expected gold current-unit state")
	_free_arena(arena)


func _test_reconfigure_resets_battle_state() -> void:
	var arena := await _arena_with_one_entry()
	var units: Array = [_unit(&"solo", 0, 0)]
	_configure(arena, units)
	var entries: Array = arena.call("get_battle_log_entries") if arena != null and arena.has_method("get_battle_log_entries") else []
	var damage_labels_clear := true
	if arena != null:
		for slot: Control in (arena.call("get_player_slots") as Array[Control]) + (arena.call("get_enemy_slots") as Array[Control]):
			var label := slot.get_node_or_null("UnitInfo/DamageFeedbackLabel") as Label
			damage_labels_clear = damage_labels_clear and label != null and label.text.is_empty()
	_assert(entries.is_empty() and int(arena.get("round_number")) == 1 and damage_labels_clear, "reconfigure resets battle state", "expected clean Round 1 battle state")
	_free_arena(arena)


func _arena_with_one_entry() -> Control:
	var arena := await _instantiate_arena()
	if arena != null and arena.has_method("perform_debug_damage"):
		arena.call("perform_debug_damage")
	return arena


func _target_for_first_fixture(arena: Control) -> Variant:
	if arena == null or not arena.has_method("get_unit_by_id"):
		return null
	return arena.call("get_unit_by_id", &"enemy_1")


func _feedback_matches(arena: Control, attacker: Variant, receiver: Variant, damage_text: String) -> bool:
	var attacker_slot := _slot_for(arena, attacker)
	var receiver_slot := _slot_for(arena, receiver)
	var label := receiver_slot.get_node_or_null("UnitInfo/DamageFeedbackLabel") as Label if receiver_slot != null else null
	return attacker_slot != null and receiver_slot != null and attacker_slot.get_meta("highlight_role", &"") == &"attacker" and receiver_slot.get_meta("highlight_role", &"") == &"receiver" and label != null and label.text == damage_text


func _slot_for(arena: Control, unit: Variant) -> Control:
	if arena == null or unit == null:
		return null
	var slots: Array[Control] = arena.call("get_player_slots") if int(unit.get("side")) == 0 else arena.call("get_enemy_slots")
	for slot: Control in slots:
		if int(slot.get_meta("slot_index", -1)) == int(unit.get("slot_index")):
			return slot
	return null


func _free_arena(arena: Control) -> void:
	if is_instance_valid(arena):
		arena.queue_free()


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	if _failures.is_empty():
		print("AC2.3 damage and battle log tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return
	for failure: String in _failures:
		print("FAILED: %s" % failure)
