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
const SKILL_BUTTON_SIZE := Vector2(88.0, 88.0)
const SELECTED_SKILL_COLOR := Color(1.0, 0.82, 0.32, 1.0)
const SKILL_TOOLTIP_VIEWPORT_MARGIN: float = 12.0
const SKILL_TOOLTIP_ANCHOR_GAP: float = 8.0

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
@onready var _skill_inspector_body: HBoxContainer = %SkillInspectorBody
@onready var _skill_inspector_unit_name_label: Label = %SkillInspectorUnitNameLabel
@onready var _skill_inspector_status_label: Label = %SkillInspectorStatusLabel
@onready var _skill_inspector_count_label: Label = %SkillInspectorCountLabel
@onready var _skill_inspector_skills: HBoxContainer = %SkillInspectorSkills
@onready var _skill_inspector_empty_label: Label = %SkillInspectorEmptyLabel
@onready var _skill_tooltip_panel: PanelContainer = %SkillTooltipPanel
@onready var _skill_tooltip_name_label: Label = %SkillTooltipNameLabel
@onready var _skill_tooltip_kind_label: Label = %SkillTooltipKindLabel
@onready var _skill_tooltip_effect_label: Label = %SkillTooltipEffectLabel
@onready var _skill_tooltip_targeting_label: Label = %SkillTooltipTargetingLabel
@onready var _skill_tooltip_requirements_label: Label = %SkillTooltipRequirementsLabel
@onready var _skill_tooltip_cooldown_label: Label = %SkillTooltipCooldownLabel
@onready var _skill_tooltip_combo_label: Label = %SkillTooltipComboLabel
@onready var _skill_action_region: VBoxContainer = %SkillActionRegion
@onready var _skill_action_message_label: Label = %SkillActionMessageLabel
@onready var _skill_action_summary_label: Label = %SkillActionSummaryLabel
@onready var _skill_confirm_button: Button = %SkillConfirmButton
@onready var _skill_cancel_button: Button = %SkillCancelButton

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""
var round_number: int = 1

var _units: Array[BattleUnitState] = []
var _turn_queue: Array[BattleUnitState] = []
var _current_turn_index: int = 0
var _battle_log_entries: Array[BattleLogEntry] = []
var _battle_action_log_entries: Array[BattleActionLogEntry] = []
var _hovered_log_index: int = -1
var _feedback_generation: int = 0
var _transient_log_entry: BattleLogEntry
var _action_in_progress: bool = false
var _battle_outcome: BattleOutcome.Type = BattleOutcome.Type.IN_PROGRESS
var _reward_options: Array[BattleRewardOption] = []
var _selected_reward: BattleRewardOption
var _reward_confirmation_latched: bool = false
var _inspected_unit_id: StringName = &""
var _selected_skill_id: StringName = &""
var _hovered_skill_button: Button
var _skill_tooltip_generation: int = 0
var _skill_transaction: BattleSkillTransaction = BattleSkillTransaction.new()
var _battle_revision: int = 0


func _exit_tree() -> void:
	_skill_transaction.reset()
	_clear_committed_action_history()


func _ready() -> void:
	var exit_callable := Callable(self, "_on_exit_debug_pressed")
	if not _exit_debug_button.pressed.is_connected(exit_callable):
		_exit_debug_button.pressed.connect(exit_callable)
	var advance_callable := Callable(self, "_on_advance_debug_pressed")
	if not _advance_debug_button.pressed.is_connected(advance_callable):
		_advance_debug_button.pressed.connect(advance_callable)
	var skill_confirm_callable := Callable(self, "confirm_skill_action")
	if not _skill_confirm_button.pressed.is_connected(skill_confirm_callable):
		_skill_confirm_button.pressed.connect(skill_confirm_callable)
	var skill_cancel_callable := Callable(self, "cancel_skill_action")
	if not _skill_cancel_button.pressed.is_connected(skill_cancel_callable):
		_skill_cancel_button.pressed.connect(skill_cancel_callable)
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
	_skill_transaction.reset()
	_battle_revision = 0
	_feedback_generation += 1
	_action_in_progress = false
	_hovered_log_index = -1
	_transient_log_entry = null
	_battle_log_entries.clear()
	_clear_committed_action_history()
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


func _clear_committed_action_history() -> void:
	_battle_action_log_entries.clear()


func get_committed_action_history_snapshot() -> Array[BattleActionLogEntry]:
	var snapshot: Array[BattleActionLogEntry] = []
	for entry: BattleActionLogEntry in _battle_action_log_entries:
		snapshot.append(entry.duplicate_entry())
	return snapshot


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
	_selected_skill_id = &""
	_inspected_unit_id = unit.unit_id
	_refresh_skill_inspector()


