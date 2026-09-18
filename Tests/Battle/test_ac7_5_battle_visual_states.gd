class_name Ac7_5BattleVisualStatesTests
extends SceneTree

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _run() -> void:
	var path: String = "res://Scripts/UI/battle_visual_state.gd"
	_assert(ResourceLoader.exists(path), "pure visual resolver exists")
	if ResourceLoader.exists(path):
		_test_resolver(load(path))
	var arena := (load("res://Scenes/battle_arena.tscn") as PackedScene).instantiate() as BattleArena
	root.add_child(arena)
	arena.call("configure_units", load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	await process_frame
	if arena.has_method("_evaluate_visual_skill"):
		await _test_observational_preview(arena)
		await _test_availability(arena)
		await _test_authored_and_focus(arena)
		await _test_lifecycle(arena)
	else:
		_assert(false, "detached visual adapter exists")
	arena.queue_free()
	await process_frame
	for failure: String in _failures:
		print("FAILED: " + failure)
	if _failures.is_empty():
		print("AC7.5 battle visual states: PASS")
	quit(0 if _failures.is_empty() else 1)

func _test_resolver(resolver: Script) -> void:
	var value: RefCounted = resolver.Request.new()
	var result: RefCounted = resolver.resolve(value)
	_assert(not result.actor_frame and result.target_border == &"", "empty slot is neutral")
	value.occupied = true
	value.active = true
	value.current_actor = true
	value.ribbon_preview = true
	result = resolver.resolve(value)
	_assert(result.actor_frame and result.interaction_spotlight, "actor and ribbon coexist")
	value.hover_target = true
	result = resolver.resolve(value)
	_assert(result.target_border == &"preview" and not result.selection_marker, "hover is preview only")
	value.action_committed = true
	result = resolver.resolve(value)
	_assert(result.target_border == &"", "committed action suppresses unrelated hover")
	value.valid_target = true
	for kind: StringName in [&"skill", &"attack", &"swap"]:
		value.action_kind = kind
		value.selected_target = false
		result = resolver.resolve(value)
		_assert(result.target_border == &"valid" and result.target_glyph == kind, "valid action identity")
		value.selected_target = true
		result = resolver.resolve(value)
		_assert(result.actor_frame and result.selection_marker and result.target_glyph == kind, "self selected keeps actor and action identity")
	value.valid_target = false
	result = resolver.resolve(value)
	_assert(not result.selection_marker, "invalidated target cannot remain selected")
	value.valid_target = true
	value.unavailable_reason = "Out of range"
	result = resolver.resolve(value)
	_assert(result.target_border == &"" and result.availability_treatment == &"unavailable", "unavailable suppresses affordances")
	value.active = false
	result = resolver.resolve(value)
	_assert(not result.actor_frame and not result.interaction_spotlight and not result.selection_marker, "defeat suppresses transient/action layers")
	value.active = true
	value.unavailable_reason = ""
	result = resolver.resolve(value)
	result.target_glyph = &"changed"
	_assert(resolver.resolve(value).target_glyph == &"swap", "fresh deterministic result")
	_assert(value.selected_target and value.current_actor, "resolver does not mutate inputs")

func _test_observational_preview(arena: BattleArena) -> void:
	var bar := arena.get_node("%BattleActionBar") as Control
	var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
	var button := rows.get_child(0) as Button
	var snapshot: Dictionary = arena.get_skill_presentation_snapshot()
	var revision: int = arena.get_battle_revision()
	button.mouse_entered.emit()
	_assert(arena.get_skill_presentation_snapshot() == snapshot, "hover cannot mutate transaction")
	_assert(arena.get_battle_revision() == revision, "hover cannot change revision")
	var target := arena.get_enemy_slots()[0] as Control
	_assert(target.get_meta("visual_target_border", &"") == &"preview", "hover previews legal enemy")
	button.mouse_exited.emit()
	_assert(target.get_meta("visual_target_border", &"") == &"", "hover exit clears targets")
	button.pressed.emit()
	arena.select_skill_target(&"enemy_0")
	var locked: Dictionary = arena.get_skill_presentation_snapshot()
	(rows.get_child(1) as Button).mouse_entered.emit()
	_assert(arena.get_skill_presentation_snapshot() == locked, "other skill hover preserves committed state")
	_assert(target.get_meta("visual_selected", false), "selected target retains marker")
	(rows.get_child(1) as Button).mouse_exited.emit()
	(bar.get_node("%CancelButton") as Button).pressed.emit()
	_assert(not target.get_meta("visual_selected", false), "cancel clears selection")
	(bar.get_node("%DefaultAttackButton") as Button).pressed.emit()
	_assert(target.get_meta("visual_target_glyph", &"") == &"attack", "Attack has distinct target glyph")
	arena.call("_select_default_action_target", &"enemy_0", 0)
	_assert(target.get_meta("visual_selected", false), "default target selected")
	(bar.get_node("%DefaultSwapButton") as Button).pressed.emit()
	var ally := arena.get_player_slots()[1] as Control
	_assert(ally.get_meta("visual_target_glyph", &"") == &"swap", "Swap has distinct target glyph")
	_assert(target.get_meta("visual_target_border", &"") == &"", "Swap clears Attack target")
	arena.advance_turn()
	_assert(not ally.get_meta("visual_selected", false) and ally.get_meta("visual_target_border", &"") == &"", "turn clears target layers")

func _test_availability(arena: BattleArena) -> void:
	var skill: CharacterSkill = load("res://Tests/Battle/legacy_debug_fixture.gd").call("_create_skill", &"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE, "Damage.", "Enemy.", "Front.", "None.")
	var actor := BattleUnitState.new(&"actor", "Actor", 0, 0, 10, 20, [skill])
	var ally := BattleUnitState.new(&"ally", "Ally", 0, 3, 5)
	arena.configure_units([actor, ally])
	var bar := arena.get_node("%BattleActionBar") as Control
	var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
	var button := rows.get_child(0) as Button
	var attack := bar.get_node("%DefaultAttackButton") as Button
	_assert(button.get_meta("no_legal_completion", false), "FREE action with no legal target marked")
	_assert((button.get_node("AvailabilityLabel") as Label).text.contains("NO TARGET"), "no target has non-color marker")
	var before: Dictionary = arena.get_skill_presentation_snapshot()
	button.grab_focus()
	await process_frame
	_assert(button.has_focus(), "unavailable skill remains focusable")
	button.pressed.emit()
	_assert(arena.get_skill_presentation_snapshot() == before and arena.get_selected_skill_id() == &"", "unavailable skill activation guarded")
	attack.grab_focus()
	await process_frame
	_assert(attack.has_focus(), "unavailable default remains focusable")
	_assert(attack.tooltip_text.contains("No legal"), "unavailable default exposes reason")
	attack.pressed.emit()
	_assert(int(arena.get("_default_action_mode")) == 0, "no-target Attack cannot activate")
	var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 4)
	arena.configure_units([actor, ally, enemy])
	actor.set_skill_cooldown(skill.skill_id, 2)
	arena.notify_authoritative_battle_change()
	button = rows.get_child(0) as Button
	_assert(not button.get_meta("can_activate", true) and button.accessibility_name.contains("2"), "cooldown reason has priority")
	actor.set_skill_cooldown(skill.skill_id, 0)
	arena.configure_units([actor, ally, enemy])
	button = rows.get_child(0) as Button
	button.mouse_entered.emit()
	button.grab_focus()
	await process_frame
	button.mouse_exited.emit()
	_assert(arena.get_enemy_slots()[0].get_meta("visual_target_border") == &"preview", "focus resumes when pointer exits")
	button.release_focus()
	await process_frame
	_assert(arena.get_enemy_slots()[0].get_meta("visual_target_border") == &"", "last source exit clears")
	button.mouse_entered.emit()
	var drawer := arena.get_node("%BattleDebugDrawer") as Control
	drawer.set_open(true)
	_assert(arena.get_enemy_slots()[0].get_meta("visual_target_border") == &"", "drawer clears obscured hover")
	drawer.set_open(false)
	(bar.get_node("%DefaultAttackButton") as Button).pressed.emit()
	arena.call("_select_default_action_target", &"enemy", 0)
	enemy.current_hp = 0
	arena.notify_authoritative_battle_change()
	_assert(not arena.get_enemy_slots()[0].get_meta("visual_selected"), "defeat removes selected marker")
	_assert(arena.get_enemy_slots()[0].get_meta("visual_reason") == "Defeated", "defeat reason retained")

func _test_authored_and_focus(arena: BattleArena) -> void:
	var definition := RunCharacterCatalog.create_by_class_id(&"wirefang_skirmisher")
	var actor := BattleUnitState.new(&"actor", "Actor", 0, 0, 10, 20, definition.get_skills())
	var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 1)
	arena.configure_units([actor, enemy])
	var bar := arena.get_node("%BattleActionBar") as Control
	var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
	var slipstep := rows.get_child(2) as Button
	var actor_slot := arena.get_player_slots()[0] as Control
	_assert(slipstep.get_meta("can_activate") and not slipstep.get_meta("no_legal_completion"), "zero explicit target remains usable")
	var before: Dictionary = arena.get_skill_presentation_snapshot()
	var armor: int = actor.get_armor()
	var revision: int = arena.get_battle_revision()
	slipstep.mouse_entered.emit()
	_assert(actor_slot.get_meta("visual_target_border") == &"preview", "zero target previews affected actor")
	_assert(arena.get_skill_presentation_snapshot() == before and actor.get_armor() == armor and arena.get_battle_revision() == revision, "self preview remains observational")
	slipstep.pressed.emit()
	_assert(actor_slot.get_meta("visual_target_border") == &"valid" and not actor_slot.get_meta("visual_selected"), "affected self is not fabricated explicit selection")
	_assert((arena.get("_skill_transaction") as BattleSkillTransaction).locked_target_ids.is_empty(), "zero target keeps empty transaction IDs")
	(bar.get_node("%CancelButton") as Button).pressed.emit()
	actor_slot.grab_focus()
	await process_frame
	_assert((actor_slot.get_node("VisualStateOverlay/StateBadge") as Label).text.contains("FOCUS"), "idle card has visible focus")
	_assert(arena.get_player_slots()[2].focus_mode == Control.FOCUS_NONE, "empty card excluded from traversal")
	var mob := RunCharacterCatalog.create_by_class_id(&"mobcaller")
	actor = BattleUnitState.new(&"mob", "Mob", 0, 0, 10, 20, mob.get_skills(), 4, 0, &"goblin")
	var ally := BattleUnitState.new(&"ally", "Ally", 0, 1, 5, 20, [], 4, 0, &"harpy")
	arena.configure_units([actor, ally])
	var mixed := rows.get_child(2) as Button
	_assert(mixed.get_meta("no_legal_completion"), "mixed side requires missing enemy stage")
	arena.configure_units([actor, ally, enemy])
	mixed = rows.get_child(2) as Button
	_assert(mixed.get_meta("can_activate"), "mixed side complete selection remains legal")
	arena.advance_turn()
	mixed = rows.get_child(2) as Button if rows.get_child_count() > 2 else null
	arena.configure_units([actor, ally, enemy])
	actor.current_hp = 0
	arena.notify_authoritative_battle_change()
	arena.inspect_unit(actor.unit_id)
	await process_frame
	if rows.get_child_count() > 0:
		var unavailable := rows.get_child(0) as Button
		unavailable.mouse_entered.emit()
		_assert((bar.get_node("%SkillTooltipPanel") as Control).visible, "defeated skill explanation remains inspectable")

