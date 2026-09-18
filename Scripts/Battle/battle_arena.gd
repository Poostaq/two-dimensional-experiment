class_name BattleArena
extends Control

signal exit_requested
signal battle_completed(outcome: BattleOutcome.Type)
signal reward_selected(option: BattleRewardOption)
signal reward_confirmed(option: BattleRewardOption)
signal recruitment_placement_requested(option: BattleRewardOption)
signal preparation_commit_requested(choice: int, target_unit_id: StringName, expected_setup_key: String)

@export var debug_encounter_index: int = 0

var _auto_enemy_turns: bool = false
var _executing_enemy_action: bool = false
var _enemy_action_elapsed: float = 0.0

const SIDE_SLOT_COUNT := 6
const NEUTRAL_SLOT_COLOR := Color.WHITE
const CURRENT_SLOT_BORDER_COLOR := Color.WHITE
const EFFECT_POSITIVE_BORDER_COLOR := Color(0.25, 0.95, 0.45, 1.0)
const EFFECT_NEGATIVE_BORDER_COLOR := Color(1.0, 0.35, 0.4, 1.0)
const CURRENT_SLOT_BORDER_WIDTH := 3
const ATTACKER_SLOT_COLOR := Color(0.35, 0.9, 0.5, 1.0)
const RECEIVER_SLOT_COLOR := Color(1.0, 0.35, 0.4, 1.0)
const EFFECT_HIGHLIGHT_TURN_ADVANCES := 2
const FEEDBACK_DURATION_SECONDS := 0.8
const SELECTED_REWARD_COLOR := Color(1.0, 0.82, 0.32, 1.0)

enum DefaultActionMode { NONE, ATTACK, SWAP }

static var PREPARATION_RECORD_SCRIPT: GDScript = load(
	"res://Scripts/Battle/battle_preparation_record.gd"
)
static var SETUP_IDENTITY_SCRIPT: GDScript = load(
	"res://Scripts/Battle/battle_setup_identity.gd"
)
static var KEYWORD_SOURCE_SCRIPT: GDScript = load(
	"res://Scripts/Battle/battle_keyword_source.gd"
)
static var PREPARATION_TRANSACTION_SCRIPT: GDScript = load(
	"res://Scripts/Battle/battle_preparation_transaction.gd"
)

@onready var _encounter_type_label: Label = %EncounterTypeLabel
@onready var _player_formation: Container = %PlayerFormation
@onready var _enemy_formation: Container = %EnemyFormation
@onready var _round_label: Label = %RoundLabel
@onready var _current_unit_label: Label = %CurrentUnitLabel
@onready var _turn_order_ribbon: Control = %TurnOrderRibbon
@onready var _action_bar: Control = %BattleActionBar
@onready var _debug_drawer: Control = %BattleDebugDrawer
@onready var _character_info: Control = %BattleCharacterInfoPanel
@onready var _battle_result_panel: PanelContainer = %BattleResultPanel
@onready var _battle_result_label: Label = %BattleResultLabel
@onready var _reward_overlay: CenterContainer = %RewardOverlay
@onready var _reward_panel: PanelContainer = %RewardPanel
@onready var _reward_heading_label: Label = %RewardHeadingLabel
@onready var _reward_options_container: VBoxContainer = %RewardOptions
@onready var _reward_empty_state_label: Label = %RewardEmptyStateLabel
@onready var _reward_description_label: Label = %RewardDescriptionLabel
@onready var _confirm_reward_button: Button = %ConfirmRewardButton
@onready var _preparation_blocker: PanelContainer = %PreparationBlocker
@onready var _frontline_briefing_button: Button = %FrontlineBriefingButton
@onready var _spare_plating_button: Button = %SparePlatingButton
@onready var _preparation_target_option: OptionButton = %PreparationTargetOption
@onready var _preparation_message_label: Label = %PreparationMessageLabel
@onready var _preparation_confirm_button: Button = %PreparationConfirmButton

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""
var round_number: int = 1

var _units: Array[BattleUnitState] = []
var _configured_player_units: Array[BattleUnitState] = []
var _turn_queue: Array[BattleUnitState] = []
var _current_turn_index: int = 0
var _turn_order_preview_id: StringName = &""
var _turn_order_context: String = ""
var _battle_log_entries: Array[BattleLogEntry] = []
var _battle_action_log_entries: Array[BattleActionLogEntry] = []
var _action_records: Array[BattleActionRecord] = []
var _hovered_log_index: int = -1
var _feedback_generation: int = 0
var _transient_log_entry: BattleLogEntry
var _action_in_progress: bool = false
var _battle_outcome: BattleOutcome.Type = BattleOutcome.Type.IN_PROGRESS
var _terminal_player_health_snapshot: Array[Dictionary] = []
var _reward_options: Array[BattleRewardOption] = []
var _selected_reward: BattleRewardOption
var _pending_recruitment_option: BattleRewardOption
var _reward_confirmation_latched: bool = false
var _configured_reward_options: Array[BattleRewardOption] = []
var _has_configured_reward_options: bool = false
var _inspected_unit_id: StringName = &""
var _selected_skill_id: StringName = &""
var _skill_transaction: BattleSkillTransaction = BattleSkillTransaction.new()
var _battle_revision: int = 0
var _default_action_mode: DefaultActionMode = DefaultActionMode.NONE
var _default_action_preview: Dictionary = {}
var _default_action_message: String = ""
var _effect_highlight_target_colors: Dictionary[StringName, Color] = {}
var _effect_highlight_turns_remaining: int = 0
var _preparation_required: bool = false
var _preparation_record: RefCounted
var _preparation_transaction: RefCounted
var _applied_preparation_ids: Dictionary[StringName, bool] = {}
var _info_cache: Dictionary = {}
var _info_epoch: int = 0
var _info_revision: int = 0
var _info_generation: int = 0
var _info_unit_id: StringName = &""
var _info_valid: bool = true
var _info_return_focus: WeakRef
var _info_presenter: Script = load("res://Scripts/UI/battle_character_info_presenter.gd")


func _exit_tree() -> void:
	close_character_info(false)
	_info_epoch += 1
	_info_cache.clear()
	_skill_transaction.reset()
	_clear_default_action_state()
	_clear_committed_action_history()


var _visual_resolver: Script = load("res://Scripts/UI/battle_visual_state.gd")
var _visual_hover_skill: StringName = &""
var _pointer_target_slot: Control
var _focused_target_slot: Control

func _ready() -> void:
	_debug_drawer.input_managed_by_arena = true
	_character_info.close_requested.connect(close_character_info)
	_character_info.resized.connect(_update_info_occlusion)
	_turn_order_ribbon.unit_preview_changed.connect(_on_turn_order_preview_changed)
	_debug_drawer.damage_requested.connect(_on_advance_debug_pressed)
	_debug_drawer.exit_requested.connect(_on_exit_debug_pressed)
	_debug_drawer.log_preview_changed.connect(_on_debug_log_preview_changed)
	_debug_drawer.opened_changed.connect(_on_debug_drawer_opened)
	_reward_overlay.visibility_changed.connect(_refresh_debug_drawer)
	_preparation_blocker.visibility_changed.connect(_refresh_debug_drawer)
	_action_bar.skill_selected.connect(_on_action_bar_skill_selected)
	_action_bar.skill_preview_changed.connect(_on_action_bar_preview_changed)
	_action_bar.default_attack_requested.connect(_on_default_attack_pressed)
	_action_bar.default_swap_requested.connect(_on_default_swap_pressed)
	_action_bar.confirm_requested.connect(_on_action_bar_confirm)
	_action_bar.cancel_requested.connect(_on_action_bar_cancel)
	var confirm_callable := Callable(self, "confirm_reward_selection")
	if not _confirm_reward_button.pressed.is_connected(confirm_callable):
		_confirm_reward_button.pressed.connect(confirm_callable)
	_frontline_briefing_button.pressed.connect(_on_frontline_briefing_pressed)
	_spare_plating_button.pressed.connect(_on_spare_plating_pressed)
	_preparation_target_option.item_selected.connect(_on_preparation_target_selected)
	_preparation_confirm_button.pressed.connect(_on_preparation_confirm_pressed)
	_clear_reward_ui()
	_assign_slot_metadata(_player_formation, "player")
	_assign_slot_metadata(_enemy_formation, "enemy")
	_refresh_context()
	configure_units(_create_debug_units())
	_auto_enemy_turns = true


func configure(coordinate: Vector2i, type: String) -> void:
	_configured_reward_options.clear()
	_has_configured_reward_options = false
	if type != WorldEncounterType.COMBAT and type != WorldEncounterType.BOSS:
		return
	debug_encounter_index = posmod(coordinate.x + 2 * coordinate.y, 3)
	encounter_coordinate = coordinate
	encounter_type = type
	if is_node_ready():
		_refresh_context()


func configure_reward_options(options: Array[BattleRewardOption]) -> void:
	_configured_reward_options = options.duplicate()
	_has_configured_reward_options = true


func configure_units(units: Array[BattleUnitState]) -> void:
	_auto_enemy_turns = false
	_enemy_action_elapsed = 0.0
	close_character_info(false)
	_info_epoch += 1
	_info_revision = 0
	_info_cache.clear()
	_info_valid = true
	if is_node_ready():
		_debug_drawer.reset_view()
	_clear_turn_order_preview()
	_clear_reward_ui()
	_clear_default_action_state()
	_clear_effect_highlights()
	_clear_skill_inspector()
	_skill_transaction.reset()
	_battle_revision = 0
	_preparation_required = false
	_preparation_record = null
	_applied_preparation_ids.clear()
	if is_node_ready():
		_preparation_blocker.visible = false
	_feedback_generation += 1
	_action_in_progress = false
	_hovered_log_index = -1
	_transient_log_entry = null
	_battle_log_entries.clear()
	_action_records.clear()
	_clear_committed_action_history()
	if is_node_ready():
		_clear_log_controls()
		_clear_all_damage_feedback()
	_battle_outcome = BattleOutcome.Type.IN_PROGRESS
	_terminal_player_health_snapshot.clear()
	_configured_player_units.clear()
	_units = units.duplicate()
	for unit: BattleUnitState in _units:
		if is_instance_valid(unit) and unit.side == BattleUnitState.Side.PLAYER:
			_configured_player_units.append(unit)
	_turn_queue = BattleTurnQueue.build(_units)
	_current_turn_index = 0
	round_number = 1
	_resolve_current_action_start_reactions()
	_publish_character_info()
	if is_node_ready():
		_refresh_turn_ui()


func configure_party_units(player_units: Array[BattleUnitState]) -> void:
	var catalog: Script = load("res://Scripts/Battle/debug_encounter_catalog.gd")
	var battle_units: Array[BattleUnitState] = catalog.create_enemies(debug_encounter_index)
	battle_units.append_array(player_units)
	configure_units(battle_units)
	_auto_enemy_turns = true


func _process(delta: float) -> void:
	var actor: BattleUnitState = get_current_unit()
	if (
		not _auto_enemy_turns or _preparation_required or _action_in_progress
		or is_battle_complete() or not is_instance_valid(actor)
		or actor.side != BattleUnitState.Side.ENEMY
	):
		_enemy_action_elapsed = 0.0
		return
	_enemy_action_elapsed += delta
	if _enemy_action_elapsed < 0.65:
		return
	_enemy_action_elapsed = 0.0
	_perform_enemy_turn()