func get_selected_skill_id() -> StringName:
	return _selected_skill_id


func select_skill(skill_id: StringName) -> void:
	var unit := get_unit_by_id(_inspected_unit_id)
	if not is_instance_valid(unit):
		return
	for skill: CharacterSkill in unit.skills:
		if skill.skill_id == skill_id:
			_selected_skill_id = skill_id
			_refresh_skill_selection()
			if skill.kind == CharacterSkill.Kind.ACTIVE:
				begin_skill_action(unit.unit_id, skill.skill_id)
			return


func preview_skill_action(actor_id: StringName, skill_id: StringName) -> bool:
	if _skill_transaction.state not in [
		BattleSkillTransaction.State.IDLE,
		BattleSkillTransaction.State.PREVIEWING,
		BattleSkillTransaction.State.CANCELLED,
		BattleSkillTransaction.State.REJECTED_STALE,
	]:
		return false
	var actor: BattleUnitState = get_unit_by_id(actor_id)
	var skill: CharacterSkill = _find_skill(actor, skill_id)
	var current: BattleUnitState = get_current_unit()
	var evaluation: SkillTargetEvaluation = BattleSkillRules.evaluate_targets(
		actor,
		skill,
		_units,
		current.unit_id if is_instance_valid(current) else &"",
		is_battle_complete(),
		round_number,
		_battle_revision,
		get_committed_action_history_snapshot()
	)
	_skill_transaction.preview(evaluation)
	_render_skill_transaction()
	return evaluation.can_start


func clear_skill_preview() -> void:
	if _skill_transaction.state == BattleSkillTransaction.State.PREVIEWING:
		_skill_transaction.reset()
		_render_skill_transaction()


func get_battle_revision() -> int:
	return _battle_revision


func get_skill_presentation_snapshot() -> Dictionary:
	return _skill_transaction.presentation_snapshot()


func notify_authoritative_battle_change(increment_revision: bool = true) -> void:
	if increment_revision:
		_battle_revision += 1
	if (
		_skill_transaction.state != BattleSkillTransaction.State.TARGETING
		or _skill_transaction.locked_target_ids.is_empty()
	):
		_render_skill_transaction()
		return
	var generation: int = _skill_transaction.generation
	var actor: BattleUnitState = get_unit_by_id(_skill_transaction.actor_id)
	var skill: CharacterSkill = _find_skill(actor, _skill_transaction.skill_id)
	var current: BattleUnitState = get_current_unit()
	var validation: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(
		actor,
		skill,
		_units,
		current.unit_id if is_instance_valid(current) else &"",
		is_battle_complete(),
		round_number,
		_skill_transaction.locked_target_ids,
		_battle_revision,
		_battle_revision,
		get_committed_action_history_snapshot()
	)
	if validation.accepted:
		_skill_transaction.battle_revision = _battle_revision
	else:
		_skill_transaction.begin_confirmation(generation)
		_skill_transaction.complete_confirmation(validation, generation)
	_render_skill_transaction()


func get_skill_transaction_state() -> BattleSkillTransaction.State:
	return _skill_transaction.state


func begin_skill_action(actor_id: StringName, skill_id: StringName) -> bool:
	var actor: BattleUnitState = get_unit_by_id(actor_id)
	var skill: CharacterSkill = _find_skill(actor, skill_id)
	var current: BattleUnitState = get_current_unit()
	var evaluation: SkillTargetEvaluation = BattleSkillRules.evaluate_targets(
		actor,
		skill,
		_units,
		current.unit_id if is_instance_valid(current) else &"",
		is_battle_complete(),
		round_number,
		_battle_revision,
		get_committed_action_history_snapshot()
	)
	var generation: int = _skill_transaction.preview(evaluation)
	if not _skill_transaction.begin_targeting(generation):
		_render_skill_transaction()
		return false
	_inspected_unit_id = actor_id
	_selected_skill_id = skill_id
	_render_skill_transaction()
	_refresh_skill_selection()
	return true


func select_skill_target(target_id: StringName) -> bool:
	var accepted: bool = _skill_transaction.select_target(
		target_id,
		_skill_transaction.generation
	)
	_render_skill_transaction()
	return accepted


func hover_skill_target(target_id: StringName) -> bool:
	var accepted: bool = _skill_transaction.hover_target(
		target_id,
		_skill_transaction.generation
	)
	_render_skill_transaction()
	return accepted


func clear_skill_target_hover() -> void:
	_skill_transaction.clear_target_hover(_skill_transaction.generation)
	_render_skill_transaction()


func cancel_skill_action() -> bool:
	var cancelled: bool = _skill_transaction.cancel(_skill_transaction.generation)
	_render_skill_transaction()
	return cancelled


