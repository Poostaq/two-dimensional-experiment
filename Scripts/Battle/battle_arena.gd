class_name BattleArena
extends Control

signal exit_requested
signal battle_completed(outcome: BattleOutcome.Type)
signal reward_confirmed(option: BattleRewardOption)

const SIDE_SLOT_COUNT := 6
const NEUTRAL_SLOT_COLOR := Color.WHITE
const CURRENT_SLOT_COLOR := Color(1.0, 0.82, 0.32, 1.0)
const ATTACKER_SLOT_COLOR := Color(0.35, 0.9, 0.5, 1.0)
const RECEIVER_SLOT_COLOR := Color(1.0, 0.35, 0.4, 1.0)
const FEEDBACK_DURATION_SECONDS := 0.8
const SELECTED_REWARD_COLOR := Color(1.0, 0.82, 0.32, 1.0)

@onready var _encounter_type_label: Label = %EncounterTypeLabel
@onready var _player_formation: GridContainer = %PlayerFormation
@onready var _enemy_formation: GridContainer = %EnemyFormation
@onready var _round_label: Label = %RoundLabel
@onready var _current_unit_label: Label = %CurrentUnitLabel
@onready var _advance_debug_button: Button = %AdvanceTurnDebugButton
@onready var _exit_debug_button: Button = %ExitBattleDebugButton
@onready var _battle_log_scroll: ScrollContainer = %BattleLogScroll
@onready var _battle_log_entries_container: VBoxContainer = %BattleLogEntries
@onready var _battle_result_panel: PanelContainer = %BattleResultPanel
@onready var _battle_result_label: Label = %BattleResultLabel
@onready var _reward_overlay: CenterContainer = %RewardOverlay
@onready var _reward_panel: PanelContainer = %RewardPanel
@onready var _reward_heading_label: Label = %RewardHeadingLabel
@onready var _reward_options_container: VBoxContainer = %RewardOptions
@onready var _reward_empty_state_label: Label = %RewardEmptyStateLabel
@onready var _reward_description_label: Label = %RewardDescriptionLabel
@onready var _confirm_reward_button: Button = %ConfirmRewardButton
@onready var _skill_inspector_prompt_label: Label = %SkillInspectorPromptLabel
@onready var _skill_inspector_header: HBoxContainer = %SkillInspectorHeader
@onready var _skill_inspector_unit_name_label: Label = %SkillInspectorUnitNameLabel
@onready var _skill_inspector_status_label: Label = %SkillInspectorStatusLabel
@onready var _skill_inspector_count_label: Label = %SkillInspectorCountLabel
@onready var _skill_inspector_skills: VBoxContainer = %SkillInspectorSkills
@onready var _skill_inspector_empty_label: Label = %SkillInspectorEmptyLabel

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""
var round_number: int = 1

var _units: Array[BattleUnitState] = []
var _turn_queue: Array[BattleUnitState] = []
var _current_turn_index: int = 0
var _battle_log_entries: Array[BattleLogEntry] = []
var _hovered_log_index: int = -1
var _feedback_generation: int = 0
var _transient_log_entry: BattleLogEntry
var _action_in_progress: bool = false
var _battle_outcome: BattleOutcome.Type = BattleOutcome.Type.IN_PROGRESS
var _reward_options: Array[BattleRewardOption] = []
var _selected_reward: BattleRewardOption
var _reward_confirmation_latched: bool = false
var _inspected_unit_id: StringName = &""


func _ready() -> void:
	var exit_callable := Callable(self, "_on_exit_debug_pressed")
	if not _exit_debug_button.pressed.is_connected(exit_callable):
		_exit_debug_button.pressed.connect(exit_callable)
	var advance_callable := Callable(self, "_on_advance_debug_pressed")
	if not _advance_debug_button.pressed.is_connected(advance_callable):
		_advance_debug_button.pressed.connect(advance_callable)
	var confirm_callable := Callable(self, "confirm_reward_selection")
	if not _confirm_reward_button.pressed.is_connected(confirm_callable):
		_confirm_reward_button.pressed.connect(confirm_callable)
	_clear_reward_ui()
	_assign_slot_metadata(_player_formation, "player")
	_assign_slot_metadata(_enemy_formation, "enemy")
	_refresh_context()
	configure_units(_create_debug_units())