func _perform_enemy_turn() -> bool:
	var actor: BattleUnitState = get_current_unit()
	if (
		_preparation_required or _action_in_progress or is_battle_complete()
		or not is_instance_valid(actor) or actor.side != BattleUnitState.Side.ENEMY
	):
		return false
	var catalog: Script = load("res://Scripts/Battle/debug_encounter_catalog.gd")
	var choice: Dictionary = catalog.choose_action(
		actor, _units, round_number, _battle_revision,
		get_committed_action_history_snapshot(), get_action_records()
	)
	_executing_enemy_action = true
	var committed: bool = false
	if not choice.is_empty() and begin_skill_action(actor.unit_id, choice["skill_id"]):
		var selected: bool = true
		for target_id: StringName in choice["target_ids"]:
			selected = select_skill_target(target_id) and selected
		if selected:
			committed = confirm_skill_action()
	if not committed:
		_skill_transaction.reset()
		for target: BattleUnitState in _units:
			if is_instance_valid(target) and target.is_active() and target.side != actor.side:
				committed = confirm_default_attack(actor.unit_id, target.unit_id, _battle_revision)
				break
	_executing_enemy_action = false
	return committed


func get_setup_identity() -> RefCounted:
	return SETUP_IDENTITY_SCRIPT.capture(encounter_coordinate, encounter_type, _units)


func configure_preparation(record: RefCounted) -> bool:
	if (
		not is_instance_valid(record)
		or not record.call("is_valid")
		or int(record.get("state")) != PREPARATION_RECORD_SCRIPT.State.OFFERED
	):
		return false
	var identity: RefCounted = get_setup_identity()
	if (
		not is_instance_valid(identity)
		or String(identity.get("canonical_key")) != String(record.get("setup_key"))
	):
		return false
	_preparation_record = record
	_preparation_transaction = PREPARATION_TRANSACTION_SCRIPT.begin(record, identity)
	if not is_instance_valid(_preparation_transaction):
		return false
	_preparation_required = true
	_refresh_turn_order_ribbon()
	_hide_skill_tooltip()
	_refresh_action_bar()
	if is_node_ready():
		_preparation_blocker.visible = true
		_preparation_target_option.visible = false
		_preparation_confirm_button.disabled = true
		_preparation_message_label.text = "Choose a preparation before combat begins."
		_refresh_debug_drawer()
	return true


func apply_committed_preparation(record: RefCounted) -> bool:
	if (
		not is_instance_valid(record)
		or not record.call("is_valid")
		or int(record.get("state")) != PREPARATION_RECORD_SCRIPT.State.COMMITTED
	):
		return false
	var preparation_id := record.get("preparation_id") as StringName
	if _applied_preparation_ids.has(preparation_id):
		_preparation_required = false
		return true
	var identity: RefCounted = get_setup_identity()
	if (
		not is_instance_valid(identity)
		or String(identity.get("canonical_key")) != String(record.get("setup_key"))
	):
		return false
	var choice := int(record.get("choice"))
	var targets: Array[BattleUnitState] = []
	if choice == PREPARATION_RECORD_SCRIPT.Choice.FRONTLINE_BRIEFING:
		var target := get_unit_by_id(record.get("target_unit_id") as StringName)
		if (
			not is_instance_valid(target)
			or target.side != BattleUnitState.Side.ENEMY
			or not target.is_active()
		):
			return false
		targets.append(target)
	elif choice == PREPARATION_RECORD_SCRIPT.Choice.SPARE_PLATING:
		for unit: BattleUnitState in _units:
			if (
				is_instance_valid(unit)
				and unit.side == BattleUnitState.Side.PLAYER
				and unit.is_active()
				and BattleFormationRules.is_front_slot(unit.slot_index)
			):
				targets.append(unit)
		if targets.is_empty():
			return false
	else:
		return false
	if choice == PREPARATION_RECORD_SCRIPT.Choice.FRONTLINE_BRIEFING:
		var source: RefCounted = KEYWORD_SOURCE_SCRIPT.create(
			&"brakka_rustbanner", &"scrapline_quartermaster", 1
		)
		if not is_instance_valid(source) or not targets[0].apply_advantage(source, 1):
			return false
	else:
		for target: BattleUnitState in targets:
			target.add_armor(2)
	_applied_preparation_ids[preparation_id] = true
	_preparation_record = record
	_preparation_required = false
	if is_node_ready():
		_preparation_blocker.visible = false
		_refresh_turn_ui()
	_publish_character_info()
	return true


func _on_frontline_briefing_pressed() -> void:
	if not is_instance_valid(_preparation_transaction):
		return
	_preparation_transaction.call("select_choice", PREPARATION_RECORD_SCRIPT.Choice.FRONTLINE_BRIEFING)
	_preparation_target_option.clear()
	for unit: BattleUnitState in _units:
		if unit.side == BattleUnitState.Side.ENEMY and unit.is_active():
			_preparation_target_option.add_item(unit.display_name)
			_preparation_target_option.set_item_metadata(
				_preparation_target_option.item_count - 1, unit.unit_id
			)
	_preparation_target_option.visible = true
	_preparation_confirm_button.disabled = _preparation_target_option.item_count == 0
	if _preparation_target_option.item_count > 0:
		_on_preparation_target_selected(0)


func _on_spare_plating_pressed() -> void:
	if not is_instance_valid(_preparation_transaction):
		return
	_preparation_transaction.call("select_choice", PREPARATION_RECORD_SCRIPT.Choice.SPARE_PLATING)
	_preparation_target_option.visible = false
	_preparation_confirm_button.disabled = false
	_preparation_message_label.text = "Frontline allies will begin with +2 Armor."


func _on_preparation_target_selected(index: int) -> void:
	if (
		not is_instance_valid(_preparation_transaction)
		or index < 0
		or index >= _preparation_target_option.item_count
	):
		return
	var target_id := _preparation_target_option.get_item_metadata(index) as StringName
	if _preparation_transaction.call("select_target", target_id, _units):
		_preparation_message_label.text = "Selected %s." % _preparation_target_option.get_item_text(index)


func _on_preparation_confirm_pressed() -> void:
	if not is_instance_valid(_preparation_transaction):
		return
	var identity: RefCounted = get_setup_identity()
	var result := _preparation_transaction.call("commit", identity, _units) as Dictionary
	if not bool(result.get("ok", false)):
		_preparation_message_label.text = "Preparation is stale. Choose again."
		return
	var record := result.get("record") as RefCounted
	preparation_commit_requested.emit(
		int(record.get("choice")),
		record.get("target_unit_id") as StringName,
		String(record.get("setup_key"))
	)


func is_preparation_required() -> bool:
	return _preparation_required


func is_battle_input_locked() -> bool:
	return _preparation_required


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


func get_action_records() -> Array[BattleActionRecord]:
	var snapshot: Array[BattleActionRecord] = []
	for record: BattleActionRecord in _action_records:
		snapshot.append(record.duplicate_record() as BattleActionRecord)
	return snapshot


func get_battle_outcome() -> BattleOutcome.Type:
	return _battle_outcome


func is_battle_complete() -> bool:
	return _battle_outcome != BattleOutcome.Type.IN_PROGRESS


func get_terminal_player_health_snapshot() -> Array[Dictionary]:
	var snapshot: Array[Dictionary] = []
	for entry: Dictionary in _terminal_player_health_snapshot:
		snapshot.append(entry.duplicate(true))
	return snapshot


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
			reward_selected.emit(_selected_reward)
			_refresh_reward_selection_ui()
			return


func confirm_reward_selection() -> void:
	if (
		_reward_confirmation_latched
		or is_instance_valid(_pending_recruitment_option)
		or _battle_outcome != BattleOutcome.Type.VICTORY
		or not is_instance_valid(_selected_reward)
	):
		return
	if _selected_reward.kind == BattleRewardOption.Kind.RECRUITMENT:
		_pending_recruitment_option = _selected_reward
		_suspend_reward_ui()
		recruitment_placement_requested.emit(_pending_recruitment_option)
		return
	_complete_reward(_selected_reward)


func restore_pending_recruitment(option: BattleRewardOption) -> void:
	if (
		not is_instance_valid(option)
		or not is_instance_valid(_pending_recruitment_option)
		or option != _pending_recruitment_option
		or _reward_confirmation_latched
	):
		return
	_pending_recruitment_option = null
	if is_node_ready():
		_reward_overlay.visible = true
		_reward_panel.visible = true
		_refresh_reward_selection_ui()


func complete_pending_recruitment(option: BattleRewardOption) -> void:
	if (
		not is_instance_valid(option)
		or not is_instance_valid(_pending_recruitment_option)
		or option != _pending_recruitment_option
		or _reward_confirmation_latched
	):
		return
	_pending_recruitment_option = null
	_complete_reward(option)


func _complete_reward(option: BattleRewardOption) -> void:
	_reward_confirmation_latched = true
	_clear_reward_ui(false)
	reward_confirmed.emit(option)
	exit_requested.emit()


func _suspend_reward_ui() -> void:
	if not is_node_ready():
		return
	_reward_overlay.visible = false
	_reward_panel.visible = false


func get_inspected_unit_id() -> StringName:
	return _inspected_unit_id


func inspect_unit(unit_id: StringName) -> void:
	var current_unit := get_current_unit()
	if (
		_battle_outcome != BattleOutcome.Type.IN_PROGRESS
		or not is_instance_valid(current_unit)
	):
		_clear_skill_inspector()
		return
	if unit_id != current_unit.unit_id or _inspected_unit_id == current_unit.unit_id:
		return
	_sync_skill_inspector_to_current_turn()


func _sync_skill_inspector_to_current_turn() -> void:
	if is_battle_complete() and is_instance_valid(get_unit_by_id(_inspected_unit_id)):
		_hide_skill_tooltip()
		_clear_default_action_state()
		_selected_skill_id = &""
		_skill_transaction.reset()
		_refresh_skill_inspector()
		return
	var current_unit := get_current_unit()
	if (
		_battle_outcome != BattleOutcome.Type.IN_PROGRESS
		or not is_instance_valid(current_unit)
	):
		_clear_skill_inspector()
		return
	if _inspected_unit_id != current_unit.unit_id:
		_visual_hover_skill = &""
		_selected_skill_id = &""
	_inspected_unit_id = current_unit.unit_id
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


func preview_default_attack(actor_id: StringName, target_id: StringName) -> Dictionary:
	if _preparation_required:
		return {}
	var actor: BattleUnitState = get_unit_by_id(actor_id)
	var target: BattleUnitState = get_unit_by_id(target_id)
	if not _is_valid_default_attack(actor, target):
		return {}
	return {
		&"actor_id": actor_id,
		&"target_id": target_id,
		&"revision": _battle_revision,
	}


