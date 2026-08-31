class_name Ac6_2KeywordReactionTests
extends SceneTree

const SOURCE_PATH: String = "res://Scripts/Battle/battle_keyword_source.gd"
const BLEED_PATH: String = "res://Scripts/Battle/battle_bleed_state.gd"
const EXPECTED_TEST_COUNT: int = 13

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_keyword_value_objects()
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC6.2 keyword reactions: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_keyword_value_objects() -> void:
	_expect(ResourceLoader.exists(SOURCE_PATH), "keyword source script exists")
	_expect(ResourceLoader.exists(BLEED_PATH), "Bleed state script exists")
	if not ResourceLoader.exists(SOURCE_PATH) or not ResourceLoader.exists(BLEED_PATH):
		return
	var source_script := load(SOURCE_PATH) as Script
	var bleed_script := load(BLEED_PATH) as Script
	var source: RefCounted = source_script.call("create", &"shivrunner", &"rusted_cut", 7)
	_expect(source != null and source.call("is_valid"), "keyword source is valid")
	_expect(source_script.call("create", &"", &"rusted_cut", 7) == null, "empty source unit is rejected")
	_expect(source_script.call("create", &"shivrunner", &"", 7) == null, "empty source skill is rejected")
	_expect(source_script.call("create", &"shivrunner", &"rusted_cut", 0) == null, "Power below one is rejected")
	var bleed: RefCounted = bleed_script.call("create", source, 1, 2)
	_expect(bleed != null and bleed.call("is_valid"), "Bleed state is valid")
	_expect(bleed_script.call("create", source, 0, 2) == null, "Bleed rejects zero stacks")
	_expect(bleed_script.call("create", source, 4, 2) == null, "Bleed rejects stacks above cap")
	_expect(bleed_script.call("create", source, 1, 0) == null, "Bleed rejects zero duration")
	_expect(bleed.call("add_application", source, 2), "same source can reapply")
	_expect(bleed.get("stacks") == 2 and bleed.get("remaining_actions") == 2, "Bleed adds and refreshes")
	_expect(bleed.call("tick_damage") == 4, "Bleed uses snapshot Power per stack")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
