class_name Ac2_8SkillSceneTests
extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	var packed_scene: PackedScene = load("res://Scenes/battle_arena.tscn")
	var arena: Control = packed_scene.instantiate()
	root.add_child(arena)
	_test_action_region(arena)
	_test_target_overlays(arena)
	_test_combo_tooltip_row(arena)
	arena.queue_free()
	if failures.is_empty():
		print("AC2.8 skill scene tests: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("AC2.8 skill scene tests: FAIL (%d)" % failures.size())
		quit(1)


func _test_action_region(arena: Control) -> void:
	var region: Control = arena.get_node_or_null("%SkillActionRegion")
	var message: Label = arena.get_node_or_null("%SkillActionMessageLabel")
	var summary: Label = arena.get_node_or_null("%SkillActionSummaryLabel")
	var confirm: Button = arena.get_node_or_null("%SkillConfirmButton")
	var cancel: Button = arena.get_node_or_null("%SkillCancelButton")
	_expect(is_instance_valid(region), "SkillActionRegion must exist in the skill panel.")
	_expect(is_instance_valid(message), "SkillActionMessageLabel must exist.")
	_expect(is_instance_valid(summary), "SkillActionSummaryLabel must exist.")
	_expect(is_instance_valid(confirm), "SkillConfirmButton must exist.")
	_expect(is_instance_valid(cancel), "SkillCancelButton must exist.")
	if is_instance_valid(region):
		_expect(not region.visible, "SkillActionRegion must be hidden initially.")
	if is_instance_valid(confirm):
		_expect(confirm.disabled, "SkillConfirmButton must be disabled initially.")


func _test_target_overlays(arena: Control) -> void:
	var overlays: Array[Node] = arena.find_children("TargetIndicatorOverlay", "Panel", true, false)
	_expect(overlays.size() == 12, "Every formation slot must own one target overlay.")
	for overlay: Panel in overlays:
		_expect(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Target overlays must ignore mouse input.")
		_expect(not overlay.visible, "Target overlays must be hidden initially.")
		_expect(overlay.get_parent() is PanelContainer, "Target overlays must be owned by formation slots.")


func _test_combo_tooltip_row(arena: Control) -> void:
	var combo_label: Label = arena.get_node_or_null("%SkillTooltipComboLabel")
	_expect(is_instance_valid(combo_label), "SkillTooltipComboLabel must be scene-owned.")
	if is_instance_valid(combo_label):
		_expect(not combo_label.visible, "Combo tooltip row must be hidden initially.")
		_expect(combo_label.text.is_empty(), "Hidden Combo tooltip row must start empty.")
		_expect(
			combo_label.custom_minimum_size.x >= 260.0,
			"Combo tooltip row must reserve readable wrapping width."
		)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
