class_name Ac3_3PartyManagementTests
extends SceneTree

const SCENE_PATH := "res://Scenes/party_management.tscn"
const EXPECTED_TEST_COUNT := 31

var _failures: Array[String] = []
var _assertions: int = 0
var _move_events: Array[Variant] = []
var _placement_events: Array[Variant] = []
var _replacement_events: Array[Variant] = []
var _closed: bool = false
var _cancelled: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	_expect(is_instance_valid(packed), "party management scene loads")
	if not is_instance_valid(packed):
		_finish()
		return
	var party := packed.instantiate() as Control
	get_root().add_child(party)
	await process_frame

	for slot_index: int in 6:
		_expect(is_instance_valid(party.get_node_or_null("%%Slot%d" % slot_index)), "slot %d exists" % slot_index)
	_expect(is_instance_valid(party.get_node_or_null("%DetailsPanel")), "details panel exists")
	_expect(is_instance_valid(party.get_node_or_null("%PendingRecruitRegion")), "pending recruit region exists")
	_expect(is_instance_valid(party.get_node_or_null("%ReturnToMapButton")), "return button exists")
	_expect(is_instance_valid(party.get_node_or_null("%CancelPlacementButton")), "cancel placement button exists")

	party.connect("move_requested", _on_move_requested)
	party.connect("placement_requested", _on_placement_requested)
	party.connect("replacement_requested", _on_replacement_requested)
	party.connect("close_requested", _on_close_requested)
	party.connect("placement_cancelled", _on_placement_cancelled)

	var slots: Array[RunCharacter] = []
	slots.resize(6)
	var starters := RunCharacterCatalog.create_starters()
	slots[0] = starters[0]
	slots[2] = starters[1]
	slots[5] = starters[2]
	party.call("configure_normal", slots)
	await process_frame
	_expect(not (party.get_node("%DetailsPanel") as Control).visible, "details are hidden before selection")
	party.call("select_character", 0, starters[0].character_id)
	await process_frame
	_expect((party.get_node("%DetailsPanel") as Control).visible, "occupied click reveals details")
	_expect((party.get_node("%DetailsNameLabel") as Label).text == starters[0].display_name, "details show selected name")
	party.call("request_move", 0, 2, starters[0].character_id)
	_expect(_move_events.size() == 1 and _move_events[0] == [0, 2, starters[0].character_id], "normal move emits typed payload")
	party.call("request_close")
	_expect(_closed and not (party.get_node("%DetailsPanel") as Control).visible, "close clears details and emits")

	var scout := RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
	party.call("configure_placement", slots, scout)
	await process_frame
	_expect((party.get_node("%PendingRecruitRegion") as Control).visible, "placement mode shows pending recruit")
	party.call("request_placement", 1, scout.character_id)
	_expect(_placement_events.size() == 1 and _placement_events[0] == [1, scout.character_id], "placement emits exact target")
	party.call("request_placement_cancel")
	_expect(_cancelled, "placement cancel emits")

	var full_slots: Array[RunCharacter] = []
	for slot_index: int in 6:
		full_slots.append(_character(StringName("full_%d" % slot_index), "Full %d" % slot_index))
	_cancelled = false
	_expect(PartyManagement.Mode.REPLACEMENT == 2, "replacement mode is a stable typed enum")
	party.call("configure_replacement", full_slots, scout)
	await process_frame
	_expect((party.get_node("%PendingRecruitRegion") as Control).visible, "replacement shows pending recruit")
	_expect((party.get_node("%CancelPlacementButton") as Button).text == "Cancel Replacement", "replacement labels cancel action")
	_expect((party.get_node("Margin/VBox/InstructionLabel") as Label).text.contains("replace"), "replacement explains destructive drop")
	party.call("select_character", 0, full_slots[0].character_id)
	_expect((party.get_node("%DetailsPanel") as Control).visible, "replacement permits target inspection")
	party.call("request_move", 0, 1, full_slots[0].character_id)
	_expect(_move_events.size() == 1, "replacement blocks existing-member movement")
	party.call("request_placement", 0, scout.character_id)
	_expect(_placement_events.size() == 1, "replacement does not emit empty-slot placement")
	party.call("request_replacement", 0, full_slots[0].character_id, scout.character_id)
	_expect(
		_replacement_events.size() == 1
		and _replacement_events[0] == [0, full_slots[0].character_id, scout.character_id],
		"replacement emits exact target and recruit identities"
	)
	party.call("request_replacement", 0, &"stale", scout.character_id)
	party.call("request_replacement", 0, full_slots[0].character_id, &"wrong")
	party.call("request_replacement", -1, full_slots[0].character_id, scout.character_id)
	_expect(_replacement_events.size() == 1, "invalid and stale replacement requests are rejected")
	party.call("request_placement_cancel")
	_expect(_cancelled and not (party.get_node("%DetailsPanel") as Control).visible, "replacement cancel clears details and emits")
	party.call("configure_normal", slots)
	await process_frame
	_expect(not (party.get_node("%PendingRecruitRegion") as Control).visible, "normal reconfiguration clears replacement presentation")
	_expect((party.get_node("%ReturnToMapButton") as Control).visible, "normal mode retains Return to Map")

	party.queue_free()
	await process_frame
	_finish()


func _on_move_requested(source_slot: int, destination_slot: int, character_id: StringName) -> void:
	_move_events.append([source_slot, destination_slot, character_id])


func _on_placement_requested(destination_slot: int, character_id: StringName) -> void:
	_placement_events.append([destination_slot, character_id])


func _on_replacement_requested(
	destination_slot: int,
	expected_character_id: StringName,
	expected_recruit_id: StringName
) -> void:
	_replacement_events.append([destination_slot, expected_character_id, expected_recruit_id])


func _character(id: StringName, display_name: String) -> RunCharacter:
	var skills: Array[CharacterSkill] = []
	return RunCharacter.new(id, display_name, 5, 20, skills)


func _on_close_requested() -> void:
	_closed = true


func _on_placement_cancelled() -> void:
	_cancelled = true


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC3.3 party management tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
