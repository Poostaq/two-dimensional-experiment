class_name AC66QuartermasterStateTests
extends SceneTree

const RULES_PATH := "res://Scripts/Run/quartermaster_cache_rules.gd"
const RUN_STATE_PATH := "res://Scripts/Run/world_run_state.gd"
const RECORD_PATH := "res://Scripts/Battle/battle_preparation_record.gd"
const EXPECTED_TEST_COUNT := 17

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(RULES_PATH), "Quartermaster Cache rules exist")
	_expect(ResourceLoader.exists(RUN_STATE_PATH), "world run state exists")
	_expect(ResourceLoader.exists(RECORD_PATH), "canonical preparation record exists")
	if not ResourceLoader.exists(RULES_PATH):
		_finish()
		return
	_test_cache_rules(load(RULES_PATH) as GDScript)
	_test_run_state(load(RUN_STATE_PATH) as GDScript, load(RECORD_PATH) as GDScript)
	_finish()


func _test_cache_rules(rules: GDScript) -> void:
	_expect(
		rules.after_accepted_move(&"brakka_rustbanner", 0, false)
			== {"progress": 1, "ready": false},
		"Brakka accepted move advances Cache"
	)
	_expect(
		rules.after_accepted_move(&"brakka_rustbanner", 3, false)
			== {"progress": 0, "ready": true},
		"fourth accepted move fills Cache"
	)
	_expect(
		rules.after_accepted_move(&"brakka_rustbanner", 0, true)
			== {"progress": 0, "ready": true},
		"ready Cache freezes progress"
	)
	_expect(
		rules.after_accepted_move(&"other_commander", 2, false)
			== {"progress": 2, "ready": false},
		"non-Brakka run does not accrue"
	)
	_expect(rules.after_accepted_move(&"brakka_rustbanner", -1, false).is_empty(), "invalid progress rejects")
	_expect(
		rules.after_consumption(true) == {"progress": 0, "ready": false},
		"consumption restarts an empty cycle"
	)


func _test_run_state(state_script: GDScript, record_script: GDScript) -> void:
	var generated := HexWorldGeneratorV1.new().generate("ac6-6-state")
	_expect(bool(generated.get("ok", false)), "fixture world generates")
	if not bool(generated.get("ok", false)):
		return
	var plan := generated.get("plan") as WorldPlan
	var formation: Array[StringName] = [
		&"starter_vanguard", &"brakka_rustbanner", &"", &"", &"", &"",
	]
	var consumed: Array[Vector2i] = []
	var default_state := state_script.create(
		Vector2i(-8, 0), Vector2i(8, 0), 0, false, false, consumed, formation
	) as RefCounted
	_expect(is_instance_valid(default_state), "legacy constructor defaults remain valid")
	_expect(
		is_instance_valid(default_state)
			and int(default_state.get("cache_move_progress")) == 0
			and not bool(default_state.get("cache_ready"))
			and int((default_state.get("battle_preparation") as RefCounted).get("state"))
				== int(record_script.State.NONE),
		"legacy state defaults Cache and preparation"
	)
	var offered := record_script.offered(
		&"prep-state", Vector2i(-7, 0), WorldEncounterType.COMBAT, "setup-state"
	) as RefCounted
	var offered_state := state_script.create(
		Vector2i(-7, 0), Vector2i(8, 0), 4, false, false, consumed, formation,
		0, true, offered
	) as RefCounted
	_expect(is_instance_valid(offered_state), "ready Cache accepts offered preparation")
	var round_trip := state_script.from_dictionary(offered_state.call("to_dictionary"), plan) as Dictionary
	_expect(bool(round_trip.get("ok", false)), "typed Cache state round trips")
	_expect(
		bool(round_trip.get("ok", false))
			and (round_trip["value"] as RefCounted).call("canonical_key")
				== offered_state.call("canonical_key"),
		"typed round trip is canonical"
	)
	var invalid_progress := offered_state.call("to_dictionary") as Dictionary
	invalid_progress["cache_move_progress"] = 4
	_expect(not bool(state_script.from_dictionary(invalid_progress, plan).get("ok", true)), "progress above three rejects")
	var inconsistent := offered_state.call("to_dictionary") as Dictionary
	inconsistent["cache_ready"] = false
	_expect(not bool(state_script.from_dictionary(inconsistent, plan).get("ok", true)), "offered preparation requires ready Cache")


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("PASS test_ac6_6_quartermaster_state (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
