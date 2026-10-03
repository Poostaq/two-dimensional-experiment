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
		"habitat": ["Habitat: Deepwood", "Habitat clan: grove", "Habitat source: generated", "Habitat ID: wood_1", "Town owner: grove", "Habitat role: Unavailable", "Habitat anchor: Unavailable", "Habitat cell count: Unavailable", "Town ID: Unavailable", "Town local index: Unavailable", "Town habitat ID: Unavailable", "Town role: Unavailable", "Town clan: grove"],
		"map": ["Neighbors: (1, -1), (3, -1)", "Valid destinations: (3, -1)", "Road links: (2, -1) -> (3, -1)", "Forest clusters: 4, 7", "World seed: original-seed", "World version: 1", "Generated player start: Unavailable", "Generated enemy start: Unavailable", "Habitat cells main: Unavailable", "Habitat cells ally_0: Unavailable", "Habitat cells ally_1: Unavailable", "Habitat cells enemy: Unavailable", "Habitat towns main: Unavailable", "Habitat towns ally_0: Unavailable", "Habitat towns ally_1: Unavailable", "Habitat towns enemy: Unavailable", "Enemy footprint: Unavailable", "Generated towns: Unavailable", "Generated roads: Unavailable"],
		"run": ["Player coordinate: (2, -1)", "Boss coordinate: (9, 0)", "Moves: 12", "Boss active: No", "Boss engaged: No", "Boss defeated: No", "Run status: active", "Gold: 100", "Preparation state: idle", "Cache progress: 2", "Cache ready: No"],
		"persistence": ["Session applied: Yes", "Input blocked: No", "Active encounter: No", "Active battle: No", "Active party: No", "Autosave blocked: No", "Integration failed: No", "Pending reward battle ID: battle_1"],
	}
	for section: String in expected:
		_expect(result.get(section) is String, "%s is text" % section)
		for line: String in expected[section]:
			_expect(str(result.get(section, "")).split("\n").has(line), "exact diagnostic: " + line)
	_expect(view == before, "nested input remains unchanged")
	var v2_view: Dictionary = view.duplicate(true)
	v2_view.merge({
		"version": 2,
		"generated_player_start": Vector2i(8, 0),
		"generated_enemy_start": Vector2i(-8, 0),
		"habitat_cell_counts": {"main": 69, "ally_0": 70, "ally_1": 69, "enemy": 9},
		"habitat_town_counts": {"main": 3, "ally_0": 3, "ally_1": 3, "enemy": 0},
		"enemy_footprint_count": 9,
		"generated_town_count": 9,
		"generated_road_count": 0,
	})
	v2_view["habitat"] = {
		"ok": true, "display_name": "Ally 0", "clan_id": &"orc",
		"source": "Generated world v2", "habitat_id": &"ally_0", "role": "ally",
		"anchor": Vector2i(1, -2), "cell_count": 70,
	}
	v2_view["ownership"] = {
		"ok": true, "town_id": &"ally_0_town_2", "local_index": 2,
		"habitat_id": &"ally_0", "role": "ally", "clan_id": &"orc",
	}
	var v2_before: Dictionary = v2_view.duplicate(true)
	for repeat: int in 3:
		result = presenter.call("format_sections", v2_view)
		_expect(result["habitat"].split("\n") == PackedStringArray([
			"Habitat: Ally 0", "Habitat clan: orc", "Habitat source: Generated world v2",
			"Habitat ID: ally_0", "Town owner: orc", "Habitat role: ally",
			"Habitat anchor: (1, -2)", "Habitat cell count: 70",
			"Town ID: ally_0_town_2", "Town local index: 2",
			"Town habitat ID: ally_0", "Town role: ally", "Town clan: orc",
		]), "V2 habitat diagnostics are exact and stable")
		for line: String in [
			"Generated player start: (8, 0)", "Generated enemy start: (-8, 0)",
			"Habitat cells main: 69", "Habitat cells ally_0: 70",
			"Habitat cells ally_1: 69", "Habitat cells enemy: 9",
			"Habitat towns main: 3", "Habitat towns ally_0: 3",
			"Habitat towns ally_1: 3", "Habitat towns enemy: 0",
			"Enemy footprint: 9", "Generated towns: 9", "Generated roads: 0",
		]:
			_expect(result["map"].split("\n").has(line), "exact V2 map diagnostic: " + line)
	_expect(v2_view == v2_before, "repeated V2 formatting preserves nested input")
	var no_town: Dictionary = v2_view.duplicate(true)
	no_town["ownership"] = {"ok": false, "error": &"not_a_town"}
	result = presenter.call("format_sections", no_town)
	_expect(result["habitat"].split("\n").has("Town owner: Not a town"), "V2 non-town remains explicit")
	_expect(result["habitat"].split("\n").has("Town ID: Unavailable"), "V2 non-town ID unavailable")
	var malformed: Dictionary = v2_view.duplicate(true)
	malformed["habitat"] = {"ok": true, "anchor": [1, -2], "cell_count": "70"}
	malformed["ownership"] = "bad"
	malformed["habitat_cell_counts"] = {"main": "69"}
	malformed["habitat_town_counts"] = []
	result = presenter.call("format_sections", malformed)
	for line: String in [
		"Habitat anchor: Unavailable", "Habitat cell count: Unavailable",
		"Town ID: Unavailable", "Town clan: Unavailable",
	]:
		_expect(result["habitat"].split("\n").has(line), "malformed habitat value is safe: " + line)
	_expect(result["map"].split("\n").has("Habitat cells main: Unavailable"), "malformed cell count unavailable")
	_expect(result["map"].split("\n").has("Habitat towns main: Unavailable"), "malformed town counts unavailable")
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