func confirm_default_attack(
	actor_id: StringName,
	target_id: StringName,
	expected_revision: int
) -> bool:
	if _preparation_required or _action_in_progress or expected_revision != _battle_revision:
		return false
	var actor: BattleUnitState = get_unit_by_id(actor_id)
	var target: BattleUnitState = get_unit_by_id(target_id)
	if not _is_valid_default_attack(actor, target):
		return false
	var requested_damage: int = BattleDamageRules.physical_damage(
		actor.power,
		1.0,
		target.defense
	)
	if requested_damage < 1:
		return false
	_action_in_progress = true
	_refresh_character_info()
	var action_round: int = round_number
	var armor_before: int = target.get_armor()
	var result: BattleDamageResult = BattleDamageResolver.apply_direct_damage(
		actor,
		target,
		requested_damage
	)
	if not is_instance_valid(result):
		_action_in_progress = false
		_invalidate_character_info()
		return false
	var log_entry: BattleLogEntry = BattleLogEntry.new(
		_battle_log_entries.size() + 1,
		action_round,
		result
	)
	_battle_log_entries.append(log_entry)
	_append_log_control(log_entry, _battle_log_entries.size() - 1)
	_show_resolution_feedback(log_entry)
	var target_ids: Array[StringName] = [target.unit_id]
	var action_results: Array[BattleDamageResult] = [result]
	var base_damage: Dictionary[StringName, int] = {
		target.unit_id: requested_damage,
	}
	var empty_bonus: Dictionary[StringName, int] = {}
	var empty_speed_targets: Array[StringName] = []
	var committed_entry: BattleActionLogEntry = BattleActionLogEntry.new(
		_battle_action_log_entries.size() + 1,
		action_round,
		actor.unit_id,
		actor.side,
		&"default_attack",
		target_ids,
		action_results,
		base_damage,
		empty_bonus,
		empty_speed_targets,
		false
	)
	_battle_action_log_entries.append(committed_entry)
	actor.tick_skill_cooldowns()
	actor.expire_speed_modifiers_after_action()
	_battle_revision += 1
	var damage_by_target: Dictionary[StringName, int] = {
		target.unit_id: result.applied_damage,
	}
	var affected_units: Dictionary[StringName, BattleUnitState] = {
		target.unit_id: target,
	}
	var bleed_ticks: Array[RefCounted] = _resolve_bleed_ticks_for_units(actor, affected_units, action_round, damage_by_target)
	var empty_slots: Dictionary[StringName, int] = {}
	var direct_hit_by_target: Dictionary[StringName, bool] = {
		target.unit_id: result.was_direct_hit,
	}
	var empty_keyword_deltas: Array[Dictionary] = []
	_record_armor_loss(empty_keyword_deltas, target, armor_before)
	var action_record_script: Script = load("res://Scripts/Battle/battle_action_record.gd")
	var action_record: BattleActionRecord = action_record_script.new(
		BattleActionRecord.Kind.DEFAULT_ATTACK,
		actor.unit_id,
		target_ids,
		damage_by_target,
		empty_slots,
		empty_slots,
		action_round,
		_battle_revision,
		_battle_revision,
		actor.side,
		&"default_attack",
		false,
		direct_hit_by_target,
		empty_keyword_deltas,
		null,
		bleed_ticks,
		false
	) as BattleActionRecord
	if not is_instance_valid(action_record) or not action_record.is_valid():
		_action_in_progress = false
		_invalidate_character_info()
		return false
	_action_records.append(action_record)
	var resolved_outcome: BattleOutcome.Type = BattleOutcome.evaluate(_units)
	if resolved_outcome == BattleOutcome.Type.IN_PROGRESS:
		_advance_after_action(actor.unit_id)
	else:
		_complete_battle(resolved_outcome)
	_action_in_progress = false
	_publish_character_info()
	_refresh_turn_ui()
	return true


func _is_valid_default_attack(actor: BattleUnitState, target: BattleUnitState) -> bool:
	var current: BattleUnitState = get_current_unit()
	return (
		not is_battle_complete()
		and is_instance_valid(actor)
		and actor.is_active()
		and (actor.side == BattleUnitState.Side.PLAYER or _executing_enemy_action)
		and is_instance_valid(current)
		and current.unit_id == actor.unit_id
		and is_instance_valid(target)
		and target.is_active()
		and target.side != actor.side
	)


func preview_formation_move(
	actor_id: StringName,
	destination_slot: int,
	default_swap: bool
) -> Dictionary:
	if _preparation_required:
		return {}
	var actor: BattleUnitState = get_unit_by_id(actor_id)
	if not _is_valid_move_actor(actor, destination_slot):
		return {}
	var occupant: BattleUnitState = _allied_occupant_at(
		actor.side,
		destination_slot,
		actor.unit_id
	)
	if default_swap and not is_instance_valid(occupant):
		return {}
	return {
		&"actor_id": actor.unit_id,
		&"source_slot": actor.slot_index,
		&"destination_slot": destination_slot,
		&"occupant_id": occupant.unit_id if is_instance_valid(occupant) else &"",
		&"revision": _battle_revision,
		&"default_swap": default_swap,
	}


func confirm_formation_move(
	actor_id: StringName,
	expected_source_slot: int,
	destination_slot: int,
	expected_occupant_id: StringName,
	expected_revision: int,
	default_swap: bool
) -> bool:
	if _preparation_required or _action_in_progress or expected_revision != _battle_revision:
		return false
	var actor: BattleUnitState = get_unit_by_id(actor_id)
	if (
		not _is_valid_move_actor(actor, destination_slot)
		or actor.slot_index != expected_source_slot
	):
		return false
	var occupant: BattleUnitState = _allied_occupant_at(
		actor.side,
		destination_slot,
		actor.unit_id
	)
	var occupant_id: StringName = occupant.unit_id if is_instance_valid(occupant) else &""
	if occupant_id != expected_occupant_id or (default_swap and not is_instance_valid(occupant)):
		return false
	_action_in_progress = true
	_refresh_character_info()
	var slot_before: Dictionary[StringName, int] = {
		actor.unit_id: actor.slot_index,
	}
	var slot_after: Dictionary[StringName, int] = {
		actor.unit_id: destination_slot,
	}
	var target_ids: Array[StringName] = []
	if is_instance_valid(occupant):
		target_ids.append(occupant.unit_id)
		slot_before[occupant.unit_id] = occupant.slot_index
		slot_after[occupant.unit_id] = actor.slot_index
		occupant.slot_index = actor.slot_index
	actor.slot_index = destination_slot
	actor.tick_skill_cooldowns()
	actor.expire_speed_modifiers_after_action()
	_battle_revision += 1
	var empty_damage: Dictionary[StringName, int] = {}
	var action_record_script: Script = load("res://Scripts/Battle/battle_action_record.gd")
	var action_record: BattleActionRecord = action_record_script.new(
		BattleActionRecord.Kind.DEFAULT_SWAP
		if default_swap
		else BattleActionRecord.Kind.FORMATION_MOVE,
		actor.unit_id,
		target_ids,
		empty_damage,
		slot_before,
		slot_after,
		round_number,
		_battle_revision
	) as BattleActionRecord
	if not is_instance_valid(action_record) or not action_record.is_valid():
		actor.slot_index = slot_before[actor.unit_id]
		if is_instance_valid(occupant):
			occupant.slot_index = slot_before[occupant.unit_id]
		_battle_revision -= 1
		_action_in_progress = false
		_invalidate_character_info()
		return false
	_action_records.append(action_record)
	var empty_results: Array[BattleDamageResult] = []
	var empty_speed_targets: Array[StringName] = []
	var movement_skill_id: StringName = &"default_swap" if default_swap else &"formation_move"
	var committed_entry: BattleActionLogEntry = BattleActionLogEntry.new(
		_battle_action_log_entries.size() + 1,
		round_number,
		actor.unit_id,
		actor.side,
		movement_skill_id,
		target_ids,
		empty_results,
		empty_damage,
		empty_damage,
		empty_speed_targets,
		false
	)
	_battle_action_log_entries.append(committed_entry)
	_advance_after_action(actor.unit_id)
	_action_in_progress = false
	_publish_character_info()
	_refresh_turn_ui()
	return true


func _is_valid_move_actor(actor: BattleUnitState, destination_slot: int) -> bool:
	var current: BattleUnitState = get_current_unit()
	return (
		not is_battle_complete()
		and is_instance_valid(actor)
		and actor.is_active()
		and actor.side == BattleUnitState.Side.PLAYER
		and is_instance_valid(current)
		and current.unit_id == actor.unit_id
		and BattleFormationRules.is_move_one(actor.slot_index, destination_slot)
	)


func _allied_occupant_at(
	side: int,
	slot_index: int,
	excluded_unit_id: StringName
) -> BattleUnitState:
	for unit: BattleUnitState in _units:
		if (
			is_instance_valid(unit)
			and unit.unit_id != excluded_unit_id
			and unit.side == side
			and unit.slot_index == slot_index
			and unit.is_active()
		):
			return unit
	return null


func get_skill_presentation_snapshot() -> Dictionary:
	return _skill_transaction.presentation_snapshot()


