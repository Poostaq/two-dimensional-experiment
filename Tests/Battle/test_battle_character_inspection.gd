class_name BattleCharacterInspectionTests
extends SceneTree

var failures: Array[String] = []

class ObservedArena extends BattleArena:
	var mid_action: Dictionary = {}
	var inspect_during_action: bool = false
	func _show_resolution_feedback(entry: BattleLogEntry) -> void:
		super._show_resolution_feedback(entry)
		if inspect_during_action:
			open_character_info(&"enemy")
			mid_action = get_character_info_snapshot()


func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	if not value:
		failures.append(label)

func _run() -> void:
	var arena: Control = load("res://Scenes/battle_arena.tscn").instantiate()
	arena.set_script(ObservedArena)
	root.add_child(arena)
	await process_frame
	check(arena.has_method("open_character_info"), "character inspection API exists")
	if arena.has_method("open_character_info"):
		await _exercise(arena)
		await _real_action_and_input(arena)
	arena.queue_free()
	await process_frame
	for failure: String in failures:
		print("FAILED: " + failure)
	if failures.is_empty():
		print("AC7.6 character inspection: PASS")
	quit(0 if failures.is_empty() else 1)

func _exercise(arena: Control) -> void:
	var actor := BattleUnitState.new(&"actor", "Actor", 0, 0, 10, 30)
	var ally := BattleUnitState.new(&"ally", "Ally", 0, 3, 8, 30)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 5, 50)
	var units: Array[BattleUnitState] = [actor, ally, enemy]
	arena.call("configure_units", units)
	check(arena.call("open_character_info", &"enemy"), "enemy inspection opens")
	var first: Dictionary = arena.call("get_character_info_snapshot")
	check(first["unit"]["current_hp"] == 50, "initial committed HP")
	var revision: int = first["committed_revision"]
	first["unit"]["current_hp"] = -1
	check(arena.call("get_character_info_snapshot")["unit"]["current_hp"] == 50, "snapshot defensive copy")
	arena.call("_on_default_attack_pressed")
	var mode: int = arena.get("_default_action_mode")
	arena.call("open_character_info", &"ally")
	check(int(arena.get("_default_action_mode")) == mode and arena.call("get_current_unit") == actor, "inspection preserves action and actor")
	arena.set("_action_in_progress", true)
	enemy.current_hp = 17
	arena.call("notify_authoritative_battle_change")
	arena.call("open_character_info", &"enemy")
	var pending: Dictionary = arena.call("get_character_info_snapshot")
	check(pending["unit"]["current_hp"] == 50 and pending["resolution_in_progress"], "mid-action newly inspected unit uses old cache")
	check(pending["committed_revision"] == revision, "no mid-action publication")
	arena.set("_action_in_progress", false)
	arena.call("notify_authoritative_battle_change")
	var committed: Dictionary = arena.call("get_character_info_snapshot")
	check(committed["unit"]["current_hp"] == 17 and committed["committed_revision"] == revision + 1, "atomic commit refresh")
	var drawer: Control = arena.get_node("%BattleDebugDrawer")
	drawer.call("set_open", true)
	arena.call("open_character_info", &"ally")
	await process_frame
	_key(KEY_ESCAPE)
	await process_frame
	check(arena.call("get_character_info_snapshot").is_empty() and drawer.call("is_open"), "first Escape information only")
	_key(KEY_ESCAPE)
	await process_frame
	check(not drawer.call("is_open") and int(arena.get("_default_action_mode")) == mode, "second Escape drawer only")
	_key(KEY_ESCAPE)
	await process_frame
	check(int(arena.get("_default_action_mode")) == 0, "third Escape action only")
	arena.call("open_character_info", &"enemy")
	var epoch: int = arena.call("get_character_info_snapshot")["battle_epoch"]
	arena.call("configure_units", units)
	check(arena.call("get_character_info_snapshot").is_empty(), "reset closes")
	arena.call("open_character_info", &"enemy")
	check(arena.call("get_character_info_snapshot")["battle_epoch"] > epoch, "same ID reset changes epoch")
	arena.call("remove_battle_unit", &"enemy")
	check(arena.call("get_character_info_snapshot").is_empty(), "removal closes")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event)
	event = InputEventKey.new()
	event.keycode = code
	event.pressed = false
	root.push_input(event)

