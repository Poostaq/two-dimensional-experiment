class_name GoblinStarterSaveMigrationTests
extends SceneTree

var _failures: Array[String] = []
var _codec: Script = load("res://Scripts/Save/world_run_save_codec_v2.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var generated: Dictionary = HexWorldGeneratorV1.new().generate("golden-alpha")
	var plan: WorldPlan = generated["plan"]
	var formation: Array[StringName] = [&"player_0", &"player_1", &"player_2", &"", &"", &""]
	var consumed: Array[Vector2i] = []
	var state: RefCounted = WorldRunState.create(plan.get_start_coord(), plan.get_boss_coord(), 0, false, false, consumed, formation)
	var health: Dictionary[StringName, int] = {&"player_0": 20, &"player_1": 14, &"player_2": 16}
	state.set_character_hp_snapshot(health)
	var bytes: PackedByteArray = _codec.encode(plan, "golden-alpha", state)
	var root_value: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	_expect(root_value.get("starter_roster_version", -1) == 1, "new encoding identifies Goblin starters")
	var legacy: Dictionary = root_value.duplicate(true)
	legacy.erase("starter_roster_version")
	legacy["world"]["run_state"]["character_hp"] = {"player_0": 20, "player_1": 20, "player_2": 20}
	_expect_health(legacy, health, "unmarked legacy full health caps at authored maxima")
	legacy["starter_roster_version"] = 0
	_expect_health(legacy, health, "explicit legacy version migrates")
	legacy["world"]["run_state"]["character_hp"]["player_1"] = 8
	legacy["world"]["run_state"]["character_hp"]["player_2"] = 12
	_expect_health(legacy, {&"player_0": 20, &"player_1": 8, &"player_2": 12}, "injured legacy health remains exact")
	for invalid_hp: Variant in [21, 0, -1, 15.5, "20"]:
		var invalid: Dictionary = legacy.duplicate(true)
		invalid["world"]["run_state"]["character_hp"]["player_1"] = invalid_hp
		_expect(not _decode(invalid).get("ok", false), "invalid legacy health rejected: " + str(invalid_hp))
	var modern: Dictionary = root_value.duplicate(true)
	modern["world"]["run_state"]["character_hp"]["player_1"] = 20
	var modern_result: Dictionary = _decode(modern)
	_expect(not modern_result.get("ok", false) or modern_result["value"]["run_state"].get_character_hp_snapshot()[&"player_1"] == 20, "modern invalid health is never silently migrated")
	for marker: Variant in [-1, 2, 0.5, "1", true, null]:
		var invalid: Dictionary = root_value.duplicate(true)
		invalid["starter_roster_version"] = marker
		_expect(not _decode(invalid).get("ok", false), "invalid roster marker rejected: " + str(marker))
	var missing_health: Dictionary = legacy.duplicate(true)
	missing_health.erase("starter_roster_version")
	missing_health["world"]["run_state"].erase("character_hp")
	var missing_result: Dictionary = _decode(missing_health)
	_expect(missing_result.get("ok", false), "legacy save without health still decodes")
	if missing_result.get("ok", false):
		_expect(not missing_result["value"]["run_state"].has_character_hp_snapshot(), "absent health remains absent for runtime initialization")
	for failure: String in _failures:
		push_error(failure)
	if _failures.is_empty():
		print("PASS test_goblin_starter_save_migration")
	quit(0 if _failures.is_empty() else 1)

func _decode(value: Dictionary) -> Dictionary:
	return _codec.decode_any(JSON.stringify(value).to_utf8_buffer())

func _expect_health(value: Dictionary, expected: Dictionary, label: String) -> void:
	var result: Dictionary = _decode(value)
	_expect(result.get("ok", false), label + " decodes")
	if result.get("ok", false):
		_expect(result["value"]["run_state"].get_character_hp_snapshot() == expected, label)

func _expect(value: bool, label: String) -> void:
	if not value:
		_failures.append(label)