func notify_authoritative_battle_change(increment_revision: bool = true) -> void:
	_publish_character_info()
	if is_node_ready():
		_render_units()
		_refresh_turn_order_ribbon()
	if increment_revision:
		_battle_revision += 1
	if (
		_skill_transaction.state != BattleSkillTransaction.State.TARGETING
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
		get_committed_action_history_snapshot(),
		_skill_transaction.declared_move_path,
		get_action_records()
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
	if _preparation_required:
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
		get_committed_action_history_snapshot(),
		_executing_enemy_action
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


func set_skill_move_path(path: Array[int]) -> bool:
	var accepted: bool = _skill_transaction.set_declared_move_path(
		path,
		_skill_transaction.generation
	)
	_render_skill_transaction()
	return accepted


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
	if _preparation_required:
		return false
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
		get_committed_action_history_snapshot(),
		_skill_transaction.declared_move_path,
		get_action_records(),
		_executing_enemy_action
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
	for operation: RefCounted in plan.keyword_operations:
		var target: BattleUnitState = get_unit_by_id(operation.get("target_id"))
		if not is_instance_valid(target) or not target.is_active():
			return false
	var movement_occupant: BattleUnitState = null
	if not plan.movement_path.is_empty():
		if (
			plan.movement_unit_id != actor.unit_id
			or plan.movement_path[0] != actor.slot_index
			or not _is_valid_move_actor(actor, plan.movement_path[1])
		):
			return false
		movement_occupant = _allied_occupant_at(actor.side, plan.movement_path[1], actor.unit_id)
	_action_in_progress = true
	_refresh_character_info()
	var action_round: int = round_number
	var action_damage_results: Array[BattleDamageResult] = []
	var action_base_damage_by_target: Dictionary[StringName, int] = {}
	var action_combo_bonus_damage_by_target: Dictionary[StringName, int] = {}
	var action_speed_target_ids: Array[StringName] = []
	var keyword_deltas: Array[Dictionary] = []
	var direct_hit_by_target: Dictionary[StringName, bool] = {}
	var affected_units: Dictionary[StringName, BattleUnitState] = {}
	var advantage_consumed: RefCounted = null
	if (plan.consume_advantage or is_instance_valid(plan.advantage_rider)) and not plan.damage_operations.is_empty():
		var marked_target: BattleUnitState = get_unit_by_id(plan.damage_operations[0].get("target_id", &""))
		if is_instance_valid(marked_target):
			advantage_consumed = marked_target.consume_advantage(action_round)
			if is_instance_valid(advantage_consumed) and is_instance_valid(plan.advantage_rider):
				_apply_keyword_operation(plan.advantage_rider, action_round, keyword_deltas, false)
	for operation: Dictionary in plan.damage_operations:
		var target: BattleUnitState = get_unit_by_id(operation["target_id"])
		var target_id: StringName = operation[&"target_id"]
		action_base_damage_by_target[target_id] = int(operation[&"base_damage"])
		action_combo_bonus_damage_by_target[target_id] = int(operation[&"combo_bonus_damage"])
		affected_units[target_id] = target
		var armor_before: int = target.get_armor()
		target.spend_armor(int(operation.get(&"armor_strip", 0)))
		var result: BattleDamageResult = BattleDamageResolver.apply_direct_damage(
			actor,
			target,
			int(operation[&"total_requested_damage"]),
			bool(operation.get(&"ignore_armor", false))
		)
		_record_armor_loss(keyword_deltas, target, armor_before)
		if not is_instance_valid(result):
			_action_in_progress = false
			_invalidate_character_info()
			return false
		direct_hit_by_target[target_id] = result.was_direct_hit
		action_damage_results.append(result)
		var entry := BattleLogEntry.new(
			_battle_log_entries.size() + 1,
			action_round,
			result
		)
		_battle_log_entries.append(entry)
		_append_log_control(entry, _battle_log_entries.size() - 1)
		_show_resolution_feedback(entry)
		if result.was_direct_hit:
			var follow_up_source: RefCounted = target.get_snared_follow_up_source(action_round)
			var follow_up_owner: BattleUnitState = null
			if is_instance_valid(follow_up_source):
				follow_up_owner = get_unit_by_id(follow_up_source.get("source_unit_id"))
			if is_instance_valid(follow_up_owner) and follow_up_owner.side == actor.side:
				follow_up_source = target.consume_snared_follow_up(action_round)
				var follow_up_operation: RefCounted = BattleKeywordOperation.create(
					BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
					target.unit_id,
					0,
					1,
					follow_up_source
				)
				_apply_keyword_operation(follow_up_operation, action_round, keyword_deltas, false)
	var slot_before: Dictionary[StringName, int] = {}
	var slot_after: Dictionary[StringName, int] = {}
	if not plan.movement_path.is_empty():
		slot_before[actor.unit_id] = actor.slot_index
		slot_after[actor.unit_id] = plan.movement_path[1]
		if is_instance_valid(movement_occupant):
			slot_before[movement_occupant.unit_id] = movement_occupant.slot_index
			slot_after[movement_occupant.unit_id] = actor.slot_index
			movement_occupant.slot_index = actor.slot_index
		actor.slot_index = plan.movement_path[1]
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
	for operation: RefCounted in plan.keyword_operations:
		_apply_keyword_operation(operation, action_round, keyword_deltas, false)
	if plan.cooldown_actions > 0:
		actor.set_skill_cooldown(plan.skill_id, plan.cooldown_actions)
	var excluded_cooldowns: Array[StringName] = []
	if plan.cooldown_actions > 0:
		excluded_cooldowns.append(plan.skill_id)
	actor.tick_skill_cooldowns(excluded_cooldowns)
	actor.expire_speed_modifiers_after_action(new_actor_speed_sources)
	var damage_by_target: Dictionary[StringName, int] = {}
	for result: BattleDamageResult in action_damage_results:
		damage_by_target[result.receiver_id] = result.applied_damage
	var bleed_ticks: Array[RefCounted] = _resolve_bleed_ticks_for_units(actor, affected_units, action_round, damage_by_target)
	var next_revision: int = _battle_revision + 1
	var action_record_script: Script = load("res://Scripts/Battle/battle_action_record.gd")
	var action_record: BattleActionRecord = action_record_script.new(
		BattleActionRecord.Kind.SKILL,
		actor.unit_id,
		plan.target_ids,
		damage_by_target,
		slot_before,
		slot_after,
		action_round,
		next_revision,
		next_revision,
		actor.side,
		plan.skill_id,
		not plan.movement_path.is_empty(),
		direct_hit_by_target,
		keyword_deltas,
		advantage_consumed,
		bleed_ticks,
		false
	) as BattleActionRecord
	if not is_instance_valid(action_record) or not action_record.is_valid():
		_action_in_progress = false
		_invalidate_character_info()
		return false
	_dispatch_passive_reactions(action_record, action_round, keyword_deltas)
	var effect_highlight_colors := _collect_effect_highlight_colors(keyword_deltas)
	for target_id: StringName in action_speed_target_ids:
		effect_highlight_colors[target_id] = EFFECT_POSITIVE_BORDER_COLOR
	_set_effect_highlights(effect_highlight_colors)
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
	_battle_revision = next_revision
	_action_records.append(action_record)
	var resolved_outcome: BattleOutcome.Type = BattleOutcome.evaluate(_units)
	if resolved_outcome == BattleOutcome.Type.IN_PROGRESS and plan.advance_turn:
		_advance_after_action(actor.unit_id)
	else:
		_complete_battle(resolved_outcome)
	_action_in_progress = false
	_publish_character_info()
	_refresh_turn_ui()
	return true


func _resolve_current_action_start_reactions() -> void:
	if is_battle_complete():
		return
	var actor: BattleUnitState = get_current_unit()
	if not is_instance_valid(actor) or not actor.is_active():
		return
	var dispatcher_script: Script = load("res://Scripts/Battle/battle_reaction_dispatcher.gd") as Script
	var candidates: Array = dispatcher_script.call(
		"collect_action_start_reactions",
		actor,
		_units,
		round_number
	)
	for candidate: Dictionary in candidates:
		_resolve_action_start_candidate(candidate)


func _resolve_action_start_candidate(candidate: Dictionary) -> void:
	var owner_id: StringName = candidate.get("owner_id", &"")
	var target_id: StringName = candidate.get("target_id", &"")
	var definition: RefCounted = candidate.get("definition") as RefCounted
	var owner: BattleUnitState = get_unit_by_id(owner_id)
	if not is_instance_valid(owner) or not is_instance_valid(definition):
		return
	if int(definition.get("trigger")) != BattleReactionDefinition.Trigger.ACTION_START:
		return
	var passive_skill: CharacterSkill = _find_skill(owner, definition.get("passive_skill_id"))
	if not is_instance_valid(passive_skill):
		return
	var dispatcher_script: Script = load("res://Scripts/Battle/battle_reaction_dispatcher.gd") as Script
	if (
		target_id.is_empty()
		or not dispatcher_script.call("is_action_start_target_current", owner, target_id, _units)
	):
		_append_action_start_message("%s found no active enemy." % passive_skill.display_name)
		return
	var operation: RefCounted = definition.get("operation") as RefCounted
	var keyword_deltas: Array[Dictionary] = []
	if (
		not is_instance_valid(operation)
		or int(operation.get("kind")) != BattleKeywordOperation.Kind.APPLY_ADVANTAGE
		or not _apply_keyword_operation(operation, round_number, keyword_deltas, true)
	):
		_append_action_start_message("%s found no active enemy." % passive_skill.display_name)
		return
	var target: BattleUnitState = get_unit_by_id(target_id)
	if not is_instance_valid(target):
		_append_action_start_message("%s found no active enemy." % passive_skill.display_name)
		return
	_battle_revision += 1
	_append_action_start_message(
		"%s's %s applied Advantage to %s." % [
			owner.display_name,
			passive_skill.display_name,
			target.display_name,
		]
	)


func _append_action_start_message(message_text: String) -> void:
	var entry: BattleLogEntry = BattleLogEntry.message(
		_battle_log_entries.size() + 1,
		round_number,
		message_text
	)
	if not is_instance_valid(entry):
		return
	_battle_log_entries.append(entry)
	if is_node_ready():
		_append_log_control(entry, _battle_log_entries.size() - 1)


func _apply_keyword_operation(
	operation: RefCounted,
	action_round: int,
	keyword_deltas: Array[Dictionary],
	from_reaction: bool
) -> bool:
	if not is_instance_valid(operation):
		return false
	var target: BattleUnitState = get_unit_by_id(operation.get("target_id"))
	if not is_instance_valid(target) or not target.is_active():
		return false
	var applied: bool = false
	match int(operation.get("kind")):
		BattleKeywordOperation.Kind.ADD_ARMOR:
			var armor_added: int = target.add_armor(int(operation.get("magnitude")))
			applied = armor_added >= 0
			keyword_deltas.append(_keyword_delta(operation, target.unit_id, armor_added, from_reaction))
		BattleKeywordOperation.Kind.APPLY_ADVANTAGE:
			applied = target.apply_advantage(operation.get("source") as RefCounted, action_round + max(1, int(operation.get("duration"))) - 1)
			if applied:
				keyword_deltas.append(_keyword_delta(operation, target.unit_id, 1, from_reaction))
		BattleKeywordOperation.Kind.APPLY_SNARED:
			applied = target.apply_snared(
				operation.get("source") as RefCounted,
				action_round + max(1, int(operation.get("duration"))) - 1,
				bool(operation.get("arms_snared_follow_up"))
			)
			if applied:
				keyword_deltas.append(_keyword_delta(operation, target.unit_id, 1, from_reaction))
		BattleKeywordOperation.Kind.APPLY_BLEED:
			applied = target.apply_bleed(operation.get("source") as RefCounted, max(1, int(operation.get("duration"))))
			if applied:
				keyword_deltas.append(_keyword_delta(operation, target.unit_id, 1, from_reaction))
		BattleKeywordOperation.Kind.REDUCE_COOLDOWN:
			var remaining: int = target.reduce_skill_cooldown(operation.get("affected_skill_id"), int(operation.get("magnitude")))
			applied = true
			keyword_deltas.append(_keyword_delta(operation, target.unit_id, remaining, from_reaction))
		_:
			applied = false
	return applied


func _keyword_delta(
	operation: RefCounted,
	target_id: StringName,
	value: int,
	from_reaction: bool
) -> Dictionary:
	return {
		&"kind": int(operation.get("kind")),
		&"target_id": target_id,
		&"value": value,
		&"affected_skill_id": operation.get("affected_skill_id"),
		&"from_reaction": from_reaction,
	}


func _resolve_bleed_ticks_for_units(
	actor: BattleUnitState,
	affected_units: Dictionary[StringName, BattleUnitState],
	action_round: int,
	damage_by_target: Dictionary[StringName, int]
) -> Array[RefCounted]:
	var ticks: Array[RefCounted] = []
	for target: BattleUnitState in affected_units.values():
		if not is_instance_valid(target) or not target.is_active():
			continue
		for tick: RefCounted in target.resolve_bleed_after_committed_action():
			var source_unit: BattleUnitState = _unit_for_keyword_source(tick.get("source") as RefCounted)
			if not is_instance_valid(source_unit) or source_unit.side == target.side:
				source_unit = actor
			var status_result: BattleDamageResult = BattleDamageResolver.apply_status_damage(source_unit, target, int(tick.call("tick_damage")))
			if not is_instance_valid(status_result):
				continue
			damage_by_target[target.unit_id] = int(damage_by_target.get(target.unit_id, 0)) + status_result.applied_damage
			ticks.append(tick)
	return ticks


func _unit_for_keyword_source(source: RefCounted) -> BattleUnitState:
	if not is_instance_valid(source):
		return null
	return get_unit_by_id(source.get("source_unit_id"))


func _dispatch_passive_reactions(
	action_record: BattleActionRecord,
	action_round: int,
	keyword_deltas: Array[Dictionary]
) -> void:
	var dispatcher_script: Script = load("res://Scripts/Battle/battle_reaction_dispatcher.gd")
	if not is_instance_valid(dispatcher_script):
		return
	var reactions: Array[RefCounted] = dispatcher_script.call("collect_reactions", action_record, _units, action_round, 0)
	for reaction: RefCounted in reactions:
		var reaction_operation: RefCounted = reaction.get("operation") as RefCounted
		_apply_keyword_operation(reaction_operation, action_round, keyword_deltas, true)


func _action_has_combo_bonus(bonus_by_target: Dictionary[StringName, int]) -> bool:
	for bonus: int in bonus_by_target.values():
		if bonus > 0:
			return true
	return false


func _render_skill_transaction() -> void:
	if not is_node_ready():
		return
	_refresh_action_bar()


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
	if _preparation_required or is_battle_complete() or _action_in_progress:
		return
	var attacker: BattleUnitState = get_current_unit()
	var receiver: BattleUnitState = BattleTargetSelector.find_closest_enemy(attacker, _units)
	if not is_instance_valid(attacker) or not is_instance_valid(receiver):
		_refresh_turn_ui()
		return
	_action_in_progress = true
	_refresh_character_info()
	var action_round: int = round_number
	var result: BattleDamageResult = BattleDamageResolver.apply_damage(
		attacker,
		receiver,
		BattleDamageResolver.DEBUG_DAMAGE
	)
	if not is_instance_valid(result):
		_action_in_progress = false
		_invalidate_character_info()
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
	_publish_character_info()
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
	if _preparation_required or is_battle_complete() or _turn_queue.is_empty():
		return
	_clear_turn_order_preview()
	_clear_default_action_state()
	_current_turn_index += 1
	if _current_turn_index >= _turn_queue.size():
		var completed_round: int = round_number
		round_number += 1
		_expire_round_modifiers(completed_round)
		_turn_queue = BattleTurnQueue.build(_units)
		_current_turn_index = 0
	if _effect_highlight_turns_remaining > 0:
		_effect_highlight_turns_remaining -= 1
		if _effect_highlight_turns_remaining == 0:
			_clear_effect_highlights()
	_battle_revision += 1
	_resolve_current_action_start_reactions()
	notify_authoritative_battle_change(false)
	_refresh_turn_ui()


func get_player_slots() -> Array[Control]:
	return _get_control_children(_player_formation)


func get_enemy_slots() -> Array[Control]:
	return _get_control_children(_enemy_formation)


func _create_debug_units() -> Array[BattleUnitState]:
	var catalog: Script = load("res://Scripts/Battle/debug_encounter_catalog.gd")
	var units: Array[BattleUnitState] = RunRoster.new().create_battle_units()
	units.append_array(catalog.create_enemies(debug_encounter_index))
	return units


func _complete_battle(outcome: BattleOutcome.Type) -> void:
	if is_battle_complete() or outcome == BattleOutcome.Type.IN_PROGRESS:
		return
	close_character_info(false)
	_battle_outcome = outcome
	_refresh_turn_order_ribbon()
	_terminal_player_health_snapshot.clear()
	for unit: BattleUnitState in _configured_player_units:
		if is_instance_valid(unit):
			_terminal_player_health_snapshot.append({
				"character_id": unit.unit_id,
				"final_hp": unit.current_hp,
				"max_hp": unit.max_hp,
			})
	_turn_queue.clear()
	_current_turn_index = 0
	_clear_effect_highlights()
	for unit: BattleUnitState in _units:
		if is_instance_valid(unit):
			unit.clear_battle_local_state()
	battle_completed.emit(_battle_outcome)
	if _battle_outcome == BattleOutcome.Type.VICTORY:
		_show_victory_rewards()
	else:
		_clear_reward_ui()


func _show_victory_rewards() -> void:
	_clear_reward_ui()
	_reward_options = (
		_configured_reward_options.duplicate()
		if _has_configured_reward_options
		else BattleRewardCatalog.get_options_for(encounter_type)
	)
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
	_pending_recruitment_option = null
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
	_clear_turn_order_preview()
	_clear_default_action_state()
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
		_resolve_current_action_start_reactions()
		return
	_current_turn_index = attacker_index + 1
	if _current_turn_index >= _turn_queue.size():
		var completed_round: int = round_number
		round_number += 1
		_expire_round_modifiers(completed_round)
		_current_turn_index = 0
	if _effect_highlight_turns_remaining > 0:
		_effect_highlight_turns_remaining -= 1
		if _effect_highlight_turns_remaining == 0:
			_clear_effect_highlights()
	_resolve_current_action_start_reactions()


func _expire_round_modifiers(completed_round: int) -> void:
	for unit: BattleUnitState in _units:
		if is_instance_valid(unit):
			unit.expire_speed_modifiers_for_round(completed_round)
			unit.clear_round_keywords(completed_round)


func _get_control_children(formation: Container) -> Array[Control]:
	var slots: Array[Control] = []
	var pending: Array[Node] = [formation]
	while not pending.is_empty():
		var candidate: Node = pending.pop_back()
		if candidate is Control and candidate.has_meta("slot_index"):
			slots.append(candidate as Control)
		else:
			for child: Node in candidate.get_children():
				pending.append(child)
	slots.sort_custom(func(a: Control, b: Control) -> bool:
		return int(a.get_meta("slot_index")) < int(b.get_meta("slot_index")))
	return slots


func _assign_slot_metadata(formation: Container, side: String) -> void:
	for slot: Control in _get_control_children(formation):
		var slot_index := int(slot.get_meta("slot_index", -1))
		assert(slot_index >= 0 and slot_index < SIDE_SLOT_COUNT)
		slot.set_meta("side", side)
		slot.set_meta("slot_index", slot_index)
		slot.set_meta("is_current_unit", false)
		slot.set_meta("highlight_role", &"neutral")
		slot.set_meta("unit_id", &"")
		slot.focus_mode = Control.FOCUS_ALL
		slot.focus_entered.connect(_on_slot_focus_entered.bind(slot))
		slot.focus_exited.connect(_on_slot_focus_exited.bind(slot))
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
	if event is InputEventKey and _slot_is_info_obscured(slot):
		return
	var click := event as InputEventMouseButton
	var key := event as InputEventKey
	if _info_modal_blocked():
		return
	if is_instance_valid(click) and click.button_index == MOUSE_BUTTON_RIGHT and click.pressed:
		slot.accept_event()
		open_character_info(slot.get_meta("unit_id", &""))
		return
	if is_instance_valid(key) and key.is_action_pressed("inspect_character") and not key.echo and slot.has_focus():
		slot.accept_event()
		open_character_info(slot.get_meta("unit_id", &""), true)
		return
	var activating: bool = (is_instance_valid(click) and click.button_index == MOUSE_BUTTON_LEFT and click.pressed) or (is_instance_valid(key) and key.is_action_pressed("ui_accept") and not key.echo)
	if not activating or _preparation_required or is_battle_complete() or _action_in_progress:
		return
	slot.accept_event()
	var unit_id: StringName = slot.get_meta("unit_id", &"")
	if _default_action_mode != DefaultActionMode.NONE:
		_select_default_action_target(unit_id, int(slot.get_meta("slot_index", -1)))
	elif not unit_id.is_empty():
		if _skill_transaction.state == BattleSkillTransaction.State.TARGETING:
			select_skill_target(unit_id)
		else:
			inspect_unit(unit_id)


func _on_slot_mouse_entered(slot: Control) -> void:
	_pointer_target_slot = slot
	_refresh_target_hover()


func _on_slot_mouse_exited(slot: Control) -> void:
	if _pointer_target_slot == slot:
		_pointer_target_slot = null
		_refresh_target_hover()


func _on_default_attack_pressed() -> void:
	_begin_default_action(DefaultActionMode.ATTACK)


func _on_default_swap_pressed() -> void:
	_begin_default_action(DefaultActionMode.SWAP)


func _begin_default_action(mode: DefaultActionMode) -> void:
	if not _can_current_player_act():
		return
	if _visual_default_targets(mode).is_empty():
		return
	_selected_skill_id = &""
	_hide_skill_tooltip()
	_skill_transaction.reset()
	_render_skill_transaction()
	_default_action_mode = mode
	_default_action_preview.clear()
	_default_action_message = (
		"Select an active enemy."
		if mode == DefaultActionMode.ATTACK
		else "Select an adjacent active ally."
	)
	_render_default_action()


func _select_default_action_target(unit_id: StringName, slot_index: int) -> void:
	var current: BattleUnitState = get_current_unit()
	if not is_instance_valid(current):
		_cancel_default_action()
		return
	if _default_action_mode == DefaultActionMode.ATTACK:
		_default_action_preview = preview_default_attack(current.unit_id, unit_id)
	else:
		_default_action_preview = preview_formation_move(current.unit_id, slot_index, true)
	if _default_action_preview.is_empty():
		_default_action_message = "That target is not valid for this action."
	else:
		_default_action_message = "Review the selected target."
	_render_default_action()


func _confirm_default_action() -> void:
	if _default_action_preview.is_empty():
		return
	var confirmed: bool = false
	if _default_action_mode == DefaultActionMode.ATTACK:
		confirmed = confirm_default_attack(
			_default_action_preview.get(&"actor_id", &""),
			_default_action_preview.get(&"target_id", &""),
			int(_default_action_preview.get(&"revision", -1))
		)
	elif _default_action_mode == DefaultActionMode.SWAP:
		confirmed = confirm_formation_move(
			_default_action_preview.get(&"actor_id", &""),
			int(_default_action_preview.get(&"source_slot", -1)),
			int(_default_action_preview.get(&"destination_slot", -1)),
			_default_action_preview.get(&"occupant_id", &""),
			int(_default_action_preview.get(&"revision", -1)),
			true
		)
	if confirmed:
		_cancel_default_action()
	else:
		_default_action_preview.clear()
		_default_action_message = "Battle state changed; choose the action again."
		_render_default_action()


func _cancel_default_action() -> void:
	_clear_default_action_state()
	_render_default_action()


func _clear_default_action_state() -> void:
	_default_action_mode = DefaultActionMode.NONE
	_default_action_preview.clear()


func _can_current_player_act() -> bool:
	var current: BattleUnitState = get_current_unit()
	return (
		is_instance_valid(current)
		and current.is_active()
		and current.side == BattleUnitState.Side.PLAYER
		and not is_battle_input_locked()
	)


func _has_adjacent_active_ally(actor: BattleUnitState) -> bool:
	if not is_instance_valid(actor):
		return false
	for unit: BattleUnitState in _units:
		if (
			is_instance_valid(unit)
			and unit.unit_id != actor.unit_id
			and unit.side == actor.side
			and unit.is_active()
			and BattleFormationRules.is_move_one(actor.slot_index, unit.slot_index)
		):
			return true
	return false


func _render_default_action() -> void:
	if not is_node_ready():
		return
	if _default_action_mode == DefaultActionMode.NONE:
		_default_action_message = (
			"Choose an action for the current character."
			if _can_current_player_act()
			else "Default actions are unavailable for the current turn."
		)
	_refresh_action_bar()



func _refresh_context() -> void:
	var catalog: Script = load("res://Scripts/Battle/debug_encounter_catalog.gd")
	var label: String = "Battle" if encounter_type.is_empty() else "%s Battle" % encounter_type.capitalize()
	_encounter_type_label.text = "%s — %s" % [label, catalog.get_encounter_name(debug_encounter_index)]


func _get_turn_order_entries() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var current: BattleUnitState = get_current_unit()
	if is_battle_complete() or is_preparation_required():
		return rows
	if not is_instance_valid(current) or not current.is_active():
		return rows
	var reached_current: bool = false
	for unit: BattleUnitState in get_turn_queue():
		if not is_instance_valid(unit):
			continue
		if unit.unit_id == current.unit_id:
			reached_current = true
		if not reached_current or not unit.is_active():
			continue
		if not is_instance_valid(get_unit_by_id(unit.unit_id)):
			continue
		rows.append({"unit_id": unit.unit_id, "display_name": unit.display_name,
			"side": unit.side, "ordinal": rows.size() + 1})
	return rows


func _refresh_turn_order_ribbon() -> void:
	if not is_node_ready():
		return
	var rows: Array[Dictionary] = _get_turn_order_entries()
	var current_id: StringName = rows[0]["unit_id"] if not rows.is_empty() else &""
	var context: String = "%s:%d:%s:%s" % [
		current_id, round_number, is_preparation_required(), is_battle_complete()]
	if context != _turn_order_context:
		_clear_turn_order_preview()
		_turn_order_context = context
	_turn_order_ribbon.render_entries(rows, current_id)
	_turn_order_preview_id = _turn_order_ribbon.get_preview_unit_id()
	_apply_turn_order_preview()


func _on_turn_order_preview_changed(unit_id: StringName) -> void:
	_turn_order_preview_id = &""
	for row: Dictionary in _get_turn_order_entries():
		if row["unit_id"] == unit_id:
			_turn_order_preview_id = unit_id
			break
	_apply_turn_order_preview()


func _apply_turn_order_preview() -> void:
	_refresh_visual_states()


func _clear_turn_order_preview() -> void:
	_visual_hover_skill = &""
	_pointer_target_slot = null
	_focused_target_slot = null
	_turn_order_preview_id = &""
	if is_node_ready():
		_turn_order_ribbon.clear_preview()
		_apply_turn_order_preview()


func _refresh_turn_ui() -> void:
	_round_label.text = "Round %d" % round_number
	_render_default_action()
	_render_units()
	_sync_skill_inspector_to_current_turn()
	_refresh_result_ui()
	_refresh_turn_order_ribbon()
	if is_battle_complete():
		_current_unit_label.text = BattleOutcome.get_display_text(_battle_outcome)
		_refresh_debug_drawer()
		_refresh_highlights()
		return
	var current_unit := get_current_unit()
	if not is_instance_valid(current_unit):
		_current_unit_label.text = "No active units"
		_refresh_debug_drawer()
		_refresh_highlights()
		return
	_current_unit_label.text = "%s | Speed %d | HP %d/%d" % [
		current_unit.display_name,
		current_unit.get_effective_speed(),
		current_unit.current_hp,
		current_unit.max_hp,
	]
	_refresh_debug_drawer()
	_refresh_highlights()


func _refresh_result_ui() -> void:
	var complete := is_battle_complete()
	_battle_result_panel.visible = complete
	_battle_result_label.text = BattleOutcome.get_display_text(_battle_outcome)


func _render_units() -> void:
	for slot: Control in get_player_slots() + get_enemy_slots():
		slot.render_empty(String(slot.get_meta("side")), int(slot.get_meta("slot_index")))
	for unit: BattleUnitState in _units:
		if not is_instance_valid(unit):
			continue
		var slot := _get_slot_for_unit(unit)
		if is_instance_valid(slot):
			slot.render_unit(unit, round_number)
	_apply_turn_order_preview()
	_update_info_slot_focus()


func _refresh_skill_inspector() -> void:
	var unit := get_unit_by_id(_inspected_unit_id)
	if not is_instance_valid(unit):
		_clear_skill_inspector()
		return
	var selection_owned: bool = false
	for skill: CharacterSkill in unit.skills:
		selection_owned = selection_owned or skill.skill_id == _selected_skill_id
	if not selection_owned:
		_selected_skill_id = &""
	_refresh_action_bar()



func _refresh_skill_selection() -> void:
	_refresh_action_bar()



func _hide_skill_tooltip() -> void:
	_visual_hover_skill = &""
	if is_node_ready():
		_action_bar.clear_details()



func _clear_skill_inspector() -> void:
	_hide_skill_tooltip()
	_inspected_unit_id = &""
	_selected_skill_id = &""
	if not is_node_ready():
		return
	_skill_transaction.reset()
	_render_skill_transaction()



func _refresh_highlights() -> void:
	_reset_slot_highlights()
	if _hovered_log_index >= 0 and _hovered_log_index < _battle_log_entries.size():
		_apply_entry_feedback(_battle_log_entries[_hovered_log_index])
	elif is_instance_valid(_transient_log_entry):
		_apply_entry_feedback(_transient_log_entry)
	elif not is_battle_complete():
		var current_slot := _get_slot_for_unit(get_current_unit())
		if is_instance_valid(current_slot):
			_apply_current_slot_highlight(current_slot)
		for target_id: StringName in _effect_highlight_target_colors.keys():
			var target_slot := _get_slot_for_unit(get_unit_by_id(target_id))
			if is_instance_valid(target_slot):
				var effect_overlay := _get_or_create_effect_slot_border_overlay(target_slot)
				effect_overlay.add_theme_stylebox_override("panel", _effect_border_style(_effect_highlight_target_colors[target_id]))
				effect_overlay.visible = true
	_refresh_visual_states()


func _reset_slot_highlights() -> void:
	for slot: Control in get_player_slots() + get_enemy_slots():
		slot.self_modulate = NEUTRAL_SLOT_COLOR
		slot.set_meta("is_current_unit", false)
		slot.set_meta("highlight_role", &"neutral")
		var border_overlay := slot.get_node_or_null("CurrentUnitBorderOverlay") as Panel
		if is_instance_valid(border_overlay):
			border_overlay.visible = false
		var effect_overlay := slot.get_node_or_null("EffectStatusBorderOverlay") as Panel
		if is_instance_valid(effect_overlay):
			effect_overlay.visible = false
		var damage_label := slot.get_node("UnitInfo/DamageFeedbackLabel") as Label
		damage_label.text = ""
		damage_label.visible = false


func _apply_current_slot_highlight(slot: Control) -> void:
	slot.self_modulate = Color.WHITE
	slot.set_meta("is_current_unit", true)
	slot.set_meta("highlight_role", &"current")
	var border_overlay := _get_or_create_current_slot_border_overlay(slot)
	border_overlay.visible = true


func _get_or_create_current_slot_border_overlay(slot: Control) -> Panel:
	var existing := slot.get_node_or_null("CurrentUnitBorderOverlay") as Panel
	if is_instance_valid(existing):
		return existing
	var overlay := Panel.new()
	overlay.name = "CurrentUnitBorderOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 11
	overlay.visible = false
	var frame: StyleBoxFlat = _current_slot_border_style()
	var slot_style: StyleBox = slot.get_theme_stylebox("panel")
	frame.expand_margin_left = slot_style.get_content_margin(SIDE_LEFT)
	frame.expand_margin_right = slot_style.get_content_margin(SIDE_RIGHT)
	frame.expand_margin_top = slot_style.get_content_margin(SIDE_TOP)
	frame.expand_margin_bottom = slot_style.get_content_margin(SIDE_BOTTOM)
	overlay.add_theme_stylebox_override("panel", frame)
	slot.add_child(overlay)
	return overlay


func _get_or_create_effect_slot_border_overlay(slot: Control) -> Panel:
	var existing := slot.get_node_or_null("EffectStatusBorderOverlay") as Panel
	if is_instance_valid(existing):
		return existing
	var overlay := Panel.new()
	overlay.name = "EffectStatusBorderOverlay"
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 12
	overlay.visible = false
	slot.add_child(overlay)
	return overlay


func _current_slot_border_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.border_color = CURRENT_SLOT_BORDER_COLOR
	style.set_border_width_all(CURRENT_SLOT_BORDER_WIDTH)
	style.bg_color = Color.TRANSPARENT
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _effect_border_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.border_color = border_color
	style.set_border_width_all(CURRENT_SLOT_BORDER_WIDTH)
	style.bg_color = Color.TRANSPARENT
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _set_effect_highlights(target_colors: Dictionary[StringName, Color]) -> void:
	_effect_highlight_target_colors = target_colors.duplicate()
	_effect_highlight_turns_remaining = (
		EFFECT_HIGHLIGHT_TURN_ADVANCES if not _effect_highlight_target_colors.is_empty() else 0
	)
	if is_node_ready():
		_refresh_highlights()


func _clear_effect_highlights() -> void:
	if _effect_highlight_target_colors.is_empty() and _effect_highlight_turns_remaining == 0:
		return
	_effect_highlight_target_colors.clear()
	_effect_highlight_turns_remaining = 0
	if is_node_ready():
		_refresh_highlights()


func _collect_effect_highlight_colors(
	keyword_deltas: Array[Dictionary]
) -> Dictionary[StringName, Color]:
	var effect_colors: Dictionary[StringName, Color] = {}
	for delta: Dictionary in keyword_deltas:
		var target_id: StringName = delta.get(&"target_id", &"")
		if target_id.is_empty():
			continue
		var effect_color := _effect_color_for_keyword_kind(int(delta.get(&"kind", -1)))
		if int(delta.get(&"kind", -1)) == BattleKeywordOperation.Kind.ADD_ARMOR and int(delta.get(&"value", 0)) < 0:
			effect_color = EFFECT_NEGATIVE_BORDER_COLOR
		if effect_color == Color.TRANSPARENT:
			continue
		if not effect_colors.has(target_id) or effect_colors[target_id] != EFFECT_NEGATIVE_BORDER_COLOR:
			effect_colors[target_id] = effect_color
	return effect_colors


func _effect_color_for_keyword_kind(kind: int) -> Color:
	match kind:
		BattleKeywordOperation.Kind.ADD_ARMOR:
			return EFFECT_POSITIVE_BORDER_COLOR
		BattleKeywordOperation.Kind.APPLY_ADVANTAGE:
			return EFFECT_POSITIVE_BORDER_COLOR
		BattleKeywordOperation.Kind.REDUCE_COOLDOWN:
			return EFFECT_POSITIVE_BORDER_COLOR
		_:
			return Color.TRANSPARENT


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
		if entry.applied_damage > 0:
			var effect_overlay := _get_or_create_effect_slot_border_overlay(receiver_slot)
			effect_overlay.add_theme_stylebox_override(
				"panel",
				_effect_border_style(EFFECT_NEGATIVE_BORDER_COLOR)
			)
			effect_overlay.visible = true
		var damage_label := receiver_slot.get_node("UnitInfo/DamageFeedbackLabel") as Label
		damage_label.text = "-%d" % entry.applied_damage
		damage_label.visible = true


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
	var text: String = entry.message_text
	if entry.kind != BattleLogEntry.Kind.MESSAGE:
		var attacker := get_unit_by_id(entry.attacker_id)
		var receiver := get_unit_by_id(entry.receiver_id)
		if not is_instance_valid(attacker) or not is_instance_valid(receiver):
			return
		text = "R%d · %s dealt %d damage to %s · %d/%d HP%s" % [
			entry.round_number, attacker.display_name, entry.applied_damage,
			receiver.display_name, entry.receiver_hp_after, receiver.max_hp,
			" · Defeated" if entry.caused_defeat else ""]
	_debug_drawer.append_log_row({"index": entry_index, "sequence": entry_index,
		"text": text, "previewable": entry.kind != BattleLogEntry.Kind.MESSAGE})


func _clear_log_controls() -> void:
	_debug_drawer.clear_log_rows()


func _clear_all_damage_feedback() -> void:
	for slot: Control in get_player_slots() + get_enemy_slots():
		var damage_label := slot.get_node("UnitInfo/DamageFeedbackLabel") as Label
		damage_label.text = ""
		damage_label.visible = false


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
	_hide_skill_tooltip()
	_clear_turn_order_preview()
	_clear_default_action_state()
	_selected_skill_id = &""
	_skill_transaction.reset()
	_clear_effect_highlights()
	_clear_committed_action_history()
	_render_skill_transaction()
	_clear_reward_ui()
	call_deferred("_emit_exit_requested")


func _emit_exit_requested() -> void:
	close_character_info(false)
	_info_cache.clear()
	exit_requested.emit()

func _on_action_bar_skill_selected(skill_id: StringName) -> void:
	var actor: BattleUnitState = get_unit_by_id(_inspected_unit_id)
	var skill: CharacterSkill = _find_skill(actor, skill_id)
	if not is_instance_valid(skill):
		return
	if skill.kind == CharacterSkill.Kind.ACTIVE and not _visual_skill_availability(actor, skill)["can_activate"]:
		_refresh_action_bar()
		return
	if _preparation_required or is_battle_complete() or _action_in_progress:
		_refresh_action_bar()
		return
	_clear_default_action_state()
	_skill_transaction.reset()
	select_skill(skill_id)
	_refresh_action_bar()


func _on_action_bar_preview_changed(skill_id: StringName) -> void:
	_visual_hover_skill = skill_id
	_refresh_visual_states()


func _on_action_bar_confirm() -> void:
	if _default_action_mode != DefaultActionMode.NONE:
		_confirm_default_action()
	else:
		confirm_skill_action()
	_refresh_action_bar()


func _on_action_bar_cancel() -> void:
	if _default_action_mode != DefaultActionMode.NONE:
		_cancel_default_action()
	else:
		cancel_skill_action()
	_selected_skill_id = &""
	_hide_skill_tooltip()
	_refresh_action_bar()


func _refresh_action_bar() -> void:
	if not is_node_ready():
		return
	var unit: BattleUnitState = get_unit_by_id(_inspected_unit_id)
	var current: BattleUnitState = get_current_unit()
	var rows: Array[Dictionary] = []
	if is_instance_valid(unit):
		for skill: CharacterSkill in unit.skills:
			if skill.kind != CharacterSkill.Kind.ACTIVE:
				continue
			var availability: Dictionary = _visual_skill_availability(unit, skill)
			var reason: String = availability["reason_text"]
			var tooltip: String = "Effect: %s\nTargeting: %s\nRequirements: %s\nCooldown: %s" % [
				skill.effect_text, skill.targeting_text, skill.requirements_text, skill.cooldown_text
			]
			if is_instance_valid(skill.combo_definition):
				tooltip += "\nCombo: " + skill.combo_definition.description_text
			rows.append({
				"skill_id": skill.skill_id, "name": skill.display_name, "kind": skill.kind,
				"selected": skill.skill_id == _selected_skill_id and _default_action_mode == DefaultActionMode.NONE,
				"availability_text": reason, "tooltip": tooltip, "skill": skill.duplicate_skill(),
				"can_activate": availability["can_activate"], "no_legal_completion": availability["no_legal_completion"]
			})
	var snapshot: Dictionary = _skill_transaction.presentation_snapshot()
	var available: bool = _can_current_player_act() and not _action_in_progress and not is_battle_complete()
	var attack_available: bool = available and not _visual_default_targets(DefaultActionMode.ATTACK).is_empty()
	var swap_available: bool = available and not _visual_default_targets(DefaultActionMode.SWAP).is_empty()
	var view: Dictionary = {
		"actor_id": unit.unit_id if is_instance_valid(unit) else &"",
		"actor_name": unit.display_name if is_instance_valid(unit) else "",
		"actor_status": ("Active" if unit.is_active() else "Defeated") if is_instance_valid(unit) else "",
		"skills": rows, "default_mode": _default_action_mode,
		"details_allowed": is_instance_valid(unit),
		"detail_context": "%s:%s:%s" % [unit.is_active() if is_instance_valid(unit) else false, _preparation_required, is_battle_complete()],
		"attack_enabled": attack_available, "swap_enabled": swap_available,
		"attack_no_target": available and not attack_available, "swap_no_target": available and not swap_available,
		"attack_reason": "Select an active enemy." if attack_available else ("No legal enemy targets." if available else "Unavailable for the current turn."),
		"swap_reason": "Select an adjacent active ally." if swap_available else ("No legal targets: no adjacent active ally." if available else "Unavailable for the current turn."),
		"message": snapshot["message"], "summary": snapshot["summary"],
		"action_region_visible": snapshot["action_region_visible"],
		"confirm_visible": snapshot["confirm_visible"], "confirm_enabled": snapshot["confirm_enabled"],
		"cancel_visible": snapshot["cancel_visible"], "cancel_enabled": snapshot["cancel_enabled"]
	}
	if _default_action_mode != DefaultActionMode.NONE:
		view["message"] = _default_action_message
		view["summary"] = ""
		view["confirm_visible"] = true
		view["confirm_enabled"] = not _default_action_preview.is_empty()
		view["cancel_visible"] = true
		view["cancel_enabled"] = true
		if not _default_action_preview.is_empty():
			var target_id: StringName = _default_action_preview.get(&"target_id" if _default_action_mode == DefaultActionMode.ATTACK else &"occupant_id", &"")
			var target: BattleUnitState = get_unit_by_id(target_id)
			if is_instance_valid(target):
				view["summary"] = ("Attack " if _default_action_mode == DefaultActionMode.ATTACK else "Swap with ") + target.display_name
	_action_bar.render(view)
	_refresh_debug_drawer()
	_refresh_visual_states()

func _on_debug_log_preview_changed(entry_index: int) -> void:
	if entry_index < 0:
		clear_log_entry_preview()
	else:
		preview_log_entry(entry_index)


func _on_debug_drawer_opened(opened: bool) -> void:
	if opened:
		_hide_skill_tooltip()
		_clear_turn_order_preview()
	_refresh_debug_drawer()


func _refresh_debug_drawer() -> void:
	if is_node_ready():
		if _info_modal_blocked():
			close_character_info(false)
		_debug_drawer.render(_build_debug_view())


func _build_debug_view() -> Dictionary:
	var current: BattleUnitState = get_current_unit()
	var phase: String = "No active units"
	if _preparation_required:
		phase = "Preparation"
	elif is_battle_complete():
		phase = "Complete"
	elif _action_in_progress:
		phase = "Resolving"
	elif is_instance_valid(current):
		phase = "Player turn" if current.side == BattleUnitState.Side.PLAYER else "Enemy turn"
	var action: String = "None"
	if _default_action_mode == DefaultActionMode.ATTACK:
		action = "Default Attack"
	elif _default_action_mode == DefaultActionMode.SWAP:
		action = "Default Swap"
	elif not _selected_skill_id.is_empty():
		var skill: CharacterSkill = _find_skill(get_unit_by_id(_inspected_unit_id), _selected_skill_id)
		action = skill.display_name if is_instance_valid(skill) else String(_selected_skill_id)
	var snapshot: Dictionary = _skill_transaction.presentation_snapshot()
	var summary: String = snapshot.get("summary", "")
	if not _default_action_preview.is_empty():
		summary = String(_default_action_preview.get(&"target_id", _default_action_preview.get(&"occupant_id", &"")))
	var rows: Array[Dictionary] = []
	for index: int in _turn_queue.size():
		var unit: BattleUnitState = _turn_queue[index]
		rows.append({"index": index, "unit_id": unit.unit_id, "display_name": unit.display_name,
			"effective_speed": unit.get_effective_speed(), "active": unit.is_active(),
			"current": unit == current})
	return {
		"phase": phase, "round": round_number, "actor_id": current.unit_id if is_instance_valid(current) else &"",
		"actor_name": current.display_name if is_instance_valid(current) else "None",
		"outcome": BattleOutcome.get_display_text(_battle_outcome), "revision": _battle_revision,
		"selected_action": action, "target_summary": summary,
		"transaction_state": BattleSkillTransaction.State.keys()[_skill_transaction.state],
		"queue_rows": rows, "damage_enabled": not _preparation_required and not is_battle_complete()
			and not _action_in_progress and is_instance_valid(BattleTargetSelector.find_closest_enemy(current, _units)),
		"exit_enabled": not _preparation_required,
		"interaction_allowed": not _preparation_required and not _reward_overlay.visible
			and not is_instance_valid(_pending_recruitment_option)
	}

func _evaluate_visual_skill(actor_id: StringName, skill_id: StringName) -> SkillTargetEvaluation:
	var actor: BattleUnitState = get_unit_by_id(actor_id)
	var current: BattleUnitState = get_current_unit()
	return BattleSkillRules.evaluate_targets(actor, _find_skill(actor, skill_id), _units,
		current.unit_id if is_instance_valid(current) else &"", is_battle_complete(),
		round_number, _battle_revision, get_committed_action_history_snapshot())


func _visual_skill_availability(actor: BattleUnitState, skill: CharacterSkill) -> Dictionary:
	var evaluation: SkillTargetEvaluation = _evaluate_visual_skill(actor.unit_id, skill.skill_id)
	var reason: String = evaluation.blocking_reason.message
	if _preparation_required:
		reason = "Finish preparation first."
	elif _action_in_progress:
		reason = "An action is resolving."
	var no_target: bool = not _preparation_required and not _action_in_progress and evaluation.blocking_reason.code == SkillActionReason.Code.TARGET_INVALID
	var allowed: bool = reason.is_empty() and evaluation.can_start
	if allowed:
		var proposed: Array[StringName] = []
		if skill.targeting_mode == CharacterSkill.TargetingMode.PREDEFINED:
			proposed.assign(evaluation.affected_target_ids)
			allowed = _visual_confirmation_valid(actor, skill, proposed)
		else:
			allowed = _has_visual_completion(actor, skill, evaluation, proposed)
		no_target = not allowed
		if no_target:
			reason = "No legal targets for this action."
	return {"can_activate": allowed, "no_legal_completion": no_target,
		"reason_text": reason, "evaluation": evaluation}


func _visual_confirmation_valid(actor: BattleUnitState, skill: CharacterSkill, targets: Array[StringName]) -> bool:
	var current: BattleUnitState = get_current_unit()
	return BattleSkillRules.validate_confirmation(actor, skill, _units,
		current.unit_id if is_instance_valid(current) else &"", is_battle_complete(),
		round_number, targets, _battle_revision, _battle_revision,
		get_committed_action_history_snapshot(), [], get_action_records()).accepted


func _has_visual_completion(actor: BattleUnitState, skill: CharacterSkill,
		evaluation: SkillTargetEvaluation, proposed: Array[StringName]) -> bool:
	if proposed.size() >= evaluation.minimum_targets and _visual_confirmation_valid(actor, skill, proposed):
		return true
	if proposed.size() >= evaluation.maximum_targets:
		return false
	var sides: Array = skill.target_profile.get("target_sides") if is_instance_valid(skill.target_profile) else []
	for id: StringName in evaluation.valid_target_ids:
		if proposed.has(id):
			continue
		var unit: BattleUnitState = get_unit_by_id(id)
		if not sides.is_empty() and (proposed.size() >= sides.size() or unit.side != int(sides[proposed.size()])):
			continue
		proposed.append(id)
		if _has_visual_completion(actor, skill, evaluation, proposed):
			proposed.pop_back()
			return true
		proposed.pop_back()
	return false


func _visual_default_targets(mode: DefaultActionMode) -> Array[StringName]:
	var result: Array[StringName] = []
	var actor: BattleUnitState = get_current_unit()
	if not _can_current_player_act() or _action_in_progress or not is_instance_valid(actor):
		return result
	for unit: BattleUnitState in _units:
		if not is_instance_valid(unit):
			continue
		var preview: Dictionary = {}
		if mode == DefaultActionMode.ATTACK:
			preview = preview_default_attack(actor.unit_id, unit.unit_id)
		elif unit.side == actor.side:
			preview = preview_formation_move(actor.unit_id, unit.slot_index, true)
		if not preview.is_empty():
			result.append(unit.unit_id)
	return result


func _refresh_visual_states() -> void:
	if not is_node_ready():
		return
	var current: BattleUnitState = get_current_unit()
	var active_battle: bool = not _preparation_required and not is_battle_complete()
	var committed: bool = not _selected_skill_id.is_empty() or _default_action_mode != DefaultActionMode.NONE or _skill_transaction.state in [BattleSkillTransaction.State.TARGETING, BattleSkillTransaction.State.VALIDATING, BattleSkillTransaction.State.RESOLVING]
	var valid: Array[StringName] = []
	var selected: Array[StringName] = []
	var hovered: Array[StringName] = []
	var kind: StringName = &"skill"
	var targeting: bool = false
	if active_battle and _default_action_mode != DefaultActionMode.NONE:
		kind = &"attack" if _default_action_mode == DefaultActionMode.ATTACK else &"swap"
		valid = _visual_default_targets(_default_action_mode)
		targeting = true
		var id: StringName = _default_action_preview.get(&"target_id" if kind == &"attack" else &"occupant_id", &"")
		if int(_default_action_preview.get(&"revision", -1)) == _battle_revision and valid.has(id):
			selected.append(id)
	elif active_battle and _skill_transaction.state in [BattleSkillTransaction.State.TARGETING, BattleSkillTransaction.State.VALIDATING, BattleSkillTransaction.State.RESOLVING]:
		valid.assign(_skill_transaction.valid_target_ids)
		for id: StringName in _skill_transaction.affected_target_ids:
			if not valid.has(id):
				valid.append(id)
		selected.assign(_skill_transaction.locked_target_ids)
		var skill: CharacterSkill = _find_skill(current, _skill_transaction.skill_id)
		for id: StringName in _visual_zero_target_affected(current, skill):
			if not valid.has(id):
				valid.append(id)
		targeting = true
	elif active_battle and not committed and not _action_in_progress:
		if not _visual_hover_skill.is_empty() and not _debug_drawer.is_open():
			var actor: BattleUnitState = get_unit_by_id(_inspected_unit_id)
			var skill: CharacterSkill = _find_skill(actor, _visual_hover_skill)
			if is_instance_valid(actor) and is_instance_valid(skill):
				var availability: Dictionary = _visual_skill_availability(actor, skill)
				if availability["can_activate"]:
					var evaluation: SkillTargetEvaluation = availability["evaluation"]
					hovered.assign(evaluation.valid_target_ids)
					for id: StringName in _visual_zero_target_affected(actor, skill):
						if not hovered.has(id):
							hovered.append(id)
					for id: StringName in evaluation.affected_target_ids:
						if not hovered.has(id):
							hovered.append(id)
		elif _skill_transaction.state == BattleSkillTransaction.State.PREVIEWING:
			hovered.assign(_skill_transaction.valid_target_ids)
	var roles: Dictionary = _skill_transaction.presentation_snapshot()["indicator_roles"]
	for slot: Control in get_player_slots() + get_enemy_slots():
		var id: StringName = slot.get_meta("unit_id", &"")
		var unit: BattleUnitState = get_unit_by_id(id)
		var request: RefCounted = _visual_resolver.Request.new()
		request.occupied = is_instance_valid(unit)
		request.active = request.occupied and unit.is_active()
		request.current_actor = active_battle and unit == current
		request.ribbon_preview = active_battle and id == _turn_order_preview_id and not id.is_empty()
		request.action_committed = committed
		request.valid_target = valid.has(id)
		request.selected_target = selected.has(id)
		request.hover_target = hovered.has(id)
		request.action_kind = kind
		if request.occupied and not request.active:
			request.unavailable_reason = "Defeated"
		elif targeting and not valid.has(id):
			request.unavailable_reason = "Not a legal " + String(kind) + " target."
		var layers: RefCounted = _visual_resolver.resolve(request)
		if layers.actor_frame:
			_get_or_create_current_slot_border_overlay(slot)
		var overlay := slot.get_node("TargetIndicatorOverlay") as Panel
		var legacy_role: StringName = roles.get(id, &"")
		slot.set_meta("target_indicator_role", legacy_role)
		var role: StringName = legacy_role
		if role.is_empty() and not layers.target_border.is_empty():
			role = &"locked" if layers.selection_marker else &"valid_preview"
		overlay.visible = not layers.target_border.is_empty()
		var tint: TextureRect = _get_or_create_indicator_tint(overlay)
		tint.visible = false
		if overlay.visible:
			var style: StyleBoxFlat = _indicator_style(role)
			style.set_border_width_all(4 if layers.selection_marker else (1 if layers.target_border == &"preview" else 2))
			if kind == &"swap":
				style.border_color = Color(0.4, 0.8, 1.0)
			overlay.add_theme_stylebox_override("panel", style)
			_update_indicator_tint(tint, role)
		slot.render_visual_state(layers)
		slot.set_meta("turn_order_preview", request.ribbon_preview and request.active)


func _on_slot_focus_entered(slot: Control) -> void:
	if _slot_is_info_obscured(slot):
		return
	_focused_target_slot = slot
	_refresh_target_hover()


func _on_slot_focus_exited(slot: Control) -> void:
	if _focused_target_slot == slot:
		_focused_target_slot = null
		_refresh_target_hover()


func _refresh_target_hover() -> void:
	var slot: Control = _pointer_target_slot if is_instance_valid(_pointer_target_slot) else _focused_target_slot
	if is_instance_valid(slot):
		hover_skill_target(slot.get_meta("unit_id", &""))
	else:
		clear_skill_target_hover()
	_refresh_visual_states()

# Read the accepted detached plan; explicit transaction targets remain untouched.
func _visual_zero_target_affected(actor: BattleUnitState, skill: CharacterSkill) -> Array[StringName]:
	var affected: Array[StringName] = []
	if not is_instance_valid(actor) or not is_instance_valid(skill) or not is_instance_valid(skill.target_profile) or int(skill.target_profile.get("maximum_targets")) != 0:
		return affected
	var current: BattleUnitState = get_current_unit()
	var validation: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(actor, skill, _units,
		current.unit_id if is_instance_valid(current) else &"", is_battle_complete(),
		round_number, [], _battle_revision, _battle_revision,
		get_committed_action_history_snapshot(), [], get_action_records())
	if validation.accepted and is_instance_valid(validation.effect_plan):
		affected.assign(validation.effect_plan.target_ids)
	return affected

# AC7.6 publication is explicit at complete mutation boundaries, never in a draw loop.
func _publish_character_info() -> void:
	if _action_in_progress or not _info_valid:
		return
	var records: Dictionary = {}
	for unit: BattleUnitState in _units:
		if not is_instance_valid(unit):
			continue
		var record: Dictionary = unit.get_character_info_snapshot(round_number)
		record["role"] = BattleUnitPresentation.role_for(unit)
		records[unit.unit_id] = record
	var current: BattleUnitState = get_current_unit()
	var phase: StringName = &"complete" if is_battle_complete() else (&"preparation" if _preparation_required else &"battle")
	_info_revision += 1
	_info_cache = {
		"battle_epoch": _info_epoch, "committed_revision": _info_revision,
		"round_number": round_number, "phase": phase,
		"current_actor_id": current.unit_id if is_instance_valid(current) else &"",
		"units_by_id": records,
	}
	_refresh_character_info()

func _invalidate_character_info() -> void:
	_info_valid = false
	close_character_info(false)

func _info_modal_blocked() -> bool:
	return is_battle_complete() or _preparation_required or is_instance_valid(_pending_recruitment_option) or (is_node_ready() and _reward_overlay.visible)

func open_character_info(unit_id: StringName, keyboard: bool = false) -> bool:
	if not is_node_ready() or _info_modal_blocked() or not _info_valid or not _info_cache.get("units_by_id", {}).has(unit_id):
		return false
	var focus: Control = get_viewport().gui_get_focus_owner()
	if _info_unit_id.is_empty() or keyboard:
		_info_return_focus = weakref(focus) if is_instance_valid(focus) else null
	_info_unit_id = unit_id
	_info_generation += 1
	_action_bar.clear_details()
	clear_skill_preview()
	_clear_turn_order_preview()
	_pointer_target_slot = null
	_focused_target_slot = null
	clear_skill_target_hover()
	_refresh_character_info()
	_character_info.open_panel()
	_update_info_occlusion()
	if keyboard:
		_character_info.focus_close()
	return true

func get_character_info_snapshot() -> Dictionary:
	if _info_unit_id.is_empty() or not _info_cache.get("units_by_id", {}).has(_info_unit_id):
		return {}
	var snapshot: Dictionary = _info_cache.duplicate(true)
	snapshot["unit"] = snapshot["units_by_id"][_info_unit_id]
	snapshot.erase("units_by_id")
	snapshot["resolution_in_progress"] = _action_in_progress
	snapshot["inspection_generation"] = _info_generation
	snapshot["requested_unit_id"] = _info_unit_id
	return snapshot

func _refresh_character_info() -> void:
	if _info_unit_id.is_empty() or not is_node_ready():
		return
	if _info_modal_blocked() or not _info_cache.get("units_by_id", {}).has(_info_unit_id):
		close_character_info(false)
		return
	var snapshot: Dictionary = get_character_info_snapshot()
	var token: Array = [snapshot["battle_epoch"], snapshot["committed_revision"], _info_generation, _info_unit_id]
	_render_character_info(snapshot, token)

func _render_character_info(snapshot: Dictionary, token: Array) -> void:
	if not is_node_ready() or _info_modal_blocked() or token != [_info_epoch, _info_revision, _info_generation, _info_unit_id] or _info_unit_id.is_empty():
		return
	var view: Dictionary = _info_presenter.present(snapshot["unit"], snapshot)
	_character_info.render(view, token, _action_in_progress)

func close_character_info(restore_focus: bool = true) -> void:
	_info_generation += 1
	_info_unit_id = &""
	if not is_instance_valid(_character_info):
		_info_return_focus = null
		return
	var focused: Control = get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var owned: bool = is_instance_valid(focused) and (_character_info == focused or _character_info.is_ancestor_of(focused))
	_character_info.close_panel()
	_update_info_occlusion()
	if restore_focus and owned and not _info_modal_blocked():
		var previous: Control = _info_return_focus.get_ref() as Control if _info_return_focus != null else null
		if _info_can_focus(previous):
			previous.grab_focus()
		else:
			var current: BattleUnitState = get_current_unit()
			var slot: Control = _get_slot_for_unit(current) if is_instance_valid(current) else null
			if _info_can_focus(slot):
				slot.grab_focus()
			elif _info_can_focus(_action_bar):
				_action_bar.grab_focus()
	_info_return_focus = null

func _info_can_focus(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	if is_instance_valid(_debug_drawer) and _debug_drawer.is_open() and not _debug_drawer.is_ancestor_of(control):
		var panel: Control = _debug_drawer.get_node("%DrawerPanel")
		if panel.get_global_rect().intersects(control.get_global_rect()):
			return false
	return true

func _update_info_occlusion() -> void:
	_update_info_slot_focus()
	if not is_instance_valid(_action_bar) or not _action_bar.has_method("set_obscured_rect"):
		return
	var rect: Rect2 = Rect2()
	if is_instance_valid(_character_info) and _character_info.visible:
		rect = Rect2(Vector2(0, _character_info.position.y), _character_info.size)
	_action_bar.set_obscured_rect(rect)

func _input(event: InputEvent) -> void:
	if not is_node_ready() or not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if _info_modal_blocked():
		close_character_info(false)
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		if not _info_unit_id.is_empty():
			close_character_info()
		elif _debug_drawer.is_open():
			_debug_drawer.set_open(false)
		elif _default_action_mode != DefaultActionMode.NONE or not _selected_skill_id.is_empty():
			_on_action_bar_cancel()
		else:
			return
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_TAB and _debug_drawer.is_open():
		var focus: Control = get_viewport().gui_get_focus_owner()
		if _info_unit_id.is_empty() or (is_instance_valid(focus) and _debug_drawer.is_ancestor_of(focus)):
			_debug_drawer.handle_keyboard(event)

func _slot_is_info_obscured(slot: Control) -> bool:
	if not is_instance_valid(_character_info) or not _character_info.visible:
		return false
	return Rect2(Vector2(0, _character_info.position.y), _character_info.size).intersects(slot.get_global_rect())

func _update_info_slot_focus() -> void:
	if not is_node_ready():
		return
	for slot: Control in get_player_slots() + get_enemy_slots():
		var occupied: bool = not StringName(slot.get_meta("unit_id", &"")).is_empty()
		slot.focus_mode = Control.FOCUS_ALL if occupied and not _slot_is_info_obscured(slot) else Control.FOCUS_NONE


func _record_armor_loss(deltas: Array[Dictionary], target: BattleUnitState, armor_before: int) -> void:
	var lost: int = armor_before - target.get_armor()
	if lost > 0:
		deltas.append({
			&"kind": BattleKeywordOperation.Kind.ADD_ARMOR,
			&"target_id": target.unit_id,
			&"value": -lost,
			&"affected_skill_id": &"",
			&"from_reaction": false,
		})
