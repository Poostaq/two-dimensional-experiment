class_name BattleActionBar
extends PanelContainer

signal skill_selected(skill_id: StringName)
signal skill_preview_changed(skill_id: StringName)
signal default_attack_requested
signal default_swap_requested
signal confirm_requested
signal cancel_requested

const SKILL_TOOLTIP_VIEWPORT_MARGIN: float = 12.0
const SKILL_TOOLTIP_ANCHOR_GAP: float = 8.0

@onready var _skills: HBoxContainer = %SkillInspectorSkills
@onready var _attack: Button = %DefaultAttackButton
@onready var _swap: Button = %DefaultSwapButton
@onready var _confirm: Button = %ConfirmButton
@onready var _cancel: Button = %CancelButton
@onready var _tooltip: PanelContainer = %SkillTooltipPanel
@onready var _skill_tooltip_panel: PanelContainer = %SkillTooltipPanel
@onready var _skill_tooltip_name_label: Label = %SkillTooltipNameLabel
@onready var _skill_tooltip_kind_label: Label = %SkillTooltipKindLabel
@onready var _skill_tooltip_effect_label: Label = %SkillTooltipEffectLabel
@onready var _skill_tooltip_targeting_label: Label = %SkillTooltipTargetingLabel
@onready var _skill_tooltip_requirements_label: Label = %SkillTooltipRequirementsLabel
@onready var _skill_tooltip_cooldown_label: Label = %SkillTooltipCooldownLabel
@onready var _skill_tooltip_combo_label: Label = %SkillTooltipComboLabel
var _actor_id: StringName = &""
var _roster: Array[StringName] = []
var _hovered_skill_button: Button
var _focused_skill_button: Button
var _pointer_skill_button: Button
var _skill_tooltip_generation: int = 0
var _detail_id: StringName = &""
var _view: Dictionary = {}
var _rendering: bool = false
var _obscured_rect: Rect2 = Rect2()

func _ready() -> void:
	_attack.pressed.connect(_request_attack)
	_swap.pressed.connect(_request_swap)
	_confirm.pressed.connect(func() -> void: confirm_requested.emit())
	_cancel.pressed.connect(func() -> void: cancel_requested.emit())
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.055, 0.075, 0.09, 1.0)
	tooltip_style.border_color = Color(0.65, 0.57, 0.35)
	tooltip_style.set_border_width_all(1)
	_tooltip.add_theme_stylebox_override("panel", tooltip_style)
	focus_entered.connect(_show_bar_details)
	focus_exited.connect(_hide_default_details)
	_attack.icon = _icon(false)
	_swap.icon = _icon(true)
	for button: Button in [_attack, _swap]:
		button.mouse_entered.connect(_show_default_details.bind(button))
		button.focus_entered.connect(_show_default_details.bind(button))
		button.mouse_exited.connect(_hide_default_details)
		button.focus_exited.connect(_hide_default_details)

func _icon(swap: bool) -> ImageTexture:
	var path: String = (
		"M4 7h15m-4-4 4 4-4 4M20 17H5m4-4-4 4 4 4"
		if swap else "M5 19 19 5V2h-3L3 15m1-4 9 9M2 22l5-5"
	)
	var svg: String = '<svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24"><path d="%s" fill="none" stroke="#e8dcb6" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>' % path
	var bitmap := Image.new()
	bitmap.load_svg_from_string(svg)
	return ImageTexture.create_from_image(bitmap)