func configure(coordinate: Vector2i, type: String) -> void:
	if type != HexMapModel.ENCOUNTER_COMBAT and type != HexMapModel.ENCOUNTER_BOSS:
		return
	encounter_coordinate = coordinate
	encounter_type = type
	if is_node_ready():
		_refresh_context()


func configure_units(units: Array[BattleUnitState]) -> void:
	_clear_reward_ui()
	_clear_skill_inspector()
	_feedback_generation += 1
	_action_in_progress = false
	_hovered_log_index = -1
	_transient_log_entry = null
	_battle_log_entries.clear()
	if is_node_ready():
		_clear_log_controls()
		_clear_all_damage_feedback()
	_battle_outcome = BattleOutcome.Type.IN_PROGRESS
	_units = units.duplicate()
	_turn_queue = BattleTurnQueue.build(_units)
	_current_turn_index = 0
	round_number = 1
	if is_node_ready():
		_refresh_turn_ui()


func get_turn_queue() -> Array[BattleUnitState]:
	return _turn_queue.duplicate()


func get_current_unit() -> BattleUnitState:
	if _turn_queue.is_empty() or _current_turn_index < 0 or _current_turn_index >= _turn_queue.size():
		return null
	return _turn_queue[_current_turn_index]


func get_battle_log_entries() -> Array[BattleLogEntry]:
	return _battle_log_entries.duplicate()


func get_battle_outcome() -> BattleOutcome.Type:
	return _battle_outcome


func is_battle_complete() -> bool:
	return _battle_outcome != BattleOutcome.Type.IN_PROGRESS


func get_reward_options() -> Array[BattleRewardOption]:
	return _reward_options.duplicate()


func get_selected_reward() -> BattleRewardOption:
	return _selected_reward


func select_reward(reward_id: StringName) -> void:
	if _reward_confirmation_latched or _battle_outcome != BattleOutcome.Type.VICTORY:
		return
	for option: BattleRewardOption in _reward_options:
		if option.reward_id == reward_id:
			_selected_reward = option
			_refresh_reward_selection_ui()
			return


func confirm_reward_selection() -> void:
	if (
		_reward_confirmation_latched
		or _battle_outcome != BattleOutcome.Type.VICTORY
		or not is_instance_valid(_selected_reward)
	):
		return
	_reward_confirmation_latched = true
	var confirmed_reward := _selected_reward
	_clear_reward_ui(false)
	reward_confirmed.emit(confirmed_reward)
	exit_requested.emit()


func get_inspected_unit_id() -> StringName:
	return _inspected_unit_id


func inspect_unit(unit_id: StringName) -> void:
	var unit := get_unit_by_id(unit_id)
	if not is_instance_valid(unit):
		_clear_skill_inspector()
		return
	_inspected_unit_id = unit.unit_id
	_refresh_skill_inspector()


func get_unit_by_id(unit_id: StringName) -> BattleUnitState:
	for unit: BattleUnitState in _units:
		if is_instance_valid(unit) and unit.unit_id == unit_id:
			return unit
	return null


func perform_debug_damage() -> void:
	if is_battle_complete() or _action_in_progress:
		return
	var attacker: BattleUnitState = get_current_unit()
	var receiver: BattleUnitState = BattleTargetSelector.find_closest_enemy(attacker, _units)
	if not is_instance_valid(attacker) or not is_instance_valid(receiver):
		_refresh_turn_ui()
		return
	_action_in_progress = true
	var action_round: int = round_number
	var result: BattleDamageResult = BattleDamageResolver.apply_damage(
		attacker,
		receiver,
		BattleDamageResolver.DEBUG_DAMAGE
	)
	if not is_instance_valid(result):
		_action_in_progress = false
		_refresh_turn_ui()
		return
	var entry := BattleLogEntry.new(
		_battle_log_entries.size() + 1,
		action_round,
		result
	)
	_battle_log_entries.append(entry)
	_append_log_control(entry, _battle_log_entries.size() - 1)
	_show_resolution_feedback(entry)
	var resolved_outcome := BattleOutcome.evaluate(_units)
	if resolved_outcome == BattleOutcome.Type.IN_PROGRESS:
		_advance_after_action(attacker.unit_id)
	else:
		_complete_battle(resolved_outcome)
	_action_in_progress = false
	_refresh_turn_ui()