func _real_action_and_input(arena: Control) -> void:
	root.content_scale_size = Vector2i(1152, 648)
	root.size = Vector2i(1152, 648)
	var skill: CharacterSkill = arena.call("_create_skill", &"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE, "Deal 7 damage.", "One enemy.", "Front row.", "1 action.")
	var actor := BattleUnitState.new(&"actor", "Actor", 0, 0, 10, 30, [skill])
	var ally := BattleUnitState.new(&"ally", "Ally", 0, 3, 8, 30)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", 1, 0, 5, 50)
	var units: Array[BattleUnitState] = [actor, ally, enemy]
	arena.call("configure_units", units)
	await _settle()
	arena.call("open_character_info", &"ally")
	var previous: Dictionary = arena.call("get_character_info_snapshot")
	arena.set("inspect_during_action", true)
	var accepted: bool = arena.call("confirm_default_attack", &"actor", &"enemy", arena.call("get_battle_revision"))
	check(accepted, "real attack commits")
	var mid: Dictionary = arena.get("mid_action")
	check(not mid.is_empty() and mid["unit"]["current_hp"] == 50 and mid["resolution_in_progress"], "damage callback sees pre-action all-unit cache")
	var final: Dictionary = arena.call("get_character_info_snapshot")
	check(final["unit"]["current_hp"] == enemy.current_hp and final["committed_revision"] == previous["committed_revision"] + 1, "real attack publishes once after advancement")
	check(final["current_actor_id"] == arena.call("get_current_unit").unit_id, "snapshot includes advanced actor")
	arena.set("inspect_during_action", false)
	var stable_revision: int = final["committed_revision"]
	check(not arena.call("confirm_default_attack", &"actor", &"enemy", -1), "stale action rejected")
	check(arena.call("get_character_info_snapshot")["committed_revision"] == stable_revision, "rejected action does not publish")
	arena.call("configure_units", units)
	await _settle()
	check(arena.call("preview_skill_action", &"actor", &"shield_bash"), "preview fixture accepted")
	arena.call("open_character_info", &"enemy")
	check(arena.call("get_skill_transaction_state") != BattleSkillTransaction.State.PREVIEWING, "opening clears transient skill transaction preview")
	arena.call("close_character_info", false)
	var slot: Control = arena.call("get_enemy_slots")[0]
	await _click(slot, MOUSE_BUTTON_RIGHT)
	check(arena.call("get_character_info_snapshot").get("requested_unit_id") == &"enemy", "real right-click opens enemy")
	var panel: Control = arena.get_node("%BattleCharacterInfoPanel")
	var bar: Control = arena.get_node("%BattleActionBar")
	var drawer: Control = arena.get_node("%BattleDebugDrawer")
	arena.call("close_character_info", false)
	var button: Control = (bar.get_node("%SkillInspectorSkills") as HBoxContainer).get_child(0)
	button.grab_focus()
	await _settle()
	_key(KEY_I)
	await _settle()
	check(arena.call("get_character_info_snapshot").is_empty(), "Inspect on action bar does nothing")
	slot.grab_focus()
	_key(KEY_I)
	await _settle()
	check(panel.visible and (panel.get_node("%InfoClose") as Button).has_focus(), "Inspect on character focuses panel")
	var covered_slot: Control = arena.call("get_player_slots")[3]
	check(covered_slot.focus_mode == Control.FOCUS_NONE, "covered slot excluded from focus traversal")
	var left_panel: bool = false
	for tab: int in 12:
		_key(KEY_TAB)
		await _settle()
		var focused: Control = root.gui_get_focus_owner()
		if is_instance_valid(focused) and not panel.is_ancestor_of(focused):
			left_panel = true
			break
	check(left_panel, "dispatched Tab can leave nonmodal information panel")
	slot.grab_focus()
	arena.call("close_character_info")
	check(slot.has_focus(), "close does not steal externally moved focus")
	arena.call("begin_skill_action", &"actor", &"shield_bash")
	arena.call("select_skill_target", &"enemy")
	var transaction: Dictionary = arena.call("get_skill_presentation_snapshot")
	await _click(slot, MOUSE_BUTTON_RIGHT)
	check(arena.call("get_skill_presentation_snapshot") == transaction, "right-click preserves skill target")
	await _click(panel.get_node("%Statistics"), MOUSE_BUTTON_RIGHT)
	check(arena.call("get_character_info_snapshot").get("requested_unit_id") == &"enemy", "panel right-click does not leak")
	await _click(arena.call("get_player_slots")[0], MOUSE_BUTTON_RIGHT)
	check(arena.call("get_character_info_snapshot").get("requested_unit_id") == &"actor", "visible part of partially covered unit remains inspectable")
	await _click(slot, MOUSE_BUTTON_RIGHT)
	var stale: Dictionary = arena.call("get_character_info_snapshot")
	arena.call("open_character_info", &"ally")
	arena.call("_render_character_info", stale, [stale["battle_epoch"],stale["committed_revision"],stale["inspection_generation"],stale["requested_unit_id"]])
	check((panel.get_node("%CharacterName") as Label).text == "Ally", "obsolete deferred unit render rejected")
	# A saved debug control can become hidden before information closes.
	arena.call("close_character_info", false)
	drawer.call("set_open", true)
	(drawer.get_node("%CloseButton") as Button).grab_focus()
	arena.call("open_character_info", &"enemy", true)
	drawer.call("set_open", false, false)
	arena.call("close_character_info")
	var fallback: Control = root.gui_get_focus_owner()
	check(is_instance_valid(fallback) and fallback.is_visible_in_tree() and not drawer.is_ancestor_of(fallback), "hidden saved drawer focus falls back to battle")
	for swap: bool in [false, true]:
		for info_first: bool in [false, true]:
			arena.call("configure_units", units)
			arena.call("_on_default_swap_pressed" if swap else "_on_default_attack_pressed")
			var mode: int = arena.get("_default_action_mode")
			await _settle()
			var geometry: Rect2 = bar.get_global_rect()
			if info_first:
				arena.call("open_character_info", &"enemy", true)
				drawer.call("set_open", true)
			else:
				drawer.call("set_open", true)
				arena.call("open_character_info", &"enemy", true)
			await _settle()
			check(bar.get_global_rect() == geometry, "two panels do not reflow")
			_key(KEY_ESCAPE)
			await _settle()
			check(not panel.visible and drawer.call("is_open") and int(arena.get("_default_action_mode")) == mode, "overlap Escape 1 preserves drawer/action")
			_key(KEY_ESCAPE)
			await _settle()
			check(not drawer.call("is_open") and int(arena.get("_default_action_mode")) == mode, "overlap Escape 2 preserves action")
			_key(KEY_ESCAPE)
			await _settle()
			check(int(arena.get("_default_action_mode")) == 0, "overlap Escape 3 cancels")
	arena.call("configure_units", units)
	arena.call("open_character_info", &"enemy", true)
	var epoch_snapshot: Dictionary = arena.call("get_character_info_snapshot")
	drawer.call("set_open", true)
	arena.call("_complete_battle", BattleOutcome.Type.VICTORY)
	await _settle()
	check(not panel.visible and not drawer.call("is_open"), "results owns both overlays")
	check(not arena.call("open_character_info", &"enemy"), "results blocks reopening")
	arena.call("_render_character_info", epoch_snapshot, [epoch_snapshot["battle_epoch"],epoch_snapshot["committed_revision"],epoch_snapshot["inspection_generation"],epoch_snapshot["requested_unit_id"]])
	check(not panel.visible, "results blocks stale rendering")
	arena.call("configure_units", units)
	arena.call("configure", Vector2i.ZERO, WorldEncounterType.COMBAT)
	var identity: RefCounted = arena.call("get_setup_identity")
	var prep: RefCounted = load("res://Scripts/Battle/battle_preparation_record.gd").offered(&"info_prep", Vector2i.ZERO, WorldEncounterType.COMBAT, String(identity.get("canonical_key")))
	arena.call("open_character_info", &"enemy")
	drawer.call("set_open", true)
	check(arena.call("configure_preparation", prep), "preparation accepted")
	check(not panel.visible and not drawer.call("is_open") and not arena.call("open_character_info", &"enemy"), "preparation modal excludes both overlays")
	arena.call("configure_units", units)
	enemy.current_hp = 1
	arena.call("open_character_info", &"enemy", true)
	drawer.call("set_open", true)
	arena.call("perform_debug_damage")
	await _settle()
	check(arena.call("is_battle_complete") and not panel.visible and not drawer.call("is_open"), "real victory closes both panels")
	var rewards: Array = arena.call("get_reward_options")
	check(not rewards.is_empty(), "reward fixture available")
	if not rewards.is_empty():
		var reward: BattleRewardOption = rewards[0]
		arena.call("select_reward", reward.reward_id)
		arena.call("confirm_reward_selection")
		await _settle()
		check(not arena.call("open_character_info", &"actor") and not panel.visible, "recruitment placement blocks inspection")
		drawer.call("set_open", true)
		check(not drawer.call("is_open"), "recruitment placement blocks drawer")
		arena.call("restore_pending_recruitment", reward)
		await _settle()
		check(not panel.visible and not arena.call("open_character_info", &"enemy"), "recruitment cancellation retains modal ownership")

func _settle() -> void:
	for frame: int in 4:
		await process_frame

func _click(control: Control, mouse_button: MouseButton) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	root.push_input(move)
	await _settle()
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = mouse_button
		event.pressed = pressed
		root.push_input(event)
		await process_frame
	await _settle()
