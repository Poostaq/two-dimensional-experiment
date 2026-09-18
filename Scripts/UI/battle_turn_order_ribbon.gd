class_name BattleTurnOrderRibbon
extends HBoxContainer

signal unit_preview_changed(unit_id: StringName)

var _entry_scene: PackedScene = load("res://Scenes/UI/battle_turn_order_entry.tscn")
var _entries_by_id: Dictionary = {}
var _entry_ids: Array[StringName] = []
var _hovered_id: StringName = &""
var _focused_id: StringName = &""
var _preview_id: StringName = &""

@onready var _current_host: HBoxContainer = $CurrentEntryHost
@onready var _upcoming: HBoxContainer = $UpcomingScroll/Entries
@onready var _scroll: ScrollContainer = $UpcomingScroll
@onready var _empty_label: Label = $EmptyLabel


func render_entries(entries: Array[Dictionary], current_id: StringName) -> void:
	var next_ids: Array[StringName] = []
	for row: Dictionary in entries:
		var id: StringName = row["unit_id"]
		if not id.is_empty() and not next_ids.has(id):
			next_ids.append(id)
	if not next_ids.has(_hovered_id):
		_hovered_id = &""
	if not next_ids.has(_focused_id):
		_focused_id = &""
	for id: StringName in _entry_ids:
		if not next_ids.has(id):
			var removed: Control = _entries_by_id[id]
			if removed.has_focus():
				removed.release_focus()
			removed.get_parent().remove_child(removed)
			removed.queue_free()
			_entries_by_id.erase(id)
	_entry_ids = next_ids
	var upcoming_index: int = 0
	for row: Dictionary in entries:
		var id: StringName = row["unit_id"]
		if not _entry_ids.has(id):
			continue
		var is_current: bool = id == current_id
		var host: HBoxContainer = _current_host if is_current else _upcoming
		var entry: Button = _entries_by_id.get(id) as Button
		if not is_instance_valid(entry):
			entry = _entry_scene.instantiate() as Button
			host.add_child(entry)
			entry.mouse_entered.connect(_on_hover_entered.bind(id))
			entry.mouse_exited.connect(_on_hover_exited.bind(id))
			entry.focus_entered.connect(_on_focus_entered.bind(id))
			entry.focus_exited.connect(_on_focus_exited.bind(id))
			_entries_by_id[id] = entry
		elif entry.get_parent() != host:
			entry.reparent(host)
		host.move_child(entry, 0 if is_current else upcoming_index)
		if not is_current:
			upcoming_index += 1
		entry.set_meta("unit_id", id)
		var full_name: String = row["display_name"]
		var team: String = "Ally" if int(row["side"]) == 0 else "Enemy"
		var order: String = "NOW" if is_current else str(row["ordinal"])
		(entry.get_node("Identity/Name") as Label).text = full_name
		(entry.get_node("Identity/Icon") as Label).text = full_name.left(1).to_upper()
		(entry.get_node("OrderLabel") as Label).text = team if is_current else "%s · %s" % [order, team]
		(entry.get_node("NowLabel") as Label).visible = is_current
		(entry.get_node("CurrentFrame") as Control).visible = is_current
		entry.tooltip_text = "%s · %s · %s" % [full_name, team, "Acting now" if is_current else "Turn %s" % order]
		entry.accessibility_name = entry.tooltip_text
		entry.accessibility_description = "Preview this character on the battlefield."
	for index: int in range(_entry_ids.size()):
		var entry: Control = _entries_by_id[_entry_ids[index]]
		entry.focus_previous = entry.get_path_to(_entries_by_id[_entry_ids[index - 1]]) if index > 0 else NodePath("")
		entry.focus_next = entry.get_path_to(_entries_by_id[_entry_ids[index + 1]]) if index + 1 < _entry_ids.size() else NodePath("")
		entry.focus_neighbor_left = entry.focus_previous
		entry.focus_neighbor_right = entry.focus_next
	_current_host.visible = not current_id.is_empty()
	_scroll.visible = upcoming_index > 0
	_empty_label.visible = _entry_ids.is_empty()
	_resolve_preview()


func clear_preview() -> void:
	_hovered_id = &""
	_focused_id = &""
	for id: StringName in _entry_ids:
		var entry: Control = _entries_by_id[id]
		if entry.has_focus():
			entry.release_focus()
	_resolve_preview()


func get_entry_ids() -> Array[StringName]:
	return _entry_ids.duplicate()


func get_preview_unit_id() -> StringName:
	return _preview_id


func get_entry_control(unit_id: StringName) -> Control:
	return _entries_by_id.get(unit_id) as Control


func _on_hover_entered(unit_id: StringName) -> void:
	_hovered_id = unit_id
	_resolve_preview()


func _on_hover_exited(unit_id: StringName) -> void:
	if _hovered_id == unit_id:
		_hovered_id = &""
	_resolve_preview()


func _on_focus_entered(unit_id: StringName) -> void:
	_focused_id = unit_id
	var entry: Control = get_entry_control(unit_id)
	if is_instance_valid(entry) and entry.get_parent() == _upcoming:
		_scroll.ensure_control_visible(entry)
	_resolve_preview()


func _on_focus_exited(unit_id: StringName) -> void:
	if _focused_id == unit_id:
		_focused_id = &""
	_resolve_preview()


func _resolve_preview() -> void:
	var next_id: StringName = _hovered_id if not _hovered_id.is_empty() else _focused_id
	if not _entries_by_id.has(next_id):
		next_id = &""
	if next_id == _preview_id:
		return
	_preview_id = next_id
	unit_preview_changed.emit(_preview_id)
