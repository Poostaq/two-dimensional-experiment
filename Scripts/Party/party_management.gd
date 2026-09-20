class_name PartyManagement
extends Control

signal move_requested(source_slot: int, destination_slot: int, expected_character_id: StringName)
signal placement_requested(destination_slot: int, expected_character_id: StringName)
signal replacement_requested(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName
)
signal dismissal_requested(slot_index: int, expected_character_id: StringName)
signal close_requested
signal placement_cancelled

enum Mode {
	NORMAL,
	PLACEMENT,
	REPLACEMENT,
}

const SLOT_COUNT := 6

@onready var _instruction_label: Label = $Margin/VBox/InstructionLabel
@onready var _details_panel: PanelContainer = %DetailsPanel
@onready var _details_name_label: Label = %DetailsNameLabel
@onready var _details_hp_label: Label = %DetailsHpLabel
@onready var _details_speed_label: Label = %DetailsSpeedLabel
@onready var _skills_container: VBoxContainer = %SkillsContainer
@onready var _pending_recruit_region: VBoxContainer = %PendingRecruitRegion
@onready var _pending_recruit_card: PartySlot = %PendingRecruitCard
@onready var _return_button: Button = %ReturnToMapButton
@onready var _cancel_button: Button = %CancelPlacementButton

@onready var _dismiss_button: Button = %DismissButton
@onready var _dismiss_explanation: Label = %DismissExplanation
@onready var _dismiss_confirmation: ConfirmationDialog = %DismissConfirmation

var _dismiss_slot: int = -1
var _dismiss_character_id: StringName = &""

var _mode: Mode = Mode.NORMAL
var _slots: Array[RunCharacter] = []
var _slot_views: Array[PartySlot] = []
var _pending_recruit: RunCharacter
var _selected_character_id: StringName = &""


func _ready() -> void:
	_slots.resize(SLOT_COUNT)
	for slot_index: int in SLOT_COUNT:
		var slot := get_node("%%Slot%d" % slot_index) as PartySlot
		_slot_views.append(slot)
		slot.character_clicked.connect(select_character)
		slot.character_dropped.connect(request_move)
		slot.pending_recruit_dropped.connect(_on_pending_recruit_dropped)
	_return_button.pressed.connect(request_close)
	_cancel_button.pressed.connect(request_placement_cancel)
	_dismiss_button.pressed.connect(_on_dismiss_pressed)
	_dismiss_confirmation.window_input.connect(_on_dismiss_window_input)
	_dismiss_confirmation.confirmed.connect(_on_dismiss_confirmed)
	_dismiss_confirmation.canceled.connect(clear_dismissal_confirmation)
	_dismiss_confirmation.close_requested.connect(clear_dismissal_confirmation)
	_dismiss_confirmation.visibility_changed.connect(_on_dismiss_visibility_changed)
	_clear_transient_state()
	_refresh_presentation()


func configure_normal(slots: Array[RunCharacter]) -> void:
	_mode = Mode.NORMAL
	_pending_recruit = null
	_set_slots(slots)
	_clear_transient_state()
	_refresh_presentation()


func configure_placement(slots: Array[RunCharacter], pending_recruit: RunCharacter) -> void:
	_mode = Mode.PLACEMENT
	_pending_recruit = pending_recruit
	_set_slots(slots)
	_clear_transient_state()
	_refresh_presentation()


func configure_replacement(slots: Array[RunCharacter], pending_recruit: RunCharacter) -> void:
	_mode = Mode.REPLACEMENT
	_pending_recruit = pending_recruit
	_set_slots(slots)
	_clear_transient_state()
	_refresh_presentation()


func refresh_slots(slots: Array[RunCharacter]) -> void:
	clear_dismissal_confirmation()
	_set_slots(slots)
	if not _selected_character_id.is_empty() and not _has_character(_selected_character_id):
		_selected_character_id = &""
	_refresh_presentation()


func select_character(slot_index: int, character_id: StringName) -> void:
	if (_mode != Mode.NORMAL and _mode != Mode.REPLACEMENT) or slot_index < 0 or slot_index >= SLOT_COUNT:
		return
	var character := _slots[slot_index]
	if not is_instance_valid(character) or character.character_id != character_id:
		return
	_selected_character_id = character_id
	_refresh_presentation()


func request_move(source_slot: int, destination_slot: int, character_id: StringName) -> void:
	if _mode != Mode.NORMAL:
		return
	move_requested.emit(source_slot, destination_slot, character_id)


