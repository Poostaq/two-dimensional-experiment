class_name WorldDebugDrawer
extends Control

@onready var _panel: PanelContainer = %DrawerPanel
@onready var _handle: Button = %DebugHandle
@onready var _close: Button = %CloseButton
@onready var _scroll: ScrollContainer = %DiagnosticsScroll
@onready var _labels: Dictionary = {
    "hex": %HexDetails, "habitat": %HabitatDetails, "map": %MapDetails,
    "run": %RunDetails, "persistence": %PersistenceDetails,
}

var _presenter: Script = load("res://Scripts/UI/world_debug_presenter.gd")
var _return_focus: WeakRef
var _available: bool = true

func _ready() -> void:
    _handle.pressed.connect(_toggle)
    _close.pressed.connect(set_open.bind(false))
    _panel.hide()
    _handle.tooltip_text = "Open world diagnostics"
    var style: StyleBoxFlat = StyleBoxFlat.new()
    style.bg_color = Color(0.045, 0.065, 0.08, 1.0)
    style.border_color = Color(0.55, 0.48, 0.29)
    style.set_border_width_all(2)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    _panel.add_theme_stylebox_override("panel", style)
    for key: String in _labels:
        var label: Label = _labels[key]
        label.add_theme_font_size_override("font_size", 16)
        label.add_theme_color_override("font_color", Color(0.82, 0.86, 0.88))
    var sections: VBoxContainer = _scroll.get_child(0) as VBoxContainer
    sections.add_theme_constant_override("separation", 10)
    for child: Node in sections.get_children():
        if child.name.ends_with("Heading"):
            (child as Label).add_theme_color_override("font_color", Color(0.87, 0.76, 0.47))

func render(view: Dictionary) -> void:
    var sections: Dictionary = _presenter.format_sections(view.duplicate(true))
    for key: String in _labels:
        var label: Label = _labels[key]
        label.text = String(sections.get(key, "Unavailable"))
        label.accessibility_description = label.text

func set_available(value: bool) -> void:
    _available = value
    if not value:
        set_open(false, false)
    _handle.visible = value
    _handle.disabled = not value

func is_open() -> bool:
    return _panel.visible

func set_open(opened: bool, restore_focus: bool = true) -> void:
    if opened and not _available:
        return
    if is_open() == opened:
        return
    if opened:
        var focused: Control = get_viewport().gui_get_focus_owner()
        _return_focus = weakref(focused) if is_instance_valid(focused) else null
        _panel.show()
        _close.grab_focus()
    else:
        _panel.hide()
        if restore_focus:
            var previous: Control = _return_focus.get_ref() as Control if _return_focus != null else null
            if _can_focus(previous):
                previous.grab_focus()
            elif _can_focus(_handle):
                _handle.grab_focus()
        _return_focus = null
    _handle.tooltip_text = "Close world diagnostics" if opened else "Open world diagnostics"
    _handle.accessibility_name = _handle.tooltip_text

func reset_view() -> void:
    set_open(false, false)
    _return_focus = null
    _scroll.scroll_vertical = 0
    for key: String in _labels:
        var label: Label = _labels[key]
        label.text = ""
        label.accessibility_description = ""

func _toggle() -> void:
    set_open(not is_open())

func _can_focus(control: Control) -> bool:
    return is_instance_valid(control) and control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE and (not control is BaseButton or not (control as BaseButton).disabled)

func _input(event: InputEvent) -> void:
    if not is_open():
        return
    if event is InputEventKey and event.is_pressed():
        var key: InputEventKey = event as InputEventKey
        if key.keycode == KEY_ESCAPE and not key.is_echo():
            set_open(false)
            get_viewport().set_input_as_handled()
        elif key.keycode == KEY_TAB:
            var controls: Array[Control] = [_close, _scroll, _handle]
            var current: int = controls.find(get_viewport().gui_get_focus_owner())
            controls[posmod(current + (-1 if key.shift_pressed else 1), controls.size())].grab_focus()
            get_viewport().set_input_as_handled()