func confirm_skill_action() -> bool:
	var generation: int = _skill_transaction.generation
	if not _skill_transaction.begin_confirmation(generation):
		return false
	_render_skill_transaction()
	var actor: BattleUnitState = get_unit_by_id(_skill_transaction.actor_id)
	var skill: CharacterSkill = _find_skill(actor, _skill_transaction.skill_id)
	var current: BattleUnitState = get_current_unit()
	var validation: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(
		actor,
		skill,
		_units,
		current.unit_id if is_instance_valid(current) else &"",
		is_battle_complete(),
		round_number,
		_skill_transaction.locked_target_ids,
		_skill_transaction.battle_revision,
		_battle_revision,
		get_committed_action_history_snapshot()
	)
	if not _skill_transaction.complete_confirmation(validation, generation):
		_render_skill_transaction()
		return false
	if not validation.accepted or not is_instance_valid(validation.effect_plan):
		_render_skill_transaction()
		return false
	var committed: bool = _commit_skill_effect_plan(validation.effect_plan)
	if committed:
		_skill_transaction.finish_resolution(generation)
	_render_skill_transaction()
	return committed


func remove_battle_unit(unit_id: StringName) -> bool:
	var unit: BattleUnitState = get_unit_by_id(unit_id)
	if not is_instance_valid(unit):
		return false
	_units.erase(unit)
	_turn_queue = BattleTurnQueue.build(_units)
	_current_turn_index = 0
	notify_authoritative_battle_change()
	_refresh_turn_ui()
	return true


func get_unit_by_id(unit_id: StringName) -> BattleUnitState:
	for unit: BattleUnitState in _units:
		if is_instance_valid(unit) and unit.unit_id == unit_id:
			return unit
	return null


func _find_skill(actor: BattleUnitState, skill_id: StringName) -> CharacterSkill:
	if not is_instance_valid(actor):
		return null
	for skill: CharacterSkill in actor.skills:
		if skill.skill_id == skill_id:
			return skill
	return null


func _commit_skill_effect_plan(plan: SkillEffectPlan) -> bool:
	if (
		_action_in_progress
		or not is_instance_valid(plan)
		or plan.battle_revision != _battle_revision
		or plan.actor_id != _skill_transaction.actor_id
		or plan.skill_id != _skill_transaction.skill_id
	):
		return false
	var actor: BattleUnitState = get_unit_by_id(plan.actor_id)
	var skill: CharacterSkill = _find_skill(actor, plan.skill_id)
	if not is_instance_valid(actor) or not is_instance_valid(skill):
		return false
	for operation: Dictionary in plan.damage_operations:
		var target: BattleUnitState = get_unit_by_id(operation.get("target_id", &""))
		if not is_instance_valid(target) or not target.is_active() or int(operation.get(&"total_requested_damage", 0)) <= 0:
			return false
	for operation: Dictionary in plan.speed_operations:
		var target: BattleUnitState = get_unit_by_id(operation.get("target_id", &""))
		if not is_instance_valid(target) or not target.is_active():
			return false
	_action_in_progress = true
	var action_round: int = round_number
	var action_damage_results: Array[BattleDamageResult] = []
	var action_base_damage_by_target: Dictionary[StringName, int] = {}
	var action_combo_bonus_damage_by_target: Dictionary[StringName, int] = {}
	var action_speed_target_ids: Array[StringName] = []
	for operation: Dictionary in plan.damage_operations:
		var target: BattleUnitState = get_unit_by_id(operation["target_id"])
		var target_id: StringName = operation[&"target_id"]
		action_base_damage_by_target[target_id] = int(operation[&"base_damage"])
		action_combo_bonus_damage_by_target[target_id] = int(operation[&"combo_bonus_damage"])
		var result: BattleDamageResult = BattleDamageResolver.apply_damage(
			actor,
			target,
			int(operation[&"total_requested_damage"])
		)
		if not is_instance_valid(result):
			_action_in_progress = false
			return false
		action_damage_results.append(result)
		var entry := BattleLogEntry.new(
			_battle_log_entries.size() + 1,
			action_round,
			result
		)
		_battle_log_entries.append(entry)
		_append_log_control(entry, _battle_log_entries.size() - 1)
		_show_resolution_feedback(entry)
	var new_actor_speed_sources: Array[StringName] = []
	for operation: Dictionary in plan.speed_operations:
		var target: BattleUnitState = get_unit_by_id(operation["target_id"])
		action_speed_target_ids.append(target.unit_id)
		target.add_speed_modifier(
			operation["source_id"],
			int(operation["amount"]),
			operation["expiry"],
			int(operation["duration"]),
			int(operation["applied_round"])
		)
		if target == actor:
			new_actor_speed_sources.append(operation["source_id"])
	if plan.cooldown_actions > 0:
		actor.set_skill_cooldown(plan.skill_id, plan.cooldown_actions)
	var excluded_cooldowns: Array[StringName] = []
	if plan.cooldown_actions > 0:
		excluded_cooldowns.append(plan.skill_id)
	actor.tick_skill_cooldowns(excluded_cooldowns)
	actor.expire_speed_modifiers_after_action(new_actor_speed_sources)
	var action_entry := BattleActionLogEntry.new(
		_battle_action_log_entries.size() + 1,
		action_round,
		plan.actor_id,
		actor.side,
		plan.skill_id,
		plan.target_ids,
		action_damage_results,
		action_base_damage_by_target,
		action_combo_bonus_damage_by_target,
		action_speed_target_ids,
		_action_has_combo_bonus(action_combo_bonus_damage_by_target)
	)
	_battle_action_log_entries.append(action_entry)
	_battle_revision += 1
	var resolved_outcome: BattleOutcome.Type = BattleOutcome.evaluate(_units)
	if resolved_outcome == BattleOutcome.Type.IN_PROGRESS and plan.advance_turn:
		_advance_after_action(actor.unit_id)
	else:
		_complete_battle(resolved_outcome)
	_action_in_progress = false
	_refresh_turn_ui()
	return true