func _observed_state(arena: BattleArena) -> Dictionary:
	var units: Array[Dictionary] = []
	for unit: BattleUnitState in arena.get("_units"):
		units.append({"id": unit.unit_id, "hp": unit.current_hp, "slot": unit.slot_index,
			"cooldowns": unit.get_skill_cooldown_snapshot(), "armor": unit.get_armor(),
			"speed": unit.get_effective_speed()})
	var queue: Array[StringName] = []
	for unit: BattleUnitState in arena.get_turn_queue():
		queue.append(unit.unit_id)
	return {"units": units, "queue": queue, "actor": arena.get_current_unit().unit_id,
		"round": arena.round_number, "revision": arena.get_battle_revision(),
		"records": arena.get_action_records(), "history": arena.get_committed_action_history_snapshot(),
		"skill": arena.get_selected_skill_id(), "default": (arena.get("_default_action_preview") as Dictionary).duplicate(true),
		"transaction": arena.get_skill_presentation_snapshot()}

func _test_lifecycle(arena: BattleArena) -> void:
	arena.configure_units(load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	var bar := arena.get_node("%BattleActionBar") as Control
	var rows := bar.get_node("%SkillInspectorSkills") as HBoxContainer
	var first := rows.get_child(0) as Button
	var second := rows.get_child(1) as Button
	var before: Dictionary = _observed_state(arena)
	first.grab_focus()
	first.mouse_entered.emit()
	second.mouse_entered.emit()
	first.mouse_exited.emit()
	_assert(arena.get("_visual_hover_skill") == second.get_meta("skill_id"), "late A exit cannot erase B")
	first.release_focus()
	_assert(arena.get("_visual_hover_skill") == second.get_meta("skill_id"), "pointer survives focus exit")
	for iteration: int in 3:
		arena.call("_refresh_action_bar")
	_assert(_observed_state(arena) == before, "all observation preserves HP cooldown queue round revision history transaction")
	second.mouse_exited.emit()
	_assert(arena.get("_visual_hover_skill") == &"", "both sources leave")
	first.pressed.emit()
	arena.select_skill_target(&"enemy_0")
	arena.call("_on_turn_order_preview_changed", &"enemy_0")
	var target := arena.get_enemy_slots()[0] as Control
	_assert(target.get_meta("visual_selected") and (target.get_node("TurnOrderPreviewOverlay") as Control).visible, "ribbon spotlight coexists with selection")
	(bar.get_node("%CancelButton") as Button).pressed.emit()
	_assert(not target.get_meta("visual_selected"), "cancel clears selected")
	first.grab_focus()
	first.mouse_entered.emit()
	first.pressed.emit()
	arena.select_skill_target(&"enemy_0")
	_assert(arena.confirm_skill_action(), "selected action confirms")
	await process_frame
	_assert(arena.get("_visual_hover_skill") == &"" and not target.get_meta("visual_selected"), "confirmation clears hover and selected")
	arena.configure_units(load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	first = rows.get_child(0) as Button
	first.mouse_entered.emit()
	var actor: BattleUnitState = arena.get_current_unit()
	actor.set_skill_cooldown(first.get_meta("skill_id"), 2)
	arena.notify_authoritative_battle_change()
	_assert(target.get_meta("visual_target_border") == &"", "cooldown removes now-illegal hover")
	arena.configure_units(load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	first = rows.get_child(0) as Button
	first.pressed.emit()
	arena.select_skill_target(&"enemy_0")
	arena.remove_battle_unit(&"enemy_0")
	_assert(not target.get_meta("visual_selected") and target.get_meta("visual_target_border") == &"", "removal clears old target slot")
	arena.configure_units(load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	first = rows.get_child(0) as Button
	first.mouse_entered.emit()
	arena.configure_units(load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	await process_frame
	_assert(arena.get("_visual_hover_skill") == &"" and not (bar.get_node("%SkillTooltipPanel") as Control).visible, "identical ID reset invalidates deferred tooltip")
	arena.configure(Vector2i.ZERO, WorldEncounterType.COMBAT)
	var identity: RefCounted = arena.get_setup_identity()
	var record: RefCounted = load("res://Scripts/Battle/battle_preparation_record.gd").offered(&"visual_prep", Vector2i.ZERO, WorldEncounterType.COMBAT, String(identity.get("canonical_key")))
	_assert(arena.configure_preparation(record), "preparation fixture accepted")
	_assert(arena.get("_visual_hover_skill") == &"", "preparation clears hover")
	for slot: Control in arena.get_player_slots() + arena.get_enemy_slots():
		_assert(not slot.get_meta("visual_selected") and not slot.get_meta("visual_actor_frame"), "preparation clears active combat layers")

	var terminal_definition := RunCharacterCatalog.create_by_class_id(&"wirefang_skirmisher")
	var terminal_player := BattleUnitState.new(&"terminal_player", "Terminal", 0, 0, 10, 20, terminal_definition.get_skills())
	var terminal_enemy := BattleUnitState.new(&"terminal_enemy", "Enemy", 1, 0, 1)
	arena.configure_units([terminal_player, terminal_enemy])
	var terminal_actor: StringName = arena.get_current_unit().unit_id
	for enemy: BattleUnitState in (arena.get("_units") as Array):
		if enemy.side == BattleUnitState.Side.ENEMY:
			enemy.current_hp = 1
	arena.perform_debug_damage()
	await create_timer(0.6).timeout
	arena.perform_debug_damage()
	await create_timer(0.6).timeout
	_assert(arena.is_battle_complete(), "terminal fixture completes")
	_assert(rows.get_child_count() > 0 and arena.get_inspected_unit_id() == terminal_actor, "completion retains read-only explanations")
	if rows.get_child_count() > 0:
		first = rows.get_child(0) as Button
		first.mouse_entered.emit()
		_assert((bar.get_node("%SkillTooltipPanel") as Control).visible and not first.get_meta("can_activate"), "completed skill exposes blocked explanation")
		var terminal_revision: int = arena.get_battle_revision()
		first.pressed.emit()
		_assert(arena.get_selected_skill_id() == &"" and arena.get_battle_revision() == terminal_revision, "completed detail cannot activate")

	arena.configure_units(load("res://Tests/Battle/legacy_debug_fixture.gd").create_units())
	(bar.get_node("%DefaultAttackButton") as Button).pressed.emit()
	arena.call("_select_default_action_target", &"enemy_0", 0)
	arena.call("_on_exit_debug_pressed")
	await process_frame
	_assert(int(arena.get("_default_action_mode")) == 0 and arena.get("_visual_hover_skill") == &"" and arena.get_selected_skill_id() == &"", "exit clears all action presentation")
	_assert(not arena.get_enemy_slots()[0].get_meta("visual_selected"), "exit clears selected target layer")
