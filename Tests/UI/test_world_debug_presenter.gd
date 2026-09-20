class_name WorldDebugPresenterTests
extends SceneTree

const PRESENTER_PATH: String = "res://Scripts/UI/world_debug_presenter.gd"
var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(PRESENTER_PATH), "presenter exists")
	if not ResourceLoader.exists(PRESENTER_PATH):
		_finish()
		return
	var presenter: Script = load(PRESENTER_PATH)
	var view: Dictionary = {
		"coord": Vector2i(2, -1), "terrain": "forest",
		"base_encounter": "combat", "effective_encounter": "safe",
		"consumed": true, "town_index": 3,
		"habitat": {"ok": true, "display_name": "Deepwood", "clan_id": "grove", "source": "generated", "habitat_id": "wood_1"},
		"ownership": {"ok": true, "clan_id": "grove"},
		"neighbors": [Vector2i(1, -1), Vector2i(3, -1)],
		"destinations": [Vector2i(3, -1)],
		"road_links": [{"a": Vector2i(2, -1), "b": Vector2i(3, -1)}],
		"forest_clusters": [4, 7], "seed": "original-seed", "version": 1,
		"player_coord": Vector2i(2, -1), "boss_coord": Vector2i(9, 0),
		"move_count": 12, "boss_active": false, "boss_engaged": false,
		"boss_defeated": false, "run_status": "active", "gold": 100,
		"session_applied": true, "input_blocked": false,
		"active_encounter": false, "active_battle": false, "active_party": false,
		"autosave_blocked": false, "integration_failed": false,
		"pending_reward_battle_id": "battle_1", "preparation_state": "idle",
		"cache_progress": 2, "cache_ready": false,
	}
	var before: Dictionary = view.duplicate(true)
	var result: Dictionary = presenter.call("format_sections", view)
	_expect(result.keys() == ["hex", "habitat", "map", "run", "persistence"], "stable five sections")
	var expected: Dictionary = {
		"hex": ["Coordinate: (2, -1)", "Terrain: forest", "Base encounter: combat", "Effective encounter: safe", "Consumed: Yes", "Town index: 3"],
		"habitat": ["Habitat: Deepwood", "Habitat clan: grove", "Habitat source: generated", "Habitat ID: wood_1", "Town owner: grove"],
		"map": ["Neighbors: (1, -1), (3, -1)", "Valid destinations: (3, -1)", "Road links: (2, -1) -> (3, -1)", "Forest clusters: 4, 7", "World seed: original-seed", "World version: 1"],
		"run": ["Player coordinate: (2, -1)", "Boss coordinate: (9, 0)", "Moves: 12", "Boss active: No", "Boss engaged: No", "Boss defeated: No", "Run status: active", "Gold: 100", "Preparation state: idle", "Cache progress: 2", "Cache ready: No"],
		"persistence": ["Session applied: Yes", "Input blocked: No", "Active encounter: No", "Active battle: No", "Active party: No", "Autosave blocked: No", "Integration failed: No", "Pending reward battle ID: battle_1"],
	}
	for section: String in expected:
		_expect(result.get(section) is String, "%s is text" % section)
		for line: String in expected[section]:
			_expect(str(result.get(section, "")).split("\n").has(line), "exact diagnostic: " + line)
	_expect(view == before, "nested input remains unchanged")
	var empty: Dictionary = presenter.call("format_sections", {})
	for section: String in empty:
		for line: String in str(empty[section]).split("\n"):
			_expect(line.ends_with(": Unavailable"), "absent fields stay unavailable: " + line)
	var nulls: Dictionary = {}
	for key: String in view:
		nulls[key] = null
	_expect(presenter.call("format_sections", nulls) == empty, "null fields stay unavailable")
	view["habitat"] = {"ok": false, "error": "missing_assignment", "display_name": "stale"}
	view["ownership"] = {"ok": false, "error": "not_a_town"}
	result = presenter.call("format_sections", view)
	_expect(result["habitat"].contains("Habitat: Unavailable"), "failed habitat unavailable")
	_expect(result["habitat"].contains("Habitat error: missing_assignment"), "habitat error explicit")
	_expect(not result["habitat"].contains("stale"), "failed habitat does not leak stale display")
	_expect(result["habitat"].contains("Town owner: Not a town"), "non-town explicit")
	view["habitat"] = {"ok": true, "display_name": "Legacy", "habitat_id": "", "source": "legacy", "clan_id": "grove"}
	view["ownership"] = {"ok": false, "error": "invalid_owner"}
	view["road_links"] = []
	view["forest_clusters"] = []
	view["seed"] = "long_seed_".repeat(100)
	result = presenter.call("format_sections", view)
	_expect(result["habitat"].contains("Habitat ID: Not generated"), "legacy habitat ID explicit")
	_expect(result["habitat"].contains("Town owner: Unavailable"), "invalid owner unavailable")
	_expect(result["habitat"].contains("Ownership error: invalid_owner"), "ownership error explicit")
	_expect(result["map"].contains("Road links: None"), "empty roads explicit")
	_expect(result["map"].contains("Forest clusters: None"), "empty forests explicit")
	_expect(result["map"].contains("World seed: " + view["seed"]), "long seed preserved in full")
	for town_case: Dictionary in [
		{"index": 0, "expected": "Yes"}, {"index": 3, "expected": "Yes"},
		{"index": -1, "expected": "No"}, {"index": -2, "expected": "Unavailable"},
		{"index": "0", "expected": "Unavailable"}, {"index": null, "expected": "Unavailable"},
	]:
		result = presenter.call("format_sections", {"town_index": town_case.index})
		_expect(result["hex"].split("\n").has("Town: " + town_case.expected), "explicit town state: " + str(town_case.index))
	result = presenter.call("format_sections", {})
	_expect(result["hex"].split("\n").has("Town: Unavailable"), "absent town unavailable")
	for reward_case: Dictionary in [
		{"id": "", "expected": "None"}, {"id": "battle_1", "expected": "battle_1"},
		{"id": null, "expected": "Unavailable"},
	]:
		result = presenter.call("format_sections", {"pending_reward_battle_id": reward_case.id})
		_expect(result["persistence"].split("\n").has("Pending reward battle ID: " + reward_case.expected), "pending reward known-empty differs from unavailable")
	var object: RefCounted = RefCounted.new()
	result = presenter.call("format_sections", {"terrain": object})
	_expect(result["hex"].contains("Terrain: Unavailable"), "objects never dumped")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("World debug presenter tests: PASS (%d assertions)" % _assertions)
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("World debug presenter tests: FAIL (%d/%d)" % [_failures.size(), _assertions])
	quit(1)
