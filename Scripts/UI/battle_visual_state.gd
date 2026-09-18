class_name BattleVisualState
extends RefCounted

class Request extends RefCounted:
	var occupied: bool = false
	var active: bool = false
	var current_actor: bool = false
	var ribbon_preview: bool = false
	var action_committed: bool = false
	var valid_target: bool = false
	var selected_target: bool = false
	var hover_target: bool = false
	var action_kind: StringName = &"skill"
	var unavailable_reason: String = ""

class Layers extends RefCounted:
	var actor_frame: bool = false
	var interaction_spotlight: bool = false
	var target_border: StringName = &""
	var target_glyph: StringName = &""
	var selection_marker: bool = false
	var availability_treatment: StringName = &""
	var reason_text: String = ""

static func resolve(value: Request) -> Layers:
	var result := Layers.new()
	if not value.occupied:
		return result
	result.actor_frame = value.active and value.current_actor
	result.interaction_spotlight = value.active and value.ribbon_preview
	result.reason_text = value.unavailable_reason
	if not value.active or not value.unavailable_reason.is_empty():
		result.availability_treatment = &"unavailable"
		return result
	if value.action_committed:
		if value.selected_target and value.valid_target:
			result.target_border = &"selected"
			result.selection_marker = true
		elif value.valid_target:
			result.target_border = &"valid"
	elif value.hover_target:
		result.target_border = &"preview"
		result.interaction_spotlight = true
	if not result.target_border.is_empty():
		result.target_glyph = value.action_kind
	return result