func render(view: Dictionary) -> void:
	_rendering = true
	if _view.get("detail_context", "") != view.get("detail_context", ""):
		clear_details()
	_view = view.duplicate(true)
	if not view.get("details_allowed", true):
		clear_details()
	var actor_id: StringName = view.get("actor_id", &"")
	var rows: Array = view.get("skills", [])
	var ids: Array[StringName] = []
	for row: Dictionary in rows:
		ids.append(row["skill_id"])
	if actor_id != _actor_id or ids != _roster:
		clear_details()
		var restore_focus: bool = is_instance_valid(_skills.get_viewport().gui_get_focus_owner()) and _skills.is_ancestor_of(_skills.get_viewport().gui_get_focus_owner())
		for child: Node in _skills.get_children():
			_skills.remove_child(child)
			child.queue_free()
		_actor_id = actor_id
		_roster = ids
		for row: Dictionary in rows:
			var button := (load("res://Scenes/UI/battle_skill_button.tscn") as PackedScene).instantiate() as Button
			button.set_meta("skill_id", row["skill_id"])
			button.pressed.connect(_select_skill.bind(button))
			button.mouse_entered.connect(_pointer_enter.bind(button))
			button.mouse_exited.connect(_pointer_exit.bind(button))
			button.focus_entered.connect(_focus_enter.bind(button))
			button.focus_exited.connect(_focus_exit.bind(button))
			button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
			_skills.add_child(button)
		if restore_focus and not rows.is_empty():
			(_skills.get_child(0) as Button).grab_focus()
		elif restore_focus:
			grab_focus()
	%SkillInspectorPromptLabel.visible = actor_id.is_empty()
	%SkillInspectorBody.visible = not actor_id.is_empty()
	%SkillInspectorUnitNameLabel.text = view.get("actor_name", "")
	%SkillInspectorStatusLabel.text = view.get("actor_status", "")
	%SkillInspectorCountLabel.text = "Active skills: %d" % rows.size()
	%SkillInspectorEmptyLabel.visible = rows.is_empty() and not actor_id.is_empty()
	for index: int in rows.size():
		var row: Dictionary = rows[index]
		var button := _skills.get_child(index) as Button
		button.set_meta("skill_index", index + 1)
		button.set_meta("skill", row["skill"])
		button.set_meta("availability_text", row["availability_text"])
		button.set_meta("can_activate", row.get("can_activate", false))
		button.set_meta("no_legal_completion", row.get("no_legal_completion", false))
		button.set_meta("selected", row["selected"])
		button.set_pressed_no_signal(row["selected"])
		button.self_modulate = Color(1.0, 0.82, 0.32) if row["selected"] else Color.WHITE
		(button.get_node("NumberLabel") as Label).text = str(index + 1)
		(button.get_node("NameLabel") as Label).text = row["name"]
		(button.get_node("KindLabel") as Label).text = "Active" if row["kind"] == CharacterSkill.Kind.ACTIVE else "Passive"
		var availability := button.get_node("AvailabilityLabel") as Label
		availability.add_theme_font_size_override("font_size", 10)
		availability.text = "Selected" if row["selected"] else ("⊘ NO TARGET" if row.get("no_legal_completion", false) else ("⊘ Locked" if not row["availability_text"].is_empty() and row["kind"] == CharacterSkill.Kind.ACTIVE else ""))
		button.accessibility_name = "%s. %s. %s" % [row["name"], (button.get_node("KindLabel") as Label).text, row["availability_text"]]
		button.accessibility_description = row["tooltip"]
	_attack.disabled = not view.get("attack_enabled", false)
	_swap.disabled = not view.get("swap_enabled", false)
	_attack.focus_mode = Control.FOCUS_ALL
	_swap.focus_mode = Control.FOCUS_ALL
	_attack.set_meta("can_activate", not _attack.disabled)
	_swap.set_meta("can_activate", not _swap.disabled)
	_attack.text = "⊘" if _attack.disabled else ""
	_swap.text = "⊘" if _swap.disabled else ""
	(_attack.get_node("NoTargetBadge") as Label).visible = view.get("attack_no_target", false)
	(_swap.get_node("NoTargetBadge") as Label).visible = view.get("swap_no_target", false)
	_attack.set_pressed_no_signal(view.get("default_mode", 0) == 1)
	_swap.set_pressed_no_signal(view.get("default_mode", 0) == 2)
	_attack.tooltip_text = "Default Attack — " + str(view.get("attack_reason", ""))
	_swap.tooltip_text = "Default Swap — " + str(view.get("swap_reason", ""))
	_attack.accessibility_description = _attack.tooltip_text
	_swap.accessibility_description = _swap.tooltip_text
	accessibility_description = _attack.tooltip_text + "\n" + _swap.tooltip_text
	%ActionMessageLabel.text = view.get("message", "")
	%ActionSummaryLabel.text = view.get("summary", "")
	%ActionSummaryLabel.visible = not %ActionSummaryLabel.text.is_empty()
	_confirm.visible = view.get("confirm_visible", false)
	_confirm.disabled = not view.get("confirm_enabled", false)
	_cancel.visible = view.get("cancel_visible", false)
	_cancel.disabled = not view.get("cancel_enabled", false)
	%ActionConfirmation.visible = view.get("action_region_visible", false) or view.get("default_mode", 0) != 0
	if is_instance_valid(_hovered_skill_button):
		var reason: String = _hovered_skill_button.get_meta("availability_text", "")
		%SkillTooltipAvailabilityLabel.text = reason
		%SkillTooltipAvailabilityLabel.visible = not reason.is_empty()
		%DetailReadout.text = _skill_tooltip_name_label.text + " — " + (reason if not reason.is_empty() else "Ready")
		call_deferred("_position_skill_tooltip", _hovered_skill_button, _skill_tooltip_generation)
	_rendering = false

func _request_attack() -> void:
	if not _attack.disabled:
		default_attack_requested.emit()

func _request_swap() -> void:
	if not _swap.disabled:
		default_swap_requested.emit()