func request_placement(destination_slot: int, character_id: StringName) -> void:
	if (
		_mode != Mode.PLACEMENT
		or not is_instance_valid(_pending_recruit)
		or _pending_recruit.character_id != character_id
		or destination_slot < 0
		or destination_slot >= SLOT_COUNT
		or is_instance_valid(_slots[destination_slot])
	):
		return
	placement_requested.emit(destination_slot, character_id)


func request_replacement(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName
) -> void:
	if (
		_mode != Mode.REPLACEMENT
		or not is_instance_valid(_pending_recruit)
		or _pending_recruit.character_id != expected_recruit_id
		or destination_slot < 0
		or destination_slot >= SLOT_COUNT
	):
		return
	var target: RunCharacter = _slots[destination_slot]
	if not is_instance_valid(target) or target.character_id != expected_character_id:
		return
	replacement_requested.emit(destination_slot, expected_character_id, expected_recruit_id)


func request_close() -> void:
	if _mode != Mode.NORMAL:
		return
	_clear_transient_state()
	close_requested.emit()


func request_placement_cancel() -> void:
	if _mode != Mode.PLACEMENT and _mode != Mode.REPLACEMENT:
		return
	_clear_transient_state()
	placement_cancelled.emit()


func _on_pending_recruit_dropped(destination_slot: int, recruit_id: StringName) -> void:
	if _mode == Mode.PLACEMENT:
		request_placement(destination_slot, recruit_id)
		return
	if _mode != Mode.REPLACEMENT or destination_slot < 0 or destination_slot >= SLOT_COUNT:
		return
	var target: RunCharacter = _slots[destination_slot]
	if is_instance_valid(target):
		request_replacement(destination_slot, target.character_id, recruit_id)


func _set_slots(slots: Array[RunCharacter]) -> void:
	_slots.clear()
	_slots.resize(SLOT_COUNT)
	for slot_index: int in min(slots.size(), SLOT_COUNT):
		_slots[slot_index] = slots[slot_index]


func _refresh_presentation() -> void:
	if not is_node_ready():
		return
	for slot_index: int in SLOT_COUNT:
		var character := _slots[slot_index]
		var occupied := is_instance_valid(character)
		_slot_views[slot_index].configure(
			slot_index,
			character,
			_mode == Mode.NORMAL and occupied,
			_mode == Mode.NORMAL,
			(_mode == Mode.PLACEMENT and not occupied) or (_mode == Mode.REPLACEMENT and occupied),
			_mode == Mode.REPLACEMENT and occupied
		)
		_slot_views[slot_index].set_selected(
			occupied and character.character_id == _selected_character_id
		)
	var is_transaction := _mode == Mode.PLACEMENT or _mode == Mode.REPLACEMENT
	_pending_recruit_region.visible = is_transaction
	_return_button.visible = _mode == Mode.NORMAL
	_cancel_button.visible = is_transaction
	_cancel_button.text = "Cancel Replacement" if _mode == Mode.REPLACEMENT else "Cancel Placement"
	if _mode == Mode.REPLACEMENT:
		_instruction_label.text = "Drag the recruit onto a character to replace them."
	elif _mode == Mode.PLACEMENT:
		_instruction_label.text = "Drag the recruit into an empty slot."
	else:
		_instruction_label.text = "Drag characters to rearrange the party."
	if is_transaction and is_instance_valid(_pending_recruit):
		_pending_recruit_card.configure(-1, _pending_recruit, true, false, false)
	_refresh_details()


func _refresh_details() -> void:
	_clear_skill_rows()
	var selected := _find_character(_selected_character_id)
	_dismiss_button.visible = is_normal_mode()
	_dismiss_button.disabled = not is_instance_valid(selected) or _occupied_count() <= 1
	_dismiss_button.tooltip_text = "Keep at least one party member." if _occupied_count() <= 1 else ""
	_dismiss_explanation.visible = is_normal_mode() and is_instance_valid(selected) and _occupied_count() <= 1
	_details_panel.visible = (
		is_instance_valid(selected)
		and (_mode == Mode.NORMAL or _mode == Mode.REPLACEMENT)
	)
	if not _details_panel.visible:
		return
	_details_name_label.text = selected.display_name
	_details_hp_label.text = "Max HP: %d" % selected.max_hp
	_details_speed_label.text = "Speed: %d" % selected.base_speed
	for skill: CharacterSkill in selected.get_skills():
		var label := Label.new()
		label.text = "%s (%s) — %s" % [
			skill.display_name,
			"Active" if skill.kind == CharacterSkill.Kind.ACTIVE else "Passive",
			skill.effect_text,
		]
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_skills_container.add_child(label)