func _action_has_combo_bonus(bonus_by_target: Dictionary[StringName, int]) -> bool:
	for bonus: int in bonus_by_target.values():
		if bonus > 0:
			return true
	return false


func _render_skill_transaction() -> void:
	if not is_node_ready():
		return
	var snapshot: Dictionary = _skill_transaction.presentation_snapshot()
	_skill_action_region.visible = snapshot["action_region_visible"]
	_skill_action_message_label.text = snapshot["message"]
	_skill_action_summary_label.text = snapshot["summary"]
	_skill_action_summary_label.visible = not _skill_action_summary_label.text.is_empty()
	_skill_confirm_button.visible = snapshot["confirm_visible"]
	_skill_confirm_button.disabled = not snapshot["confirm_enabled"]
	_skill_cancel_button.visible = snapshot["cancel_visible"]
	_skill_cancel_button.disabled = not snapshot["cancel_enabled"]
	var roles: Dictionary = snapshot["indicator_roles"]
	for slot: Control in get_player_slots() + get_enemy_slots():
		var overlay := slot.get_node_or_null("TargetIndicatorOverlay") as Panel
		if not is_instance_valid(overlay):
			continue
		var unit_id: StringName = slot.get_meta("unit_id", &"")
		var role: StringName = roles.get(unit_id, &"")
		slot.set_meta("target_indicator_role", role)
		overlay.visible = not role.is_empty()
		var tint: TextureRect = _get_or_create_indicator_tint(overlay)
		if role.is_empty():
			overlay.remove_theme_stylebox_override("panel")
			tint.visible = false
			continue
		overlay.add_theme_stylebox_override("panel", _indicator_style(role))
		_update_indicator_tint(tint, role)


func _indicator_style(role: StringName) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var is_invalid: bool = role in [&"invalid_preview", &"invalid_hover"]
	var is_combo: bool = role in [&"combo_ready", &"combo_ready_locked"]
	var border_color := Color(0.95, 0.2, 0.2, 1.0) if is_invalid else Color(0.25, 0.95, 0.45, 1.0)
	if is_combo:
		border_color = Color(1.0, 0.72, 0.18, 1.0)
	style.border_color = border_color
	style.set_border_width_all(3)
	style.bg_color = Color.TRANSPARENT
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _get_or_create_indicator_tint(overlay: Panel) -> TextureRect:
	var existing := overlay.get_node_or_null("CenterTint") as TextureRect
	if is_instance_valid(existing):
		return existing
	var tint := TextureRect.new()
	tint.name = "CenterTint"
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tint.offset_left = 4.0
	tint.offset_top = 4.0
	tint.offset_right = -4.0
	tint.offset_bottom = -4.0
	tint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tint.stretch_mode = TextureRect.STRETCH_SCALE
	overlay.add_child(tint)
	return tint


