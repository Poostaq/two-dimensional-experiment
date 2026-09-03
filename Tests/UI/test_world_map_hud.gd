class_name WorldMapHudTests
extends SceneTree

const SCENE_PATH := "res://Scenes/world_map_hud.tscn"
const EXPECTED_TEST_COUNT := 42

var _failures: Array[String] = []
var _assertions: int = 0
var _party_requests: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_expect(is_instance_valid(packed), "world map HUD scene loads")
	if not is_instance_valid(packed):
		_finish()
		return
	var hud := packed.instantiate() as Control
	get_root().add_child(hud)
	await process_frame

	var top_bar := hud.get_node("TopBar") as Control
	var cache := hud.get_node("%CacheStatusLabel") as Control
	var remaining := hud.get_node("%RemainingLabel") as Control
	var boss := hud.get_node("%BossStateLabel") as Control
	var formation := hud.get_node("FormationPanel") as Control
	var manage_button := hud.get_node("%ManagePartyButton") as Control
	_expect(is_equal_approx(_rect(top_bar).position.x, 0.0), "top bar is flush left")
	_expect(is_equal_approx(_rect(top_bar).size.x, hud.size.x), "top bar spans the viewport")
	_expect(_rect(top_bar).size.y <= 48.0, "top bar is compact")
	_expect(_rect(cache).position.x < hud.size.x * 0.25, "Cache information is left aligned")
	_expect(_rect(remaining).end.x <= _rect(boss).position.x, "boss countdown precedes boss state")
	_expect(_rect(boss).end.x >= hud.size.x - 24.0, "boss information is right aligned")
	_expect(is_equal_approx(_rect(formation).position.x, 0.0), "party preview is flush left")
	_expect(_rect(formation).size.x <= 260.0, "party preview is narrow")
	_expect(_rect(formation).encloses(_rect(manage_button)), "Manage Party is inside party preview")
	_expect(_rect(manage_button).size.x < _rect(formation).size.x, "Manage Party is narrower than party preview")
	_expect(abs(_rect(manage_button).get_center().x - _rect(formation).get_center().x) <= 1.0, "Manage Party is centered")

	_expect((hud.get_node("%BackLineLabel") as Label).text == "BACK", "back column is labeled Back")
	_expect((hud.get_node("%FrontLineLabel") as Label).text == "FRONT", "front column is labeled Front")
	for index: int in 3:
		_expect(is_instance_valid(hud.get_node_or_null("%%BackSlot%d" % index)), "back slot %d exists" % index)
		_expect(is_instance_valid(hud.get_node_or_null("%%FrontSlot%d" % index)), "front slot %d exists" % index)
		_expect(_has_visible_border(hud.get_node("%%BackSlot%d" % index) as Label), "back slot %d has a border" % index)
		_expect(_has_visible_border(hud.get_node("%%FrontSlot%d" % index) as Label), "front slot %d has a border" % index)

	hud.call("set_turn_state", 29, false)
	_expect((hud.get_node("%MoveCountLabel") as Label).text == "MOVES 29 / 30", "move count and threshold are exact")
	_expect((hud.get_node("%RemainingLabel") as Label).text == "1 MOVE UNTIL BOSS ACTIVATES", "remaining countdown is exact")
	_expect((hud.get_node("%BossStateLabel") as Label).text == "BOSS DORMANT", "dormant state is explicit")
	hud.call("set_turn_state", 30, true)
	_expect((hud.get_node("%RemainingLabel") as Label).text == "BOSS ACTIVE", "active countdown is explicit")
	_expect((hud.get_node("%BossStateLabel") as Label).text == "BOSS PURSUING", "active pursuit state is explicit")

	var slots: Array[RunCharacter] = []
	slots.resize(6)
	var starters := RunCharacterCatalog.create_starters()
	slots[0] = starters[0]
	slots[3] = starters[1]
	hud.call("set_formation", slots)
	_expect(
		(hud.get_node("%FrontSlot0") as Label).text == starters[0].display_name,
		"formation slot 0 appears in front slot 0"
	)
	_expect(
		(hud.get_node("%FrontSlot1") as Label).text == "Empty",
		"empty front slot is explicit"
	)
	_expect(
		(hud.get_node("%BackSlot0") as Label).text == starters[1].display_name,
		"formation slot 3 appears in back slot 0"
	)
	_expect(
		(hud.get_node("%BackSlot1") as Label).text == "Empty",
		"empty back slot is explicit"
	)

	var terrain_tags: Array[String] = ["forest", "road"]
	hud.call("set_context", "combat", terrain_tags, true)
	_expect((hud.get_node("%InstructionLabel") as Label).text == "Choose a highlighted neighbouring hex.", "valid-neighbour instruction is exact")
	var details := (hud.get_node("%ContextLabel") as Label).text
	_expect(details.contains("Combat") and details.contains("Forest") and details.contains("Road"), "context shows encounter and terrain")
	var no_terrain: Array[String] = []
	hud.call("set_context", "safe", no_terrain, false)
	_expect((hud.get_node("%InstructionLabel") as Label).text == "Inspect a neighbouring hex.", "invalid destination guidance is distinct")

	hud.connect("party_requested", _on_party_requested)
	hud.call("set_party_available", false)
	_expect((hud.get_node("%ManagePartyButton") as Button).disabled, "Party access can be blocked")
	(hud.get_node("%ManagePartyButton") as Button).pressed.emit()
	_expect(_party_requests == 0, "blocked Party button emits nothing")
	hud.call("set_party_available", true)
	_expect(not (hud.get_node("%ManagePartyButton") as Button).disabled, "Party access can be enabled")
	(hud.get_node("%ManagePartyButton") as Button).pressed.emit()
	_expect(_party_requests == 1, "enabled Party button emits one request")

	hud.queue_free()
	await process_frame
	_finish()


func _rect(control: Control) -> Rect2:
	return control.get_global_rect()


func _has_visible_border(label: Label) -> bool:
	var style := label.get_theme_stylebox("normal") as StyleBoxFlat
	return (
		is_instance_valid(style)
		and style.border_width_left > 0
		and style.border_width_top > 0
		and style.border_width_right > 0
		and style.border_width_bottom > 0
	)


func _on_party_requested() -> void:
	_party_requests += 1


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("World map HUD tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
