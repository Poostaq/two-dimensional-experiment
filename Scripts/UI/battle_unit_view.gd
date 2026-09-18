class_name BattleUnitView
extends PanelContainer

const STATUS_GLYPHS: Dictionary = {
	&"armor": "◇", &"advantage": "⊕", &"snared": "#", &"bleed": "♦", &"speed": "↕",
}
const STATUS_NAMES: Dictionary = {
	&"armor": "ARM", &"advantage": "ADV", &"snared": "SNR", &"bleed": "BLD", &"speed": "SPD",
}
var _presentation: Script = load("res://Scripts/UI/battle_unit_presentation.gd")

@onready var _name_label: Label = $UnitInfo/UnitNameLabel
@onready var _speed_label: Label = $UnitInfo/SpeedLabel
@onready var _health_label: Label = $UnitInfo/HealthLabel
@onready var _health_bar: ProgressBar = $UnitInfo/HealthBar
@onready var _role_label: Label = $UnitInfo/CharacterRow/Identity/RoleLabel
@onready var _figure: Control = $UnitInfo/CharacterRow/Figure
@onready var _slot_label: Label = $UnitInfo/SlotLabel
@onready var _state_label: Label = $UnitInfo/StateLabel
@onready var _statuses: HFlowContainer = $UnitInfo/StatusRow
@onready var _turn_order_preview: Control = $TurnOrderPreviewOverlay


func render_empty(side: String, slot_index: int) -> void:
	set_turn_order_preview(false)
	set_meta("unit_id", &"")
	set_meta("side", side)
	set_meta("slot_index", slot_index)
	_slot_label.text = "%s · %s %d" % [
		"ALLY" if side == "player" else "ENEMY",
		"FRONT" if slot_index < 3 else "BACK", slot_index % 3 + 1,
	]
	_slot_label.visible = true
	_name_label.text = ""
	_speed_label.text = ""
	_health_label.text = ""
	_health_bar.value = 0
	_health_bar.visible = false
	_role_label.text = ""
	_figure.visible = false
	_state_label.text = "Empty"
	_state_label.visible = true
	_clear_statuses()
	tooltip_text = _slot_label.text + " · Empty"


func render_unit(unit: BattleUnitState, round_number: int) -> void:
	if not unit.is_active():
		set_turn_order_preview(false)
	set_meta("unit_id", unit.unit_id)
	_name_label.text = unit.display_name
	_speed_label.text = "Speed %d" % unit.get_effective_speed()
	_health_label.text = (
		"HP %d/%d" % [unit.current_hp, unit.max_hp] if unit.is_active()
		else "Defeated — HP 0/%d" % unit.max_hp
	)
	_health_bar.max_value = maxi(1, unit.max_hp)
	_health_bar.value = clampi(unit.current_hp, 0, unit.max_hp)
	_health_bar.visible = true
	_slot_label.visible = false
	_role_label.text = "%s · %s %d" % [_presentation.role_for(unit),
		"Front" if unit.slot_index < 3 else "Back", unit.slot_index % 3 + 1]
	_figure.visible = true
	_figure.modulate = Color.WHITE if unit.is_active() else Color(0.5, 0.5, 0.5)
	var figure_id: StringName = _presentation.figure_for(unit)
	_figure.set_meta("figure_id", figure_id)
	(_figure.get_node("Shield") as Control).visible = figure_id in [&"bruiser", &"combatant"]
	(_figure.get_node("Blade") as Control).visible = figure_id in [&"striker", &"skirmisher"]
	(_figure.get_node("Staff") as Control).visible = figure_id in [&"support", &"controller", &"commander"]
	(_figure.get_node("Banner") as Control).visible = figure_id == &"commander"
	_state_label.text = "" if unit.is_active() else "Defeated"
	_state_label.visible = not unit.is_active()
	_clear_statuses()
	var status_descriptions: PackedStringArray = []
	for status: Dictionary in _presentation.statuses_for(unit, round_number):
		var badge := _statuses.get_node(String(status.id)) as Label
		badge.text = "%s%s%s" % [STATUS_GLYPHS[status.id], STATUS_NAMES[status.id], status.value]
		badge.tooltip_text = "%s %s — %s" % [status.label, status.value, status.description]
		badge.visible = true
		status_descriptions.append(badge.tooltip_text)
	tooltip_text = "%s · %s · %s · %s" % [
		unit.display_name, _role_label.text, _health_label.text, _speed_label.text,
	]
	if not status_descriptions.is_empty():
		tooltip_text += "\n" + "\n".join(status_descriptions)


func set_turn_order_preview(active: bool) -> void:
	_turn_order_preview.visible = active
	set_meta("turn_order_preview", active)


func _clear_statuses() -> void:
	for child: Node in _statuses.get_children():
		var badge := child as Label
		badge.text = ""
		badge.visible = false