func _clear_skill_rows() -> void:
	for child: Node in _skills_container.get_children():
		child.queue_free()


func _clear_transient_state() -> void:
	clear_dismissal_confirmation()
	_selected_character_id = &""
	if is_instance_valid(_details_panel):
		_details_panel.visible = false
	for slot: PartySlot in _slot_views:
		slot.clear_transient_state()


func _find_character(character_id: StringName) -> RunCharacter:
	if character_id.is_empty():
		return null
	for character: RunCharacter in _slots:
		if is_instance_valid(character) and character.character_id == character_id:
			return character
	return null


func _has_character(character_id: StringName) -> bool:
	return is_instance_valid(_find_character(character_id))


func is_normal_mode() -> bool:
	return _mode == Mode.NORMAL


func request_dismissal(slot_index: int, expected_character_id: StringName) -> void:
	clear_dismissal_confirmation()
	if not is_node_ready() or not _can_dismiss(slot_index, expected_character_id):
		return
	_dismiss_slot = slot_index
	_dismiss_character_id = expected_character_id
	_dismiss_confirmation.dialog_text = "Dismiss %s? No gold is refunded." % _slots[slot_index].display_name
	_dismiss_confirmation.popup_centered()
	_dismiss_confirmation.get_cancel_button().grab_focus()


func clear_dismissal_confirmation() -> void:
	_dismiss_slot = -1
	_dismiss_character_id = &""
	if is_instance_valid(_dismiss_confirmation):
		_dismiss_confirmation.hide()


func _on_dismiss_pressed() -> void:
	for slot_index: int in _slots.size():
		var character: RunCharacter = _slots[slot_index]
		if is_instance_valid(character) and character.character_id == _selected_character_id:
			request_dismissal(slot_index, character.character_id)
			return


func _on_dismiss_confirmed() -> void:
	var slot_index: int = _dismiss_slot
	var character_id: StringName = _dismiss_character_id
	var valid: bool = _can_dismiss(slot_index, character_id)
	# Consume the confirmation key before callbacks can close this overlay.
	get_viewport().set_input_as_handled()
	clear_dismissal_confirmation()
	if valid:
		dismissal_requested.emit(slot_index, character_id)


func _on_dismiss_window_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_dismiss_confirmation.set_input_as_handled()
		get_viewport().set_input_as_handled()
		clear_dismissal_confirmation()


func _on_dismiss_visibility_changed() -> void:
	if not _dismiss_confirmation.visible:
		_dismiss_slot = -1
		_dismiss_character_id = &""


func _can_dismiss(slot_index: int, character_id: StringName) -> bool:
	if not is_normal_mode() or slot_index < 0 or slot_index >= _slots.size() or _occupied_count() <= 1:
		return false
	var character: RunCharacter = _slots[slot_index]
	return is_instance_valid(character) and character.character_id == character_id


func _occupied_count() -> int:
	var count: int = 0
	for character: RunCharacter in _slots:
		if is_instance_valid(character):
			count += 1
	return count


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventMouseButton and event.button_index in [
		MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN,
		MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT,
	]:
		get_viewport().set_input_as_handled()
		return
	if _dismiss_confirmation.visible:
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel"):
			if is_normal_mode():
				request_close()
			else:
				request_placement_cancel()
		elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			_step_focus(1)
		elif event.is_action_pressed("ui_focus_prev") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			_step_focus(-1)
		elif event.is_action_pressed("ui_accept") and not event.is_echo():
			var focused: Button = get_viewport().gui_get_focus_owner() as Button
			if is_instance_valid(focused) and is_ancestor_of(focused) and not focused.disabled:
				focused.pressed.emit()


func _step_focus(direction: int) -> void:
	var controls: Array[Button] = []
	for button: Button in [_return_button, _dismiss_button, _cancel_button]:
		if button.is_visible_in_tree() and not button.disabled:
			controls.append(button)
	if controls.is_empty():
		return
	var current: int = controls.find(get_viewport().gui_get_focus_owner())
	controls[posmod(current + direction, controls.size())].grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	# GUI controls receive keys first; everything else remains inside the party overlay.
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel"):
			if _dismiss_confirmation.visible:
				clear_dismissal_confirmation()
			elif is_normal_mode():
				request_close()
			else:
				request_placement_cancel()