func _update_indicator_tint(tint: TextureRect, role: StringName) -> void:
	var has_tint: bool = role in [
		&"valid_preview",
		&"invalid_preview",
		&"invalid_hover",
		&"locked",
		&"combo_ready",
		&"combo_ready_locked",
	]
	tint.visible = has_tint
	if not has_tint:
		return
	var is_invalid: bool = role in [&"invalid_preview", &"invalid_hover"]
	var is_combo: bool = role in [&"combo_ready", &"combo_ready_locked"]
	var tint_color := Color(0.95, 0.2, 0.2, 0.16) if is_invalid else Color(0.25, 0.95, 0.45, 0.16)
	if is_combo:
		tint_color = Color(1.0, 0.72, 0.18, 0.14)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.7, 1.0])
	gradient.colors = PackedColorArray([
		tint_color,
		Color(tint_color.r, tint_color.g, tint_color.b, tint_color.a * 0.35),
		Color(tint_color.r, tint_color.g, tint_color.b, 0.0),
	])
	var texture := GradientTexture2D.new()
	texture.width = 128
	texture.height = 96
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	tint.texture = texture


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
		var completed_round: int = round_number
		round_number += 1
		_expire_round_modifiers(completed_round)
		_turn_queue = BattleTurnQueue.build(_units)
		_current_turn_index = 0
	_battle_revision += 1
	notify_authoritative_battle_change(false)
	_refresh_turn_ui()


func get_player_slots() -> Array[Control]:
	return _get_control_children(_player_formation)


func get_enemy_slots() -> Array[Control]:
	return _get_control_children(_enemy_formation)


