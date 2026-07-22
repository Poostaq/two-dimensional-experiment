extends SceneTree

const MODEL_PATH := "res://Scripts/Map/hex_map_model.gd"
const RUN_ID_A := "AC1.2-A"
const RUN_ID_B := "AC1.2-B"
const EXPECTED_TEST_COUNT := 6

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var model_script: Variant = _load_model_script()
	if model_script != null:
		var model: HexMapModel = model_script.new() as HexMapModel
		_test_layout_has_one_entry_per_coord(model)
		_test_same_run_id_produces_identical_layout(model)
		_test_different_run_ids_can_produce_different_layouts(model)
		_test_start_is_safe(model)
		_test_boss_is_boss(model)
		_test_non_boss_tiles_are_safe_or_combat(model)

	_report()
	quit(1 if not _failures.is_empty() else 0)


func _load_model_script() -> Variant:
	if not ResourceLoader.exists(MODEL_PATH):
		_failures.append("test_model_script_exists - missing %s" % MODEL_PATH)
		return null

	var model_script: Variant = load(MODEL_PATH)
	if model_script == null:
		_failures.append("test_model_script_exists - failed to load %s" % MODEL_PATH)
	return model_script


func _test_layout_has_one_entry_per_coord(model: HexMapModel) -> void:
	var layout: Dictionary = model.get_encounter_types_for_run(RUN_ID_A)
	var coords: Array[Vector2i] = model.get_all_coords()

	_assert(layout.size() == coords.size(), "test_layout_has_one_entry_per_coord", "expected %d entries, got %d" % [coords.size(), layout.size()])
	for coord: Vector2i in coords:
		_assert(layout.has(coord), "test_layout_has_one_entry_per_coord", "missing coord %s" % coord)


func _test_same_run_id_produces_identical_layout(model: HexMapModel) -> void:
	var first_layout: Dictionary = model.get_encounter_types_for_run(RUN_ID_A)
	var second_layout: Dictionary = model.get_encounter_types_for_run(RUN_ID_A)
	_assert(_layouts_match(first_layout, second_layout), "test_same_run_id_produces_identical_layout", "same Run ID produced different layouts")


func _test_different_run_ids_can_produce_different_layouts(model: HexMapModel) -> void:
	var first_layout: Dictionary = model.get_encounter_types_for_run(RUN_ID_A)
	var second_layout: Dictionary = model.get_encounter_types_for_run(RUN_ID_B)
	_assert(not _layouts_match(first_layout, second_layout), "test_different_run_ids_can_produce_different_layouts", "fixture Run IDs AC1.2-A and AC1.2-B must differ by at least one non-boss tile")


func _test_start_is_safe(model: HexMapModel) -> void:
	var start_coord: Vector2i = model.get_start_coord()
	var encounter_type: String = model.get_encounter_type(RUN_ID_A, start_coord)
	_assert(encounter_type == HexMapModel.ENCOUNTER_SAFE, "test_start_is_safe", "expected start Safe, got %s" % encounter_type)


func _test_boss_is_boss(model: HexMapModel) -> void:
	var boss_coord: Vector2i = model.get_boss_coord()
	var encounter_type: String = model.get_encounter_type(RUN_ID_A, boss_coord)
	_assert(encounter_type == HexMapModel.ENCOUNTER_BOSS, "test_boss_is_boss", "expected boss Boss, got %s" % encounter_type)


func _test_non_boss_tiles_are_safe_or_combat(model: HexMapModel) -> void:
	var layout: Dictionary = model.get_encounter_types_for_run(RUN_ID_A)
	var boss_coord: Vector2i = model.get_boss_coord()
	var safe_count := 0
	var combat_count := 0

	for coord: Vector2i in layout.keys():
		if coord == boss_coord:
			continue

		var encounter_type: String = layout[coord]
		if encounter_type == HexMapModel.ENCOUNTER_SAFE:
			safe_count += 1
		elif encounter_type == HexMapModel.ENCOUNTER_COMBAT:
			combat_count += 1
		else:
			_failures.append("test_non_boss_tiles_are_safe_or_combat - invalid type %s at %s" % [encounter_type, coord])

	_assert(safe_count > 0, "test_non_boss_tiles_are_safe_or_combat", "expected at least one Safe tile")
	_assert(combat_count > 0, "test_non_boss_tiles_are_safe_or_combat", "expected at least one Combat tile")


func _layouts_match(first_layout: Dictionary, second_layout: Dictionary) -> bool:
	if first_layout.size() != second_layout.size():
		return false

	for coord: Vector2i in first_layout.keys():
		if not second_layout.has(coord):
			return false
		if first_layout[coord] != second_layout[coord]:
			return false

	return true


func _assert(condition: bool, test_name: String, reason: String) -> void:
	if not condition:
		_failures.append("%s - %s" % [test_name, reason])


func _report() -> void:
	var passed_count := EXPECTED_TEST_COUNT - _failures.size()
	if _failures.is_empty():
		print("AC1.2 encounter determinism tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return

	print("AC1.2 encounter determinism tests: FAIL (%d/%d)" % [passed_count, EXPECTED_TEST_COUNT])
	for failure: String in _failures:
		print("FAILED: %s" % failure)
