class_name BattleGoldRewardPanel
extends Control

signal acknowledgement_requested(battle_id: String)

var _battle_id: String = ""
var _submitted: bool = false
@onready var _amount: Label = %AmountLabel
@onready var _continue: Button = %ContinueButton

func _ready() -> void:
	_continue.pressed.connect(_on_continue_pressed)
	dismiss()

func present(battle_id: String, earned_gold: int) -> void:
	_battle_id = battle_id
	_submitted = false
	_amount.text = "Gold received: %dg" % earned_gold
	_continue.disabled = false
	show()
	_continue.grab_focus()

func set_saving(saving: bool) -> void:
	_continue.disabled = saving or _submitted

func dismiss() -> void:
	hide()
	_battle_id = ""
	_submitted = false

func _on_continue_pressed() -> void:
	if not visible or _submitted or _continue.disabled or _battle_id.is_empty():
		return
	_submitted = true
	_continue.disabled = true
	acknowledgement_requested.emit(_battle_id)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
