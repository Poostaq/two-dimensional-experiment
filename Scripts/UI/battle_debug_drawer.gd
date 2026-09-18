class_name BattleDebugDrawer
extends Control

signal damage_requested
signal exit_requested
signal log_preview_changed(entry_index: int)
signal opened_changed(opened: bool)

@onready var _panel: PanelContainer = %DrawerPanel
@onready var _handle: Button = %DebugHandle
@onready var _close: Button = %CloseButton
@onready var _damage: Button = %AdvanceTurnDebugButton
@onready var _exit: Button = %ExitBattleDebugButton
@onready var _live: Label = %LiveState
@onready var _queue: Label = %InitiativeQueue
@onready var _rows: VBoxContainer = %BattleLogEntries
@onready var _scroll: ScrollContainer = %BattleLogScroll

var _return_focus: WeakRef
var _generation: int = 0
var _preview_index: int = -1
var _view: Dictionary = {}

func _ready() -> void:
	_handle.pressed.connect(_toggle)
	_close.pressed.connect(set_open.bind(false))
	_damage.pressed.connect(_request_damage)
	_exit.pressed.connect(_request_exit)
	_panel.hide()
	_handle.tooltip_text = "Open battle diagnostics"
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.065, 0.08, 1.0)
	style.border_color = Color(0.55, 0.48, 0.29)
	style.set_border_width_all(2)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", style)

func is_open() -> bool:
	return _panel.visible

func _toggle() -> void:
	set_open(not is_open())

func set_open(opened: bool, restore_focus: bool = true) -> void:
	if opened and _handle.disabled:
		return
	if is_open() == opened:
		return
	if opened:
		var focused: Control = get_viewport().gui_get_focus_owner()
		_return_focus = weakref(focused) if is_instance_valid(focused) else null
		_panel.show()
		_close.grab_focus()
	else:
		_clear_preview()
		_panel.hide()
		if restore_focus:
			var previous: Control = _return_focus.get_ref() as Control if _return_focus != null else null
			if _can_focus(previous):
				previous.grab_focus()
			elif _can_focus(_handle):
				_handle.grab_focus()
		_return_focus = null
	_handle.tooltip_text = "Close battle diagnostics" if opened else "Open battle diagnostics"
	_handle.accessibility_name = _handle.tooltip_text
	opened_changed.emit(opened)
	if is_open():
		_scroll_to_newest(_generation)

func _can_focus(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and (not control is BaseButton or not (control as BaseButton).disabled)

func reset_view() -> void:
	_generation += 1
	set_open(false, false)
	_return_focus = null
	_clear_preview()
	clear_log_rows()
	_view.clear()
	($DrawerPanel/DrawerContents/DiagnosticsScroll as ScrollContainer).scroll_vertical = 0

func render(view: Dictionary) -> void:
	_view = view.duplicate(true)
	_handle.disabled = not view.get("interaction_allowed", true)
	if _handle.disabled:
		set_open(false, false)
	_handle.visible = not _handle.disabled
	_damage.disabled = not view.get("damage_enabled", false)
	_exit.disabled = not view.get("exit_enabled", true)
	_live.text = "LIVE STATE\n%s · Round %d\nActor: %s [%s]\nOutcome: %s\nRevision: %d\nAction: %s\nTargets: %s\nTransaction: %s" % [
		view.get("phase", ""), view.get("round", 1), view.get("actor_name", "None"),
		view.get("actor_id", &""), view.get("outcome", ""), view.get("revision", 0),
		view.get("selected_action", "None"), view.get("target_summary", ""),
		view.get("transaction_state", "IDLE")]
	var lines: PackedStringArray = ["INITIATIVE QUEUE"]
	for row: Dictionary in view.get("queue_rows", []):
		lines.append("%s %d. %s [%s] · SPD %d%s" % [
			"NOW" if row["current"] else "   ", row["index"] + 1, row["display_name"],
			row["unit_id"], row["effective_speed"], "" if row["active"] else " · inactive"])
	_queue.text = "\n".join(lines)
	_live.accessibility_description = _live.text
	_queue.accessibility_description = _queue.text

func append_log_row(row: Dictionary) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = row["text"]
	label.set_meta("entry_index", row["index"])
	label.set_meta("sequence", row["sequence"])
	label.mouse_filter = Control.MOUSE_FILTER_STOP if row["previewable"] else Control.MOUSE_FILTER_IGNORE
	if row["previewable"]:
		label.mouse_entered.connect(_preview_row.bind(int(row["index"])))
		label.mouse_exited.connect(_leave_row.bind(int(row["index"])))
	_rows.add_child(label)
	_scroll_to_newest(_generation)

func clear_log_rows() -> void:
	_generation += 1
	_clear_preview()
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_scroll.scroll_vertical = 0

func _scroll_to_newest(generation: int) -> void:
	await get_tree().process_frame
	if not is_inside_tree() or generation != _generation:
		return
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)

func _preview_row(index: int) -> void:
	if not is_open():
		return
	_preview_index = index
	log_preview_changed.emit(index)

func _leave_row(index: int) -> void:
	if _preview_index == index:
		_clear_preview()

func _clear_preview() -> void:
	_preview_index = -1
	log_preview_changed.emit(-1)

func _request_damage() -> void:
	if is_open() and not _damage.disabled:
		damage_requested.emit()

func _request_exit() -> void:
	if is_open() and not _exit.disabled:
		exit_requested.emit()

func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventKey or not event.is_pressed():
		return
	var key := event as InputEventKey
	if key.keycode == KEY_ESCAPE:
		set_open(false)
		get_viewport().set_input_as_handled()
	elif key.keycode == KEY_TAB:
		var controls: Array[Control] = [_close, _scroll, _damage, _exit, _handle]
		var available: Array[Control] = []
		for control: Control in controls:
			if _can_focus(control):
				available.append(control)
		var current: int = available.find(get_viewport().gui_get_focus_owner())
		var next: int = posmod(current + (-1 if key.shift_pressed else 1), available.size())
		available[next].grab_focus()
		get_viewport().set_input_as_handled()