func _select_skill(button: Button) -> void:
	var skill: CharacterSkill = button.get_meta("skill") as CharacterSkill
	if is_instance_valid(skill) and skill.kind == CharacterSkill.Kind.ACTIVE and not button.get_meta("can_activate", false):
		show_skill_details(skill, button)
		return
	if not _rendering:
		skill_selected.emit(button.get_meta("skill_id", &""))

func _pointer_enter(button: Button) -> void:
	if _is_obscured(button):
		return
	_pointer_skill_button = button
	_refresh_details()

func _pointer_exit(button: Button) -> void:
	if _pointer_skill_button == button:
		_pointer_skill_button = null
		_refresh_details()

func _focus_enter(button: Button) -> void:
	if _is_obscured(button):
		return
	_focused_skill_button = button
	_refresh_details()

func _focus_exit(button: Button) -> void:
	if _focused_skill_button == button:
		_focused_skill_button = null
		_refresh_details()

func _refresh_details() -> void:
	if _rendering or not _view.get("details_allowed", true):
		return
	var button: Button = _pointer_skill_button if is_instance_valid(_pointer_skill_button) else _focused_skill_button
	var next_id: StringName = button.get_meta("skill_id", &"") if is_instance_valid(button) else &""
	if is_instance_valid(button):
		show_skill_details(button.get_meta("skill") as CharacterSkill, button)
	else:
		_hide_skill_tooltip()
	if _detail_id != next_id:
		_detail_id = next_id
		skill_preview_changed.emit(next_id)

func set_obscured_rect(rect: Rect2) -> void:
	if rect == _obscured_rect:
		return
	_obscured_rect = rect
	if _is_obscured(_focused_skill_button):
		_focused_skill_button = null
	if _is_obscured(_pointer_skill_button):
		_pointer_skill_button = null
	if is_instance_valid(_hovered_skill_button) and _is_obscured(_hovered_skill_button):
		clear_details()
	elif is_instance_valid(_hovered_skill_button):
		_position_skill_tooltip(_hovered_skill_button, _skill_tooltip_generation)

func _is_obscured(button: Button) -> bool:
	return is_instance_valid(button) and _obscured_rect.has_area() and _obscured_rect.intersects(button.get_global_rect())

func clear_details() -> void:
	var had_preview: bool = not _detail_id.is_empty()
	_pointer_skill_button = null
	_focused_skill_button = null
	_detail_id = &""
	_hide_skill_tooltip()
	%DetailReadout.text = ""
	if had_preview:
		skill_preview_changed.emit(&"")

func _show_bar_details() -> void:
	%DetailReadout.text = accessibility_description.replace("\n", "  |  ")

func _show_default_details(button: Button) -> void:
	%DetailReadout.text = button.tooltip_text
	%DetailReadout.visible = true

func _hide_default_details() -> void:
	%DetailReadout.text = ""

func show_skill_details(skill: CharacterSkill, button: Button) -> void:
	if not is_instance_valid(skill) or not skill.is_valid() or not is_instance_valid(button) or _is_obscured(button):
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
	var availability: String = button.get_meta("availability_text", "")
	%SkillTooltipAvailabilityLabel.text = availability
	%SkillTooltipAvailabilityLabel.visible = not availability.is_empty()
	%DetailReadout.text = skill.display_name + " — " + (availability if not availability.is_empty() else "Ready")
	_skill_tooltip_panel.visible = true
	_skill_tooltip_panel.reset_size()

	call_deferred("_position_skill_tooltip", button, generation)


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
	var proposed := Rect2(Vector2(x, y), tooltip_size)
	if _obscured_rect.has_area() and _obscured_rect.intersects(proposed):
		var right_x: float = _obscured_rect.end.x + SKILL_TOOLTIP_ANCHOR_GAP
		var left_x: float = _obscured_rect.position.x - tooltip_size.x - SKILL_TOOLTIP_ANCHOR_GAP
		if right_x <= max_x:
			x = right_x
		elif left_x >= SKILL_TOOLTIP_VIEWPORT_MARGIN:
			x = left_x
		else:
			_hide_skill_tooltip()
			return
	_skill_tooltip_panel.global_position = Vector2(x, y)



func _hide_skill_tooltip() -> void:
	_skill_tooltip_generation += 1
	_hovered_skill_button = null
	if not is_node_ready():
		return
	_skill_tooltip_panel.visible = false
	%SkillTooltipAvailabilityLabel.text = ""
	%SkillTooltipAvailabilityLabel.visible = false
	%DetailReadout.text = ""
	_skill_tooltip_name_label.text = ""
	_skill_tooltip_kind_label.text = ""
	_skill_tooltip_effect_label.text = ""
	_skill_tooltip_targeting_label.text = ""
	_skill_tooltip_requirements_label.text = ""
	_skill_tooltip_cooldown_label.text = ""
	_skill_tooltip_combo_label.text = ""
	_skill_tooltip_combo_label.visible = false