func preview_log_entry(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= _battle_log_entries.size():
		return
	_hovered_log_index = entry_index
	_refresh_highlights()


func clear_log_entry_preview() -> void:
	_hovered_log_index = -1
	_refresh_highlights()


func advance_turn() -> void:
	if is_battle_complete() or _turn_queue.is_empty():
		return
	_current_turn_index += 1
	if _current_turn_index >= _turn_queue.size():
		round_number += 1
		_turn_queue = BattleTurnQueue.build(_units)
		_current_turn_index = 0
	_refresh_turn_ui()


func get_player_slots() -> Array[Control]:
	return _get_control_children(_player_formation)


func get_enemy_slots() -> Array[Control]:
	return _get_control_children(_enemy_formation)


func _create_debug_units() -> Array[BattleUnitState]:
	return [
		BattleUnitState.new(&"player_0", "Player Front 1", BattleUnitState.Side.PLAYER, 0, 8, 20, _skill_roster([CharacterSkill.new(&"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE), CharacterSkill.new(&"frontline_guard", "Frontline Guard", CharacterSkill.Kind.PASSIVE)])),
		BattleUnitState.new(&"player_1", "Player Front 2", BattleUnitState.Side.PLAYER, 1, 6),
		BattleUnitState.new(&"player_2", "Player Front 3", BattleUnitState.Side.PLAYER, 2, 6, 20, _skill_roster([CharacterSkill.new(&"quick_step", "Quick Step", CharacterSkill.Kind.ACTIVE)])),
		BattleUnitState.new(&"player_3", "Player Back 1", BattleUnitState.Side.PLAYER, 3, 4),
		BattleUnitState.new(&"player_4", "Player Back 2", BattleUnitState.Side.PLAYER, 4, 9, 20, _skill_roster([CharacterSkill.new(&"quick_strike", "Quick Strike", CharacterSkill.Kind.ACTIVE), CharacterSkill.new(&"rally", "Rally", CharacterSkill.Kind.ACTIVE), CharacterSkill.new(&"evasion", "Evasion", CharacterSkill.Kind.PASSIVE), CharacterSkill.new(&"momentum", "Momentum", CharacterSkill.Kind.PASSIVE)])),
		BattleUnitState.new(&"player_5", "Player Back 3", BattleUnitState.Side.PLAYER, 5, 2),
		BattleUnitState.new(&"enemy_0", "Enemy Front 1", BattleUnitState.Side.ENEMY, 0, 8, 20, _skill_roster([CharacterSkill.new(&"savage_blow", "Savage Blow", CharacterSkill.Kind.ACTIVE), CharacterSkill.new(&"blood_scent", "Blood Scent", CharacterSkill.Kind.PASSIVE)])),
		BattleUnitState.new(&"enemy_1", "Enemy Front 2", BattleUnitState.Side.ENEMY, 1, 7),
		BattleUnitState.new(&"enemy_2", "Enemy Front 3", BattleUnitState.Side.ENEMY, 2, 6, 20, _skill_roster([CharacterSkill.new(&"brace", "Brace", CharacterSkill.Kind.PASSIVE)])),
		BattleUnitState.new(&"enemy_3", "Enemy Back 1", BattleUnitState.Side.ENEMY, 3, 4),
		BattleUnitState.new(&"enemy_4", "Enemy Back 2", BattleUnitState.Side.ENEMY, 4, 9, 20, _skill_roster([CharacterSkill.new(&"shadow_lunge", "Shadow Lunge", CharacterSkill.Kind.ACTIVE)])),
		BattleUnitState.new(&"enemy_5", "Enemy Back 3", BattleUnitState.Side.ENEMY, 5, 2),
	]


func _skill_roster(values: Array) -> Array[CharacterSkill]:
	var roster: Array[CharacterSkill] = []
	for value: Variant in values:
		roster.append(value as CharacterSkill)
	return roster


func _complete_battle(outcome: BattleOutcome.Type) -> void:
	if is_battle_complete() or outcome == BattleOutcome.Type.IN_PROGRESS:
		return
	_battle_outcome = outcome
	_turn_queue.clear()
	_current_turn_index = 0
	battle_completed.emit(_battle_outcome)
	if _battle_outcome == BattleOutcome.Type.VICTORY:
		_show_victory_rewards()
	else:
		_clear_reward_ui()


func _show_victory_rewards() -> void:
	_clear_reward_ui()
	_reward_options = BattleRewardCatalog.get_options_for(encounter_type)
	_reward_overlay.visible = true
	_reward_panel.visible = true
	_reward_heading_label.text = "%s Rewards" % encounter_type.capitalize()
	_reward_empty_state_label.visible = _reward_options.is_empty()
	for option: BattleRewardOption in _reward_options:
		var button := Button.new()
		button.custom_minimum_size = Vector2(0.0, 48.0)
		button.text = option.title
		button.set_meta("reward_id", option.reward_id)
		button.pressed.connect(select_reward.bind(option.reward_id))
		_reward_options_container.add_child(button)


func _refresh_reward_selection_ui() -> void:
	if not is_instance_valid(_selected_reward):
		return
	for child: Node in _reward_options_container.get_children():
		var button := child as Button
		if button == null:
			continue
		var is_selected: bool = button.get_meta("reward_id", &"") == _selected_reward.reward_id
		button.self_modulate = SELECTED_REWARD_COLOR if is_selected else Color.WHITE
	_reward_description_label.text = _selected_reward.description
	_confirm_reward_button.disabled = false


func _clear_reward_ui(reset_latch: bool = true) -> void:
	if reset_latch:
		_reward_confirmation_latched = false
	_selected_reward = null
	_reward_options.clear()
	if not is_node_ready():
		return
	for child: Node in _reward_options_container.get_children():
		_reward_options_container.remove_child(child)
		child.queue_free()
	_reward_overlay.visible = false
	_reward_panel.visible = false
	_reward_heading_label.text = "Choose a reward"
	_reward_empty_state_label.visible = false
	_reward_description_label.text = ""
	_confirm_reward_button.disabled = true


func _advance_after_action(attacker_id: StringName) -> void:
	_turn_queue = BattleTurnQueue.build(_units)
	if _turn_queue.is_empty():
		_current_turn_index = 0
		return
	var attacker_index: int = -1
	for index: int in _turn_queue.size():
		if _turn_queue[index].unit_id == attacker_id:
			attacker_index = index
			break
	if attacker_index < 0:
		_current_turn_index = 0
		return
	_current_turn_index = attacker_index + 1
	if _current_turn_index >= _turn_queue.size():
		round_number += 1
		_current_turn_index = 0


func _get_control_children(formation: GridContainer) -> Array[Control]:
	var slots: Array[Control] = []
	for child: Node in formation.get_children():
		if child is Control:
			slots.append(child as Control)
	return slots


func _assign_slot_metadata(formation: GridContainer, side: String) -> void:
	for slot: Control in _get_control_children(formation):
		var slot_index := int(String(slot.name).trim_prefix("Slot"))
		slot.set_meta("side", side)
		slot.set_meta("slot_index", slot_index)
		slot.set_meta("is_current_unit", false)
		slot.set_meta("highlight_role", &"neutral")
		slot.set_meta("unit_id", &"")
		var input_callable := Callable(self, "_on_slot_gui_input").bind(slot)
		if not slot.gui_input.is_connected(input_callable):
			slot.gui_input.connect(input_callable)


func _on_slot_gui_input(event: InputEvent, slot: Control) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var unit_id := slot.get_meta("unit_id", &"") as StringName
	if unit_id.is_empty():
		return
	inspect_unit(unit_id)


func _refresh_context() -> void:
	if encounter_type.is_empty():
		_encounter_type_label.text = "Battle"
		return
	_encounter_type_label.text = "%s Battle" % encounter_type.capitalize()


func _refresh_turn_ui() -> void:
	_round_label.text = "Round %d" % round_number
	_render_units()
	_refresh_skill_inspector()
	_refresh_result_ui()
	if is_battle_complete():
		_current_unit_label.text = BattleOutcome.get_display_text(_battle_outcome)
		_advance_debug_button.disabled = true
		_refresh_highlights()
		return
	var current_unit := get_current_unit()
	if not is_instance_valid(current_unit):
		_current_unit_label.text = "No active units"
		_advance_debug_button.disabled = true
		_refresh_highlights()
		return
	_current_unit_label.text = "%s | Speed %d | HP %d/%d" % [
		current_unit.display_name,
		current_unit.speed,
		current_unit.current_hp,
		current_unit.max_hp,
	]
	var target := BattleTargetSelector.find_closest_enemy(current_unit, _units)
	_advance_debug_button.disabled = not is_instance_valid(target) or _action_in_progress
	_refresh_highlights()


func _refresh_result_ui() -> void:
	var complete := is_battle_complete()
	_battle_result_panel.visible = complete
	_battle_result_label.text = BattleOutcome.get_display_text(_battle_outcome)


func _render_units() -> void:
	for slot: Control in get_player_slots() + get_enemy_slots():
		var name_label := slot.get_node("UnitInfo/UnitNameLabel") as Label
		var speed_label := slot.get_node("UnitInfo/SpeedLabel") as Label
		var health_label := slot.get_node("UnitInfo/HealthLabel") as Label
		name_label.text = "Unoccupied"
		speed_label.text = "Speed —"
		health_label.text = "HP —"
		slot.set_meta("unit_id", &"")
	for unit: BattleUnitState in _units:
		if not is_instance_valid(unit):
			continue
		var slot := _get_slot_for_unit(unit)
		if not is_instance_valid(slot):
			continue
		slot.set_meta("unit_id", unit.unit_id)
		var name_label := slot.get_node("UnitInfo/UnitNameLabel") as Label
		var speed_label := slot.get_node("UnitInfo/SpeedLabel") as Label
		var health_label := slot.get_node("UnitInfo/HealthLabel") as Label
		name_label.text = unit.display_name
		speed_label.text = "Speed %d" % unit.speed
		health_label.text = (
			"HP %d/%d" % [unit.current_hp, unit.max_hp]
			if unit.is_active()
			else "Defeated — HP 0/%d" % unit.max_hp
		)


func _refresh_skill_inspector() -> void:
	var unit := get_unit_by_id(_inspected_unit_id)
	if not is_instance_valid(unit):
		_clear_skill_inspector()
		return
	_clear_skill_rows()
	_skill_inspector_prompt_label.visible = false
	_skill_inspector_header.visible = true
	_skill_inspector_unit_name_label.text = unit.display_name
	_skill_inspector_status_label.text = "Active" if unit.is_active() else "Defeated"
	_skill_inspector_count_label.text = "Skills: %d/%d" % [unit.skills.size(), BattleUnitState.MAX_CHARACTER_SKILLS]
	_skill_inspector_empty_label.visible = unit.skills.is_empty()
	for skill: CharacterSkill in unit.skills:
		var row := Label.new()
		row.text = "%s — %s" % [skill.display_name, "Active" if skill.kind == CharacterSkill.Kind.ACTIVE else "Passive"]
		_skill_inspector_skills.add_child(row)


func _clear_skill_inspector() -> void:
	_inspected_unit_id = &""
	if not is_node_ready():
		return
	_clear_skill_rows()
	_skill_inspector_prompt_label.visible = true
	_skill_inspector_header.visible = false
	_skill_inspector_unit_name_label.text = ""
	_skill_inspector_status_label.text = ""
	_skill_inspector_count_label.text = ""
	_skill_inspector_empty_label.visible = false


func _clear_skill_rows() -> void:
	for child: Node in _skill_inspector_skills.get_children():
		_skill_inspector_skills.remove_child(child)
		child.queue_free()


func _refresh_highlights() -> void:
	_reset_slot_highlights()
	if _hovered_log_index >= 0 and _hovered_log_index < _battle_log_entries.size():
		_apply_entry_feedback(_battle_log_entries[_hovered_log_index])
		return
	if is_instance_valid(_transient_log_entry):
		_apply_entry_feedback(_transient_log_entry)
		return
	if is_battle_complete():
		return
	var current_unit := get_current_unit()
	var current_slot := _get_slot_for_unit(current_unit)
	if is_instance_valid(current_slot):
		current_slot.self_modulate = CURRENT_SLOT_COLOR
		current_slot.set_meta("is_current_unit", true)
		current_slot.set_meta("highlight_role", &"current")


func _reset_slot_highlights() -> void:
	for slot: Control in get_player_slots() + get_enemy_slots():
		slot.self_modulate = NEUTRAL_SLOT_COLOR
		slot.set_meta("is_current_unit", false)
		slot.set_meta("highlight_role", &"neutral")
		var damage_label := slot.get_node("UnitInfo/DamageFeedbackLabel") as Label
		damage_label.text = ""


func _apply_entry_feedback(entry: BattleLogEntry) -> void:
	var attacker := get_unit_by_id(entry.attacker_id)
	var receiver := get_unit_by_id(entry.receiver_id)
	var attacker_slot := _get_slot_for_unit(attacker)
	var receiver_slot := _get_slot_for_unit(receiver)
	if is_instance_valid(attacker_slot):
		attacker_slot.self_modulate = ATTACKER_SLOT_COLOR
		attacker_slot.set_meta("highlight_role", &"attacker")
	if is_instance_valid(receiver_slot):
		receiver_slot.self_modulate = RECEIVER_SLOT_COLOR
		receiver_slot.set_meta("highlight_role", &"receiver")
		var damage_label := receiver_slot.get_node("UnitInfo/DamageFeedbackLabel") as Label
		damage_label.text = "-%d" % entry.applied_damage


func _show_resolution_feedback(entry: BattleLogEntry) -> void:
	_feedback_generation += 1
	_transient_log_entry = entry
	var generation: int = _feedback_generation
	_refresh_highlights()
	_expire_feedback(generation)


func _expire_feedback(generation: int) -> void:
	await get_tree().create_timer(FEEDBACK_DURATION_SECONDS).timeout
	if generation != _feedback_generation:
		return
	_transient_log_entry = null
	_refresh_highlights()


func _append_log_control(entry: BattleLogEntry, entry_index: int) -> void:
	var attacker := get_unit_by_id(entry.attacker_id)
	var receiver := get_unit_by_id(entry.receiver_id)
	if not is_instance_valid(attacker) or not is_instance_valid(receiver):
		return
	var row := Label.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.text = "R%d · %s dealt %d damage to %s · %d/%d HP%s" % [
		entry.round_number,
		attacker.display_name,
		entry.applied_damage,
		receiver.display_name,
		entry.receiver_hp_after,
		receiver.max_hp,
		" · Defeated" if entry.caused_defeat else "",
	]
	row.mouse_entered.connect(preview_log_entry.bind(entry_index))
	row.mouse_exited.connect(clear_log_entry_preview)
	_battle_log_entries_container.add_child(row)
	await get_tree().process_frame
	_battle_log_scroll.scroll_vertical = int(_battle_log_scroll.get_v_scroll_bar().max_value)


func _clear_log_controls() -> void:
	for child: Node in _battle_log_entries_container.get_children():
		child.queue_free()


func _clear_all_damage_feedback() -> void:
	for slot: Control in get_player_slots() + get_enemy_slots():
		var damage_label := slot.get_node("UnitInfo/DamageFeedbackLabel") as Label
		damage_label.text = ""


func _get_slot_for_unit(unit: BattleUnitState) -> Control:
	if not is_instance_valid(unit) or unit.slot_index < 0 or unit.slot_index >= SIDE_SLOT_COUNT:
		return null
	var slots: Array[Control] = get_player_slots() if unit.side == BattleUnitState.Side.PLAYER else get_enemy_slots()
	for slot: Control in slots:
		if int(slot.get_meta("slot_index", -1)) == unit.slot_index:
			return slot
	return null


func _on_advance_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	perform_debug_damage()


func _on_exit_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	_clear_reward_ui()
	call_deferred("_emit_exit_requested")


func _emit_exit_requested() -> void:
	exit_requested.emit()
