class_name WorldMapHud
extends Control

signal party_requested

const BOSS_THRESHOLD := 30

@onready var _move_count_label: Label = %MoveCountLabel
@onready var _remaining_label: Label = %RemainingLabel
@onready var _boss_state_label: Label = %BossStateLabel
@onready var _instruction_label: Label = %InstructionLabel
@onready var _context_label: Label = %ContextLabel
@onready var _manage_party_button: Button = %ManagePartyButton
@onready var _back_slots: Array[Label] = [%BackSlot0, %BackSlot1, %BackSlot2]
@onready var _front_slots: Array[Label] = [%FrontSlot0, %FrontSlot1, %FrontSlot2]


func _ready() -> void:
	_manage_party_button.pressed.connect(_on_manage_party_pressed)


func set_turn_state(move_count: int, boss_active: bool) -> void:
	var accepted_moves := maxi(0, move_count)
	_move_count_label.text = "MOVES %d / %d" % [accepted_moves, BOSS_THRESHOLD]
	if boss_active or accepted_moves >= BOSS_THRESHOLD:
		_remaining_label.text = "BOSS ACTIVE"
		_boss_state_label.text = "BOSS PURSUING"
		return
	var remaining := BOSS_THRESHOLD - accepted_moves
	_remaining_label.text = (
		"%d MOVE UNTIL BOSS ACTIVATES" % remaining
		if remaining == 1
		else "%d MOVES UNTIL BOSS ACTIVATES" % remaining
	)
	_boss_state_label.text = "BOSS DORMANT"


func set_formation(slots: Array[RunCharacter]) -> void:
	for index: int in 3:
		_back_slots[index].text = _slot_text(slots, index)
		_front_slots[index].text = _slot_text(slots, index + 3)


func set_context(encounter_type: String, terrain_tags: Array[String], is_valid: bool) -> void:
	_instruction_label.text = (
		"Choose a highlighted neighbouring hex."
		if is_valid
		else "Inspect a neighbouring hex."
	)
	var parts: Array[String] = [encounter_type.capitalize()]
	for tag: String in terrain_tags:
		if not tag.is_empty():
			parts.append(tag.capitalize())
	_context_label.text = " • ".join(parts)


func set_party_available(value: bool) -> void:
	_manage_party_button.disabled = not value


func _slot_text(slots: Array[RunCharacter], index: int) -> String:
	if index < 0 or index >= slots.size() or not is_instance_valid(slots[index]):
		return "Empty"
	return slots[index].display_name


func _on_manage_party_pressed() -> void:
	if _manage_party_button.disabled:
		return
	party_requested.emit()
