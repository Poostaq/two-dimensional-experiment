class_name TownRecruitmentPanel
extends Control

signal recruit_requested(class_id: StringName)
signal close_requested

@onready var _title: Label = %TitleLabel
@onready var _wallet: Label = %WalletLabel
@onready var _offers: VBoxContainer = %Offers
@onready var _empty: Label = %EmptyLabel
@onready var _close: Button = %CloseButton
@onready var _card: PanelContainer = $Card

var _focus_controls: Array[Control] = []

func _ready() -> void:
	_close.pressed.connect(_request_close)
	visibility_changed.connect(_on_visibility_changed)
	_refresh_focus()

func configure(clan_id: StringName, gold: int, class_ids: Array[StringName]) -> void:
	_title.text = "%s Recruitment" % String(clan_id).capitalize()
	_wallet.text = "%dg" % gold
	for child: Node in _offers.get_children():
		_offers.remove_child(child)
		child.queue_free()
	for class_id: StringName in class_ids:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		if not is_instance_valid(character):
			continue
		var offer: Button = Button.new()
		offer.name = String(class_id)
		offer.custom_minimum_size = Vector2(0, 56)
		offer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		offer.mouse_filter = Control.MOUSE_FILTER_STOP
		offer.disabled = gold < RunEconomyRules.RECRUITMENT_COST
		offer.text = "%s — %dg" % [character.display_name, RunEconomyRules.RECRUITMENT_COST]
		if offer.disabled:
			offer.text += " · Requires %dg" % RunEconomyRules.RECRUITMENT_COST
		offer.pressed.connect(_request_recruit.bind(class_id, offer))
		_offers.add_child(offer)
	_empty.visible = _offers.get_child_count() == 0
	_refresh_focus()

func _refresh_focus() -> void:
	_focus_controls.clear()
	for child: Node in _offers.get_children():
		var offer: Button = child as Button
		if is_instance_valid(offer) and not offer.disabled:
			_focus_controls.append(offer)
	_focus_controls.append(_close)
	for index: int in _focus_controls.size():
		var control: Control = _focus_controls[index]
		var previous: Control = _focus_controls[posmod(index - 1, _focus_controls.size())]
		var next: Control = _focus_controls[(index + 1) % _focus_controls.size()]
		control.focus_previous = control.get_path_to(previous)
		control.focus_next = control.get_path_to(next)
		control.focus_neighbor_top = control.focus_previous
		control.focus_neighbor_bottom = control.focus_next
		control.focus_neighbor_left = control.focus_previous
		control.focus_neighbor_right = control.focus_next
	_focus_first.call_deferred()

func _focus_first() -> void:
	if is_visible_in_tree() and not _focus_controls.is_empty():
		_focus_controls[0].grab_focus()

func _on_visibility_changed() -> void:
	if is_node_ready() and is_visible_in_tree():
		_focus_first.call_deferred()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		get_viewport().set_input_as_handled()
		if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE):
			_request_close()
		elif event.is_action_pressed("ui_focus_next") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_right"):
			_step_focus(1)
		elif event.is_action_pressed("ui_focus_prev") or event.is_action_pressed("ui_up") or event.is_action_pressed("ui_left"):
			_step_focus(-1)
		elif event.is_action_pressed("ui_accept") and not event.is_echo():
			var focused: Button = get_viewport().gui_get_focus_owner() as Button
			if is_instance_valid(focused) and is_ancestor_of(focused) and not focused.disabled:
				focused.pressed.emit()
	elif event is InputEventMouse and not _card.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()

func _unhandled_input(_event: InputEvent) -> void:
	if is_visible_in_tree():
		get_viewport().set_input_as_handled()

func _step_focus(direction: int) -> void:
	var current: int = _focus_controls.find(get_viewport().gui_get_focus_owner())
	_focus_controls[posmod(current + direction, _focus_controls.size())].grab_focus()

func _request_recruit(class_id: StringName, offer: Button) -> void:
	if is_visible_in_tree() and is_instance_valid(offer) and not offer.disabled:
		recruit_requested.emit(class_id)

func _request_close() -> void:
	if is_visible_in_tree():
		close_requested.emit()
