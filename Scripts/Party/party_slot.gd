class_name PartySlot
extends PanelContainer

signal character_clicked(slot_index: int, character_id: StringName)
signal character_dropped(source_slot: int, destination_slot: int, character_id: StringName)
signal pending_recruit_dropped(destination_slot: int, character_id: StringName)

const CARD_MINIMUM_SIZE := Vector2(260.0, 82.0)
const HP_BAR_MARGIN := 8.0
const HP_BAR_HEIGHT := 16.0
const HP_COLOR := Color(0.13, 0.77, 0.37)
const EMPTY_COLOR := Color(0.10, 0.13, 0.18)
const CARD_COLOR := Color(0.12, 0.16, 0.22)
const SELECTED_COLOR := Color(0.23, 0.51, 0.96)
const DROP_COLOR := Color(0.96, 0.75, 0.18)

var slot_index: int = -1
var character: RunCharacter
var drag_enabled: bool = false
var accepts_existing: bool = false
var accepts_pending: bool = false
var selected: bool = false
var drop_highlighted: bool = false


func _ready() -> void:
	custom_minimum_size = CARD_MINIMUM_SIZE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	gui_input.connect(_on_gui_input)
	queue_redraw()


func configure(
	index: int,
	value: RunCharacter,
	can_drag: bool,
	can_accept_existing: bool,
	can_accept_pending: bool
) -> void:
	slot_index = index
	character = value
	drag_enabled = can_drag
	accepts_existing = can_accept_existing
	accepts_pending = can_accept_pending
	mouse_default_cursor_shape = (
		Control.CURSOR_DRAG if drag_enabled and is_instance_valid(character)
		else Control.CURSOR_POINTING_HAND
	)
	queue_redraw()


func clear_transient_state() -> void:
	selected = false
	drop_highlighted = false
	queue_redraw()


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func _draw() -> void:
	var background := CARD_COLOR if is_instance_valid(character) else EMPTY_COLOR
	draw_rect(Rect2(Vector2.ZERO, size), background, true)
	var border_color := DROP_COLOR if drop_highlighted else SELECTED_COLOR if selected else Color(0.29, 0.35, 0.44)
	draw_rect(Rect2(Vector2.ONE, size - Vector2(2.0, 2.0)), border_color, false, 2.0)
	if not is_instance_valid(character):
		draw_string(ThemeDB.fallback_font, Vector2(12.0, 34.0), "Empty Slot %d" % slot_index, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color(0.62, 0.67, 0.75))
		return
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 25.0), character.display_name, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)
	draw_string(ThemeDB.fallback_font, Vector2(12.0, 47.0), "Slot %d   Speed %d" % [slot_index, character.base_speed], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color(0.75, 0.80, 0.88))
	var hp_rect := Rect2(
		Vector2(HP_BAR_MARGIN, size.y - HP_BAR_HEIGHT - HP_BAR_MARGIN),
		Vector2(size.x - HP_BAR_MARGIN * 2.0, HP_BAR_HEIGHT)
	)
	draw_rect(hp_rect, Color(0.12, 0.16, 0.20), true)
	draw_rect(hp_rect, HP_COLOR, true)
	draw_string(
		ThemeDB.fallback_font,
		Vector2(hp_rect.position.x, hp_rect.position.y + 13.0),
		"%d / %d HP" % [character.max_hp, character.max_hp],
		HORIZONTAL_ALIGNMENT_CENTER,
		hp_rect.size.x,
		12,
		Color.WHITE
	)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not drag_enabled or not is_instance_valid(character):
		return null
	var preview := Label.new()
	preview.text = character.display_name
	preview.add_theme_font_size_override("font_size", 18)
	set_drag_preview(preview)
	return {
		"source_slot": slot_index,
		"character_id": character.character_id,
		"pending": slot_index < 0,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary or not data.has("character_id"):
		drop_highlighted = false
		queue_redraw()
		return false
	var pending := bool(data.get("pending", false))
	var accepted := accepts_pending and pending or accepts_existing and not pending
	if pending and is_instance_valid(character):
		accepted = false
	drop_highlighted = accepted
	queue_redraw()
	return accepted


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_highlighted = false
	queue_redraw()
	if not _can_drop_data(Vector2.ZERO, data):
		return
	if bool(data.get("pending", false)):
		pending_recruit_dropped.emit(slot_index, StringName(data["character_id"]))
	else:
		character_dropped.emit(
			int(data["source_slot"]),
			slot_index,
			StringName(data["character_id"])
		)


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		drop_highlighted = false
		queue_redraw()


func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		is_instance_valid(mouse_event)
		and mouse_event.button_index == MOUSE_BUTTON_LEFT
		and mouse_event.pressed
		and is_instance_valid(character)
	):
		character_clicked.emit(slot_index, character.character_id)