func _create_debug_units() -> Array[BattleUnitState]:
	return [
		BattleUnitState.new(&"player_0", "Player Front 1", BattleUnitState.Side.PLAYER, 0, 8, 20, _skill_roster([
			_create_skill(&"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE, "Deal 7 damage.", "One selected active enemy.", "User must occupy a front-row slot.", "1 turn after use."),
			_create_skill(&"frontline_guard", "Frontline Guard", CharacterSkill.Kind.PASSIVE, "Reduce the next damage taken by an adjacent ally by 3.", "Adjacent active allies.", "User must occupy a front-row slot.", "None"),
		])),
		BattleUnitState.new(&"player_1", "Player Front 2", BattleUnitState.Side.PLAYER, 1, 6),
		BattleUnitState.new(&"player_2", "Player Front 3", BattleUnitState.Side.PLAYER, 2, 6, 20, _skill_roster([
			_create_skill(&"quick_step", "Quick Step", CharacterSkill.Kind.ACTIVE, "Gain 2 Speed until the end of the next turn.", "Self.", "None", "2 turns after use."),
		])),
		BattleUnitState.new(&"player_3", "Player Back 1", BattleUnitState.Side.PLAYER, 3, 4),
		BattleUnitState.new(&"player_4", "Player Back 2", BattleUnitState.Side.PLAYER, 4, 9, 20, _skill_roster([
			_create_skill(&"quick_strike", "Quick Strike", CharacterSkill.Kind.ACTIVE, "Deal 5 damage.", "One selected active enemy.", "None", "None"),
			_create_skill(&"rally", "Rally", CharacterSkill.Kind.ACTIVE, "Grant all active allies 2 Speed until the end of the round.", "All active allies, including the user.", "None", "2 turns after use."),
			_create_skill(&"evasion", "Evasion", CharacterSkill.Kind.PASSIVE, "Prevent the first damage instance received each round.", "Self.", "None", "None"),
			_create_skill(&"momentum", "Momentum", CharacterSkill.Kind.PASSIVE, "Gain 1 Speed after taking an action, lasting until battle ends.", "Self.", "User must remain active.", "None"),
		])),
		BattleUnitState.new(&"player_5", "Player Back 3", BattleUnitState.Side.PLAYER, 5, 2),
		BattleUnitState.new(&"enemy_0", "Enemy Front 1", BattleUnitState.Side.ENEMY, 0, 8, 20, _skill_roster([
			_create_skill(&"savage_blow", "Savage Blow", CharacterSkill.Kind.ACTIVE, "Deal 12 damage.", "One selected active enemy.", "User must be above 50% HP.", "2 turns after use."),
			_create_skill(&"blood_scent", "Blood Scent", CharacterSkill.Kind.PASSIVE, "Deal 3 additional damage to injured enemies.", "Enemies below 50% HP.", "Target must be below 50% HP.", "None"),
		])),
		BattleUnitState.new(&"enemy_1", "Enemy Front 2", BattleUnitState.Side.ENEMY, 1, 7),
		BattleUnitState.new(&"enemy_2", "Enemy Front 3", BattleUnitState.Side.ENEMY, 2, 6, 20, _skill_roster([
			_create_skill(&"brace", "Brace", CharacterSkill.Kind.PASSIVE, "Reduce the first damage received each round by 2.", "Self.", "None", "None"),
		])),
		BattleUnitState.new(&"enemy_3", "Enemy Back 1", BattleUnitState.Side.ENEMY, 3, 4),
		BattleUnitState.new(&"enemy_4", "Enemy Back 2", BattleUnitState.Side.ENEMY, 4, 9, 20, _skill_roster([
			_create_skill(&"shadow_lunge", "Shadow Lunge", CharacterSkill.Kind.ACTIVE, "Deal 10 damage.", "Farthest active enemy.", "User must occupy a back-row slot.", "Unavailable for the first turn of battle; none after use."),
		])),
		BattleUnitState.new(&"enemy_5", "Enemy Back 3", BattleUnitState.Side.ENEMY, 5, 2),
	]


func _create_skill(
	id: StringName,
	display_name: String,
	kind: CharacterSkill.Kind,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> CharacterSkill:
	var targeting_mode: CharacterSkill.TargetingMode = CharacterSkill.TargetingMode.PREDEFINED
	var target_side: CharacterSkill.TargetSide = CharacterSkill.TargetSide.SELF
	var target_rule: CharacterSkill.TargetRule = CharacterSkill.TargetRule.SELF
	var requirement: CharacterSkill.Requirement = CharacterSkill.Requirement.NONE
	var mechanical_effect: CharacterSkill.Effect = CharacterSkill.Effect.NONE
	var effect_magnitude: int = 0
	var effect_duration: int = 0
	var effect_duration_mode: CharacterSkill.EffectDuration = CharacterSkill.EffectDuration.NONE
	var cooldown_mode: CharacterSkill.CooldownMode = CharacterSkill.CooldownMode.NONE
	var cooldown_actions: int = 0
	var unavailable_through_round: int = 0
	var combo_definition: RefCounted = null
	match id:
		&"shield_bash":
			targeting_mode = CharacterSkill.TargetingMode.FREE
			target_side = CharacterSkill.TargetSide.ENEMY
			target_rule = CharacterSkill.TargetRule.SELECT_ONE
			requirement = CharacterSkill.Requirement.FRONT_ROW
			mechanical_effect = CharacterSkill.Effect.DAMAGE
			effect_magnitude = 7
			cooldown_mode = CharacterSkill.CooldownMode.POST_USE_ACTIONS
			cooldown_actions = 1
		&"quick_step":
			target_side = CharacterSkill.TargetSide.SELF
			target_rule = CharacterSkill.TargetRule.SELF
			mechanical_effect = CharacterSkill.Effect.SPEED_BOOST
			effect_magnitude = 2
			effect_duration = 1
			effect_duration_mode = CharacterSkill.EffectDuration.NEXT_ACTION
			cooldown_mode = CharacterSkill.CooldownMode.POST_USE_ACTIONS
			cooldown_actions = 2
		&"quick_strike":
			targeting_mode = CharacterSkill.TargetingMode.FREE
			target_side = CharacterSkill.TargetSide.ENEMY
			target_rule = CharacterSkill.TargetRule.SELECT_ONE
			mechanical_effect = CharacterSkill.Effect.DAMAGE
			effect_magnitude = 5
			var condition_script: Script = load("res://Scripts/Battle/combo_condition.gd")
			var effect_script: Script = load("res://Scripts/Battle/combo_bonus_effect.gd")
			var definition_script: Script = load("res://Scripts/Battle/combo_definition.gd")
			combo_definition = definition_script.create(
				[condition_script.create(0)],
				[effect_script.create(0, 3)],
				"+3 damage if another ally damaged this target with a skill this round."
			)
		&"rally":
			target_side = CharacterSkill.TargetSide.ALLY
			target_rule = CharacterSkill.TargetRule.ALL_ACTIVE_ALLIES
			mechanical_effect = CharacterSkill.Effect.SPEED_BOOST
			effect_magnitude = 2
			effect_duration = 1
			effect_duration_mode = CharacterSkill.EffectDuration.CURRENT_ROUND
			cooldown_mode = CharacterSkill.CooldownMode.POST_USE_ACTIONS
			cooldown_actions = 2
		&"savage_blow":
			targeting_mode = CharacterSkill.TargetingMode.FREE
			target_side = CharacterSkill.TargetSide.ENEMY
			target_rule = CharacterSkill.TargetRule.SELECT_ONE
			requirement = CharacterSkill.Requirement.ABOVE_HALF_HP
			mechanical_effect = CharacterSkill.Effect.DAMAGE
			effect_magnitude = 12
			cooldown_mode = CharacterSkill.CooldownMode.POST_USE_ACTIONS
			cooldown_actions = 2
		&"shadow_lunge":
			target_side = CharacterSkill.TargetSide.ENEMY
			target_rule = CharacterSkill.TargetRule.FARTHEST_ACTIVE_ENEMY
			requirement = CharacterSkill.Requirement.BACK_ROW
			mechanical_effect = CharacterSkill.Effect.DAMAGE
			effect_magnitude = 10
			cooldown_mode = CharacterSkill.CooldownMode.ROUND_GATE
			unavailable_through_round = 1
	return CharacterSkill.new(
		id,
		display_name,
		kind,
		effect,
		targeting,
		requirements,
		cooldown,
		targeting_mode,
		target_side,
		target_rule,
		requirement,
		mechanical_effect,
		effect_magnitude,
		effect_duration,
		effect_duration_mode,
		cooldown_mode,
		cooldown_actions,
		unavailable_through_round,
		combo_definition
	)


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
		var completed_round: int = round_number
		round_number += 1
		_expire_round_modifiers(completed_round)
		_current_turn_index = 0


func _expire_round_modifiers(completed_round: int) -> void:
	for unit: BattleUnitState in _units:
		if is_instance_valid(unit):
			unit.expire_speed_modifiers_for_round(completed_round)


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
		var enter_callable := Callable(self, "_on_slot_mouse_entered").bind(slot)
		if not slot.mouse_entered.is_connected(enter_callable):
			slot.mouse_entered.connect(enter_callable)
		var exit_callable := Callable(self, "_on_slot_mouse_exited").bind(slot)
		if not slot.mouse_exited.is_connected(exit_callable):
			slot.mouse_exited.connect(exit_callable)


func _on_slot_gui_input(event: InputEvent, slot: Control) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	var unit_id := slot.get_meta("unit_id", &"") as StringName
	if unit_id.is_empty():
		return
	if _skill_transaction.state == BattleSkillTransaction.State.TARGETING:
		select_skill_target(unit_id)
		return
	inspect_unit(unit_id)


func _on_slot_mouse_entered(slot: Control) -> void:
	var unit_id: StringName = slot.get_meta("unit_id", &"")
	if not unit_id.is_empty():
		hover_skill_target(unit_id)


func _on_slot_mouse_exited(_slot: Control) -> void:
	clear_skill_target_hover()


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
		current_unit.get_effective_speed(),
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
		speed_label.text = "Speed %d" % unit.get_effective_speed()
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
	_skill_inspector_body.visible = true
	_skill_inspector_unit_name_label.text = unit.display_name
	_skill_inspector_status_label.text = "Active" if unit.is_active() else "Defeated"
	var unit_skills := unit.skills
	_skill_inspector_count_label.text = "Skills: %d/%d" % [unit_skills.size(), BattleUnitState.MAX_CHARACTER_SKILLS]
	_skill_inspector_empty_label.visible = unit_skills.is_empty()
	var selection_still_owned := false
	for index: int in unit_skills.size():
		var skill := unit_skills[index]
		selection_still_owned = selection_still_owned or skill.skill_id == _selected_skill_id
		_skill_inspector_skills.add_child(_create_skill_button(skill, index + 1))
	if not selection_still_owned:
		_selected_skill_id = &""
	_refresh_skill_selection()


func _create_skill_button(skill: CharacterSkill, skill_index: int) -> Button:
	var button := Button.new()
	button.custom_minimum_size = SKILL_BUTTON_SIZE
	button.set_meta("skill_id", skill.skill_id)
	button.set_meta("skill_index", skill_index)
	button.set_meta("selected", false)
	button.pressed.connect(select_skill.bind(skill.skill_id))
	button.mouse_entered.connect(_on_skill_button_mouse_entered.bind(skill, button))
	button.mouse_exited.connect(_on_skill_button_mouse_exited.bind(button))

	var number_label := Label.new()
	number_label.name = "NumberLabel"
	number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	number_label.text = str(skill_index)
	number_label.offset_left = 6.0
	number_label.offset_top = 3.0
	button.add_child(number_label)

	var name_label := Label.new()
	name_label.name = "NameLabel"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_label.offset_left = 8.0
	name_label.offset_top = 18.0
	name_label.offset_right = -8.0
	name_label.offset_bottom = -18.0
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.text = skill.display_name
	button.add_child(name_label)

	var kind_label := Label.new()
	kind_label.name = "KindLabel"
	kind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(kind_label)
	kind_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	kind_label.offset_top = -20.0
	kind_label.offset_bottom = -3.0
	kind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kind_label.text = "Active" if skill.kind == CharacterSkill.Kind.ACTIVE else "Passive"
	return button


func _refresh_skill_selection() -> void:
	for child: Node in _skill_inspector_skills.get_children():
		var button := child as Button
		if not is_instance_valid(button):
			continue
		var is_selected: bool = button.get_meta("skill_id", &"") == _selected_skill_id
		button.set_meta("selected", is_selected)
		button.self_modulate = SELECTED_SKILL_COLOR if is_selected else Color.WHITE


func _on_skill_button_mouse_entered(skill: CharacterSkill, button: Button) -> void:
	if not is_instance_valid(skill) or not skill.is_valid() or not is_instance_valid(button):
		_hide_skill_tooltip()
		return
	_hovered_skill_button = button
	_skill_tooltip_generation += 1
	var generation := _skill_tooltip_generation
	_skill_tooltip_name_label.text = skill.display_name
	_skill_tooltip_kind_label.text = (
		"Active" if skill.kind == CharacterSkill.Kind.ACTIVE else "Passive"
	)
	_skill_tooltip_effect_label.text = "Effect: %s" % skill.effect_text
	_skill_tooltip_targeting_label.text = "Targeting: %s" % skill.targeting_text
	_skill_tooltip_requirements_label.text = "Requirements: %s" % skill.requirements_text
	_skill_tooltip_cooldown_label.text = "Cooldown: %s" % skill.cooldown_text
	_skill_tooltip_combo_label.visible = is_instance_valid(skill.combo_definition)
	_skill_tooltip_combo_label.text = (
		"Combo: %s" % skill.combo_definition.description_text
		if is_instance_valid(skill.combo_definition) else ""
	)
	_skill_tooltip_panel.visible = true
	_skill_tooltip_panel.reset_size()
	preview_skill_action(_inspected_unit_id, skill.skill_id)
	call_deferred("_position_skill_tooltip", button, generation)


func _on_skill_button_mouse_exited(button: Button) -> void:
	if button != _hovered_skill_button:
		return
	_hide_skill_tooltip()
	clear_skill_preview()


func _position_skill_tooltip(button_value: Variant, generation: int) -> void:
	if not is_instance_valid(button_value) or not button_value is Button:
		return
	var button := button_value as Button
	if (
		not _skill_tooltip_panel.visible
		or button != _hovered_skill_button
		or generation != _skill_tooltip_generation
	):
		return
	_skill_tooltip_panel.size = _skill_tooltip_panel.get_combined_minimum_size()
	var button_rect := button.get_global_rect()
	var tooltip_size := _skill_tooltip_panel.size
	var viewport_size := get_viewport_rect().size
	var centered_x := button_rect.position.x + (button_rect.size.x - tooltip_size.x) * 0.5
	var max_x := maxf(
		SKILL_TOOLTIP_VIEWPORT_MARGIN,
		viewport_size.x - SKILL_TOOLTIP_VIEWPORT_MARGIN - tooltip_size.x
	)
	var x := clampf(centered_x, SKILL_TOOLTIP_VIEWPORT_MARGIN, max_x)
	var above_y := button_rect.position.y - SKILL_TOOLTIP_ANCHOR_GAP - tooltip_size.y
	var below_y := button_rect.end.y + SKILL_TOOLTIP_ANCHOR_GAP
	var max_y := maxf(
		SKILL_TOOLTIP_VIEWPORT_MARGIN,
		viewport_size.y - SKILL_TOOLTIP_VIEWPORT_MARGIN - tooltip_size.y
	)
	var y := above_y if above_y >= SKILL_TOOLTIP_VIEWPORT_MARGIN else clampf(
		below_y,
		SKILL_TOOLTIP_VIEWPORT_MARGIN,
		max_y
	)
	_skill_tooltip_panel.global_position = Vector2(x, y)


func _hide_skill_tooltip() -> void:
	_skill_tooltip_generation += 1
	_hovered_skill_button = null
	if not is_node_ready():
		return
	_skill_tooltip_panel.visible = false
	_skill_tooltip_name_label.text = ""
	_skill_tooltip_kind_label.text = ""
	_skill_tooltip_effect_label.text = ""
	_skill_tooltip_targeting_label.text = ""
	_skill_tooltip_requirements_label.text = ""
	_skill_tooltip_cooldown_label.text = ""
	_skill_tooltip_combo_label.text = ""
	_skill_tooltip_combo_label.visible = false


func _clear_skill_inspector() -> void:
	_hide_skill_tooltip()
	_inspected_unit_id = &""
	_selected_skill_id = &""
	if not is_node_ready():
		return
	_clear_skill_rows()
	_skill_transaction.reset()
	_render_skill_transaction()
	_skill_inspector_prompt_label.visible = true
	_skill_inspector_body.visible = false
	_skill_inspector_unit_name_label.text = ""
	_skill_inspector_status_label.text = ""
	_skill_inspector_count_label.text = ""
	_skill_inspector_empty_label.visible = false


func _clear_skill_rows() -> void:
	_hide_skill_tooltip()
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
	_skill_transaction.reset()
	_clear_committed_action_history()
	_render_skill_transaction()
	_clear_reward_ui()
	call_deferred("_emit_exit_requested")


func _emit_exit_requested() -> void:
	exit_requested.emit()
