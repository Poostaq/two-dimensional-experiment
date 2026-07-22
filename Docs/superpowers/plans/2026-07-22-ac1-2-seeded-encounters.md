# AC1.2 Seeded Encounters Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement `Docs/Specs/AC1/AC1.2_SEEDED_ENCOUNTERS_IMPLEMENTATION_SPEC.md` by adding deterministic Safe/Combat/Boss encounter assignment to the existing 25-hex map, keyed by Run ID.

**Architecture:** Keep encounter generation in `HexMapModel` because AC1.2 is pure map content determinism, not full run lifecycle management. `MapController` stores the active `run_id`, caches the generated layout, exposes layout inspection helpers for tests and later UI, and passes encounter display states to `HexTileView`. The boss coordinate remains fixed at `Vector2i(4, 4)`, the start coordinate is always Safe, and every other valid coordinate is seeded as Safe or Combat by a stable FNV-1a hash.

**Tech Stack:** Godot 4.7, GDScript, GodotIQ for `.gd`/`.tscn` inspection and edits, existing headless `SceneTree` test scripts.

---

## Source Requirements

- `Docs/Specs/AC1/AC1.2_SEEDED_ENCOUNTERS_IMPLEMENTATION_SPEC.md`: formal AC1.2 implementation authority, owner/status metadata, fixture interpretation, traceability, and evidence governance.
- `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`: `AC1.2 - Hex encounter types (Safe/Combat/Boss) are seeded and deterministic per run ID`
- Verification path: start two runs with the same Run ID and confirm Safe/Combat/Boss layout is identical; start a run with a different Run ID and confirm the layout can differ.
- Fixed fixture expectation: although the source criterion says different Run ID layouts "can differ," this plan uses `AC1.2-A` and `AC1.2-B` as deterministic fixtures that must differ by at least one non-boss tile under the AC1.2 hash algorithm.
- AC1.1 implementation is the base: bounded axial 5x5 map, start at `Vector2i(0, 0)`, boss objective at `Vector2i(4, 4)`, scene root uses `MapController`.

## Design Choices

1. Use string encounter constants: `"safe"`, `"combat"`, `"boss"`.
2. Treat an empty Run ID as `"default-run"` so tests and runtime always have deterministic behavior.
3. Keep `get_boss_coord()` authoritative for the boss encounter. No seeded roll can move the boss.
4. Keep `get_start_coord()` Safe so the player never begins on Combat.
5. Use a coordinate-specific FNV-1a hash of `RUN_ID:q:r` so each tile is deterministic and independent of generation order.
6. Use a 40% Safe / 60% Combat split for non-start, non-boss cells. This produces visible variety while keeping AC1.2 limited to type assignment only.
7. Do not add an autoload for Run ID yet. AC5.1 and AC5.3 can introduce run/session ownership when independent run lifecycle becomes required.
8. Keep the AC1.2 completion checkbox unchecked until the implementation evidence package exists.

## File Structure

- Modify: `Scripts/Map/hex_map_model.gd`
  - Add encounter constants, stable hash helpers, seeded layout generation, and per-coordinate encounter lookup.
- Modify: `Scripts/Map/map_controller.gd`
  - Add `run_id`, cache `encounter_types`, expose `set_run_id()`, `get_encounter_layout()`, and `get_encounter_type_at()`, and refresh tiles with encounter states.
- Modify: `Scripts/Map/hex_tile_view.gd`
  - Add Safe and Combat display states while preserving existing Player, Boss, Valid Move, and Default states.
- Create: `Tests/Map/test_ac1_2_encounter_determinism.gd`
  - Pure model determinism coverage.
- Create: `Tests/Map/test_ac1_2_runtime_encounter_layout.gd`
  - Runtime scene/controller determinism coverage.
- Create: `Tests/Map/test_ac1_2_hex_tile_view_states.gd`
  - Tile view display-state coverage for Combat encounter visuals.
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
  - Keep AC1.2 unchecked during implementation.
  - Mark AC1.2 complete only after implementation evidence exists.
- Create: `Docs/Specs/AC1/Evidence/AC1.2/2026-07-22/automated-test.log`
  - Captured command output from AC1.2 automated tests.
- Create: `Docs/Specs/AC1/Evidence/AC1.2/2026-07-22/manual-runtime-check.md`
  - Manual/runtime verification summary.
- Create: `Docs/Specs/AC1/Evidence/AC1.2/2026-07-22/implementation-link.txt`
  - Branch, commit, remote, PR status, and source spec reference.

---

### Task 1: Add Pure Encounter Generation To `HexMapModel`

**Files:**
- Modify: `Scripts/Map/hex_map_model.gd`
- Test: `Tests/Map/test_ac1_2_encounter_determinism.gd`

- [ ] **Step 1: Inspect current file context**

Run through GodotIQ before editing:

```text
godotiq_project_summary(detail="brief")
godotiq_file_context(file="res://Scripts/Map/hex_map_model.gd", detail="brief")
```

Expected: `HexMapModel` extends `RefCounted` and exposes AC1.1 map coordinate helpers.

- [ ] **Step 2: Create the failing model determinism test**

Create `Tests/Map/test_ac1_2_encounter_determinism.gd` with `godotiq_script_ops(op="create", path="res://Tests/Map/test_ac1_2_encounter_determinism.gd")` and the following content:

```gdscript
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
```

- [ ] **Step 3: Run the model test and verify it fails**

Run:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_encounter_determinism.gd
```

Expected: FAIL with missing method or constant errors for `get_encounter_types_for_run`, `get_encounter_type`, or `ENCOUNTER_SAFE`.

- [ ] **Step 4: Replace `HexMapModel` with encounter-aware implementation**

Write this complete content through `godotiq_script_ops(op="write", path="res://Scripts/Map/hex_map_model.gd")`:

```gdscript
class_name HexMapModel
extends RefCounted

const MAP_WIDTH := 5
const MAP_HEIGHT := 5
const NEIGHBOR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]

const DEFAULT_RUN_ID := "default-run"
const ENCOUNTER_NONE := ""
const ENCOUNTER_SAFE := "safe"
const ENCOUNTER_COMBAT := "combat"
const ENCOUNTER_BOSS := "boss"
const SAFE_ENCOUNTER_PERCENT := 40
const HASH_OFFSET_BASIS := 2166136261
const HASH_PRIME := 16777619
const HASH_MODULUS := 4294967296


func get_all_coords() -> Array[Vector2i]:
	var coords: Array[Vector2i] = []
	for q: int in range(MAP_WIDTH):
		for r: int in range(MAP_HEIGHT):
			coords.append(Vector2i(q, r))
	return coords


func is_valid_coord(coord: Vector2i) -> bool:
	return coord.x >= 0 and coord.x < MAP_WIDTH and coord.y >= 0 and coord.y < MAP_HEIGHT


func get_neighbors(coord: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for offset: Vector2i in NEIGHBOR_OFFSETS:
		var neighbor := coord + offset
		if is_valid_coord(neighbor):
			neighbors.append(neighbor)
	return neighbors


func are_adjacent(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	if not is_valid_coord(from_coord) or not is_valid_coord(to_coord):
		return false
	return NEIGHBOR_OFFSETS.has(to_coord - from_coord)


func get_start_coord() -> Vector2i:
	return Vector2i(0, 0)


func get_boss_coord() -> Vector2i:
	return Vector2i(MAP_WIDTH - 1, MAP_HEIGHT - 1)


func get_encounter_types_for_run(run_id: String) -> Dictionary:
	var encounter_types: Dictionary = {}
	for coord: Vector2i in get_all_coords():
		encounter_types[coord] = get_encounter_type(run_id, coord)
	return encounter_types


func get_encounter_type(run_id: String, coord: Vector2i) -> String:
	if not is_valid_coord(coord):
		return ENCOUNTER_NONE
	if coord == get_boss_coord():
		return ENCOUNTER_BOSS
	if coord == get_start_coord():
		return ENCOUNTER_SAFE

	var normalized_run_id := _normalize_run_id(run_id)
	var roll := _stable_hash("%s:%d:%d" % [normalized_run_id, coord.x, coord.y]) % 100
	return ENCOUNTER_SAFE if roll < SAFE_ENCOUNTER_PERCENT else ENCOUNTER_COMBAT


func find_path_exists(from_coord: Vector2i, to_coord: Vector2i) -> bool:
	if not is_valid_coord(from_coord) or not is_valid_coord(to_coord):
		return false
	if from_coord == to_coord:
		return true

	var visited: Dictionary = {from_coord: true}
	var frontier: Array[Vector2i] = [from_coord]
	var index := 0

	while index < frontier.size():
		var current := frontier[index]
		index += 1

		for neighbor: Vector2i in get_neighbors(current):
			if visited.has(neighbor):
				continue
			if neighbor == to_coord:
				return true
			visited[neighbor] = true
			frontier.append(neighbor)

	return false


func _normalize_run_id(run_id: String) -> String:
	return DEFAULT_RUN_ID if run_id.is_empty() else run_id


func _stable_hash(value: String) -> int:
	var hash_value := HASH_OFFSET_BASIS
	for index: int in range(value.length()):
		hash_value = hash_value ^ value.unicode_at(index)
		hash_value = (hash_value * HASH_PRIME) % HASH_MODULUS
	return hash_value
```

- [ ] **Step 5: Validate and run model tests**

Run:

```text
godotiq_validate(target="res://Scripts/Map/hex_map_model.gd", detail="brief")
godotiq_check_errors(scope="res://Scripts/Map/hex_map_model.gd")
```

Then run:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_hex_map_model.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_encounter_determinism.gd
```

Expected:

```text
AC1.1 map logic tests: PASS (7/7)
AC1.2 encounter determinism tests: PASS (6/6)
```

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Map/hex_map_model.gd Tests/Map/test_ac1_2_encounter_determinism.gd
git commit -m "feat: add deterministic encounter generation"
```

---

### Task 2: Surface Run ID And Encounter Layout In `MapController`

**Files:**
- Modify: `Scripts/Map/map_controller.gd`
- Test: `Tests/Map/test_ac1_2_runtime_encounter_layout.gd`

- [ ] **Step 1: Inspect controller impact**

Run:

```text
godotiq_file_context(file="res://Scripts/Map/map_controller.gd", detail="brief")
godotiq_impact_check(file="res://Scripts/Map/map_controller.gd", action="modify_function", target="_ready", change_description="Initialize seeded encounter layout from the active Run ID.", detail="brief")
```

Expected: affected surface is local to `game_world.tscn` and current tests.

- [ ] **Step 2: Create the failing runtime controller test**

Create `Tests/Map/test_ac1_2_runtime_encounter_layout.gd` with `godotiq_script_ops(op="create", path="res://Tests/Map/test_ac1_2_runtime_encounter_layout.gd")` and the following content:

```gdscript
extends SceneTree

const SCENE_PATH := "res://Scenes/game_world.tscn"
const RUN_ID_A := "AC1.2-A"
const RUN_ID_B := "AC1.2-B"
const EXPECTED_TEST_COUNT := 5

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var controller: MapController = await _create_controller()
	if controller != null:
		_test_default_layout_exists(controller)
		_test_same_run_id_keeps_matching_layout(controller)
		_test_different_run_id_changes_layout(controller)
		_test_controller_reports_start_safe(controller)
		_test_controller_reports_boss_boss(controller)

	_report()
	quit(1 if not _failures.is_empty() else 0)


func _create_controller() -> MapController:
	if not ResourceLoader.exists(SCENE_PATH):
		_failures.append("test_scene_exists - missing %s" % SCENE_PATH)
		return null

	var scene: PackedScene = load(SCENE_PATH) as PackedScene
	if scene == null:
		_failures.append("test_scene_exists - failed to load %s" % SCENE_PATH)
		return null

	var instance := scene.instantiate()
	get_root().add_child(instance)
	await process_frame

	var controller := instance as MapController
	if controller == null:
		_failures.append("test_scene_root_is_map_controller - scene root is not MapController")
	return controller


func _test_default_layout_exists(controller: MapController) -> void:
	var layout: Dictionary = controller.get_encounter_layout()
	_assert(layout.size() == 25, "test_default_layout_exists", "expected 25 encounter entries, got %d" % layout.size())


func _test_same_run_id_keeps_matching_layout(controller: MapController) -> void:
	controller.set_run_id(RUN_ID_A)
	var first_layout: Dictionary = controller.get_encounter_layout()

	controller.set_run_id(RUN_ID_A)
	var second_layout: Dictionary = controller.get_encounter_layout()

	_assert(_layouts_match(first_layout, second_layout), "test_same_run_id_keeps_matching_layout", "same Run ID produced different controller layouts")


func _test_different_run_id_changes_layout(controller: MapController) -> void:
	controller.set_run_id(RUN_ID_A)
	var first_layout: Dictionary = controller.get_encounter_layout()

	controller.set_run_id(RUN_ID_B)
	var second_layout: Dictionary = controller.get_encounter_layout()

	_assert(not _layouts_match(first_layout, second_layout), "test_different_run_id_changes_layout", "fixture Run IDs AC1.2-A and AC1.2-B must differ by at least one non-boss tile")


func _test_controller_reports_start_safe(controller: MapController) -> void:
	controller.set_run_id(RUN_ID_A)
	_assert(controller.get_encounter_type_at(Vector2i(0, 0)) == HexMapModel.ENCOUNTER_SAFE, "test_controller_reports_start_safe", "expected start Safe")


func _test_controller_reports_boss_boss(controller: MapController) -> void:
	controller.set_run_id(RUN_ID_A)
	_assert(controller.get_encounter_type_at(Vector2i(4, 4)) == HexMapModel.ENCOUNTER_BOSS, "test_controller_reports_boss_boss", "expected boss Boss")


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
		print("AC1.2 runtime encounter layout tests: PASS (%d/%d)" % [EXPECTED_TEST_COUNT, EXPECTED_TEST_COUNT])
		return

	print("AC1.2 runtime encounter layout tests: FAIL (%d/%d)" % [passed_count, EXPECTED_TEST_COUNT])
	for failure: String in _failures:
		print("FAILED: %s" % failure)
```

- [ ] **Step 3: Run the runtime test and verify it fails**

Run:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_runtime_encounter_layout.gd
```

Expected: FAIL with missing `MapController.get_encounter_layout`, `set_run_id`, or `get_encounter_type_at`.

- [ ] **Step 4: Replace `MapController` with encounter-aware implementation**

Write this complete content through `godotiq_script_ops(op="write", path="res://Scripts/Map/map_controller.gd")`:

```gdscript
class_name MapController
extends Node2D

signal player_moved(coord: Vector2i, move_count: int)

const HEX_MAP_MODEL_PATH := "res://Scripts/Map/hex_map_model.gd"
const TILE_SCENE_PATH := "res://Scenes/map_hex_tile.tscn"
const TILE_RADIUS := 38.0
const TILE_SPACING := 1.08
const TILE_STATE_DEFAULT := "default"
const TILE_STATE_VALID_MOVE := "valid_move"
const TILE_STATE_PLAYER := "player"
const TILE_STATE_SAFE := "safe"
const TILE_STATE_COMBAT := "combat"
const TILE_STATE_BOSS := "boss"
const DEFAULT_RUN_ID := "default-run"
const ACTION_OFFSETS := {
	"map_move_e": Vector2i(1, 0),
	"map_move_ne": Vector2i(1, -1),
	"map_move_nw": Vector2i(0, -1),
	"map_move_w": Vector2i(-1, 0),
	"map_move_sw": Vector2i(-1, 1),
	"map_move_se": Vector2i(0, 1),
}

@onready var _map_root: Node2D = $MapRoot
@onready var _player_marker: Node2D = $MapRoot/PlayerMarker
@onready var _boss_marker: Node2D = $MapRoot/BossMarker

var player_coord := Vector2i.ZERO
var boss_coord := Vector2i.ZERO
var move_count := 0
var run_id := DEFAULT_RUN_ID
var encounter_types: Dictionary = {}

var _model: HexMapModel
var _tile_scene: PackedScene
var _tiles: Dictionary = {}


func _ready() -> void:
	var model_script := load(HEX_MAP_MODEL_PATH) as Script
	_model = model_script.new() as HexMapModel
	_tile_scene = load(TILE_SCENE_PATH) as PackedScene

	player_coord = _model.get_start_coord()
	boss_coord = _model.get_boss_coord()
	encounter_types = _model.get_encounter_types_for_run(run_id)

	_build_tiles()
	_refresh_visual_state()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo:
		return

	for action: String in ACTION_OFFSETS.keys():
		if event.is_action_pressed(action):
			try_move_by_offset(ACTION_OFFSETS[action])
			get_viewport().set_input_as_handled()
			return


func set_run_id(value: String) -> void:
	run_id = DEFAULT_RUN_ID if value.is_empty() else value
	if _model == null:
		return

	encounter_types = _model.get_encounter_types_for_run(run_id)
	_refresh_visual_state()


func get_encounter_layout() -> Dictionary:
	return encounter_types.duplicate()


func get_encounter_type_at(coord: Vector2i) -> String:
	if not encounter_types.has(coord):
		return HexMapModel.ENCOUNTER_NONE
	return encounter_types[coord]


func try_move_by_offset(offset: Vector2i) -> bool:
	return request_move(player_coord + offset)


func request_move(destination: Vector2i) -> bool:
	if not _model.is_valid_coord(destination):
		return false
	if not _model.are_adjacent(player_coord, destination):
		return false

	player_coord = destination
	move_count += 1
	_refresh_visual_state()
	player_moved.emit(player_coord, move_count)
	return true


func axial_to_world(coord: Vector2i) -> Vector2:
	var radius := TILE_RADIUS * TILE_SPACING
	var x := sqrt(3.0) * radius * (float(coord.x) + float(coord.y) * 0.5)
	var y := 1.5 * radius * float(coord.y)
	return Vector2(x, y)


func _build_tiles() -> void:
	for child: Node in _map_root.get_children():
		if child != _player_marker and child != _boss_marker:
			child.queue_free()
	_tiles.clear()

	for coord: Vector2i in _model.get_all_coords():
		var tile := _tile_scene.instantiate()
		_map_root.add_child(tile)
		_map_root.move_child(tile, 0)
		tile.position = axial_to_world(coord)
		tile.configure(coord)
		_tiles[coord] = tile


func _refresh_visual_state() -> void:
	var valid_destinations: Dictionary = {}
	for coord: Vector2i in _model.get_neighbors(player_coord):
		valid_destinations[coord] = true

	for coord: Vector2i in _tiles.keys():
		var tile: Node = _tiles[coord]
		if coord == player_coord:
			tile.set_display_state(TILE_STATE_PLAYER)
		elif coord == boss_coord:
			tile.set_display_state(TILE_STATE_BOSS)
		elif valid_destinations.has(coord):
			tile.set_display_state(TILE_STATE_VALID_MOVE)
		else:
			tile.set_display_state(_get_tile_state_for_encounter(coord))

	_player_marker.position = axial_to_world(player_coord)
	_boss_marker.position = axial_to_world(boss_coord)


func _get_tile_state_for_encounter(coord: Vector2i) -> String:
	match get_encounter_type_at(coord):
		HexMapModel.ENCOUNTER_SAFE:
			return TILE_STATE_SAFE
		HexMapModel.ENCOUNTER_COMBAT:
			return TILE_STATE_COMBAT
		HexMapModel.ENCOUNTER_BOSS:
			return TILE_STATE_BOSS
		_:
			return TILE_STATE_DEFAULT
```

- [ ] **Step 5: Validate and run controller tests**

Run:

```text
godotiq_validate(target="res://Scripts/Map/map_controller.gd", detail="brief")
godotiq_check_errors(scope="res://Scripts/Map/map_controller.gd")
```

Then run:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_map_controller_runtime.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_runtime_encounter_layout.gd
```

Expected:

```text
AC1.1 runtime map controller tests: PASS (8/8)
AC1.2 runtime encounter layout tests: PASS (5/5)
```

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Map/map_controller.gd Tests/Map/test_ac1_2_runtime_encounter_layout.gd
git commit -m "feat: expose seeded encounter layout on map controller"
```

---

### Task 3: Display Safe And Combat Tile States

**Files:**
- Modify: `Scripts/Map/hex_tile_view.gd`
- Test: `Tests/Map/test_ac1_2_hex_tile_view_states.gd`
- Runtime scene: `Scenes/game_world.tscn`

- [ ] **Step 1: Inspect tile view context**

Run:

```text
godotiq_file_context(file="res://Scripts/Map/hex_tile_view.gd", detail="brief")
```

Expected: `HexTileView` exposes `configure()` and `set_display_state()`.

- [ ] **Step 2: Create the failing tile-state test**

Create `Tests/Map/test_ac1_2_hex_tile_view_states.gd` before editing `HexTileView`. The test should instantiate `res://Scenes/map_hex_tile.tscn`, call `set_display_state("combat")`, and assert that `Fill.color` is `Color(0.72, 0.34, 0.22, 1.0)` and `Outline.default_color` is `Color(1.0, 0.74, 0.36, 1.0)`.

Run:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_hex_tile_view_states.gd
```

Expected before the `HexTileView` edit:

```text
AC1.2 hex tile view state tests: FAIL
```

- [ ] **Step 3: Replace `HexTileView` with encounter display states**

Write this complete content through `godotiq_script_ops(op="write", path="res://Scripts/Map/hex_tile_view.gd")`:

```gdscript
class_name HexTileView
extends Node2D

const STATE_DEFAULT := "default"
const STATE_SAFE := "safe"
const STATE_COMBAT := "combat"
const STATE_VALID_MOVE := "valid_move"
const STATE_PLAYER := "player"
const STATE_BOSS := "boss"

@onready var _fill: Polygon2D = $Fill
@onready var _outline: Line2D = $Outline
@onready var _coord_label: Label = $CoordLabel

var coordinate := Vector2i.ZERO


func configure(coord: Vector2i, show_debug_label: bool = false) -> void:
	coordinate = coord
	_coord_label.text = "%d,%d" % [coordinate.x, coordinate.y]
	_coord_label.visible = show_debug_label
	set_display_state(STATE_SAFE)


func set_display_state(state: String) -> void:
	match state:
		STATE_PLAYER:
			_fill.color = Color(0.15, 0.72, 0.95, 1.0)
			_outline.default_color = Color(0.88, 0.98, 1.0, 1.0)
		STATE_BOSS:
			_fill.color = Color(0.85, 0.18, 0.22, 1.0)
			_outline.default_color = Color(1.0, 0.78, 0.18, 1.0)
		STATE_VALID_MOVE:
			_fill.color = Color(0.36, 0.72, 0.38, 1.0)
			_outline.default_color = Color(0.8, 1.0, 0.62, 1.0)
		STATE_COMBAT:
			_fill.color = Color(0.72, 0.34, 0.22, 1.0)
			_outline.default_color = Color(1.0, 0.74, 0.36, 1.0)
		STATE_SAFE:
			_fill.color = Color(0.24, 0.28, 0.34, 1.0)
			_outline.default_color = Color(0.56, 0.63, 0.72, 1.0)
		_:
			_fill.color = Color(0.18, 0.2, 0.24, 1.0)
			_outline.default_color = Color(0.42, 0.46, 0.52, 1.0)
```

- [ ] **Step 4: Validate and run all map tests**

Run:

```text
godotiq_validate(target="res://Scripts/Map/hex_tile_view.gd", detail="brief")
godotiq_check_errors(scope="res://Scripts/Map/hex_tile_view.gd")
```

Then run:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_hex_map_model.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_map_controller_runtime.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_1_runtime_step_counts.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_encounter_determinism.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_runtime_encounter_layout.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_hex_tile_view_states.gd
```

Expected:

```text
AC1.1 map logic tests: PASS (7/7)
AC1.1 runtime map controller tests: PASS (8/8)
AC1.1 runtime step-count check: PASS (8/8)
AC1.2 encounter determinism tests: PASS (6/6)
AC1.2 runtime encounter layout tests: PASS (5/5)
AC1.2 hex tile view state tests: PASS (1/1)
```

- [ ] **Step 5: Runtime visual verification**

Run through GodotIQ:

```text
godotiq_run(action="play")
godotiq_verify_project_runs()
godotiq_read_debug_console()
godotiq_state_inspect(detail="brief", queries=[{"node":"/root/GameWorld","properties":["run_id","encounter_types.size()","get_encounter_type_at(Vector2i(0, 0))","get_encounter_type_at(Vector2i(4, 4))"]}])
```

Expected:

```text
run_id: "default-run"
encounter_types.size(): 25
get_encounter_type_at(Vector2i(0, 0)): "safe"
get_encounter_type_at(Vector2i(4, 4)): "boss"
```

If visual capture is useful for the evidence package, take one screenshot after confirming the runtime state:

```text
godotiq_screenshot(scale=0.25, quality=0.3)
```

- [ ] **Step 6: Commit**

```powershell
git add Scripts/Map/hex_tile_view.gd Tests/Map/test_ac1_2_hex_tile_view_states.gd
git commit -m "feat: display seeded encounter tile states"
```

---

### Task 4: Capture AC1.2 Evidence And Mark The Criterion Complete

**Files:**
- Modify: `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
- Read: `Docs/Specs/AC1/AC1.2_SEEDED_ENCOUNTERS_IMPLEMENTATION_SPEC.md`
- Create: `Docs/Specs/AC1/Evidence/AC1.2/2026-07-22/automated-test.log`
- Create: `Docs/Specs/AC1/Evidence/AC1.2/2026-07-22/manual-runtime-check.md`
- Create: `Docs/Specs/AC1/Evidence/AC1.2/2026-07-22/implementation-link.txt`

- [ ] **Step 1: Capture automated test log**

Create the evidence directory:

```powershell
New-Item -ItemType Directory -Force Docs\Specs\AC1\Evidence\AC1.2\2026-07-22
```

Run all map tests and tee output:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_hex_map_model.gd *> Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\automated-test.log
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_map_controller_runtime.gd *>> Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\automated-test.log
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_1_runtime_step_counts.gd *>> Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\automated-test.log
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_encounter_determinism.gd *>> Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\automated-test.log
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_runtime_encounter_layout.gd *>> Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\automated-test.log
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_hex_tile_view_states.gd *>> Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\automated-test.log
```

Expected log includes:

```text
AC1.1 map logic tests: PASS (7/7)
AC1.1 runtime map controller tests: PASS (8/8)
AC1.1 runtime step-count check: PASS (8/8)
AC1.2 encounter determinism tests: PASS (6/6)
AC1.2 runtime encounter layout tests: PASS (5/5)
AC1.2 hex tile view state tests: PASS (1/1)
```

- [ ] **Step 2: Create manual runtime check**

Create `Docs/Specs/AC1/Evidence/AC1.2/2026-07-22/manual-runtime-check.md`:

```markdown
# AC1.2 Manual Runtime Check

**Date:** 2026-07-22
**Spec:** `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`
**Implementation Spec:** `Docs/Specs/AC1/AC1.2_SEEDED_ENCOUNTERS_IMPLEMENTATION_SPEC.md`
**Acceptance Criterion:** AC1.2 - Hex encounter types (Safe/Combat/Boss) are seeded and deterministic per run ID
**Scene:** `res://Scenes/game_world.tscn`
**Tester:** Codex
**Godot:** Godot 4.7

| Check | Expected | Observed | Result |
|---|---|---|---|
| Start scene with default Run ID. | Runtime map creates 25 encounter entries. | `encounter_types.size()` returned `25`. | PASS |
| Inspect start coordinate. | `Vector2i(0, 0)` is Safe. | `get_encounter_type_at(Vector2i(0, 0))` returned `safe`. | PASS |
| Inspect boss coordinate. | `Vector2i(4, 4)` is Boss. | `get_encounter_type_at(Vector2i(4, 4))` returned `boss`. | PASS |
| Set Run ID to `AC1.2-A` twice. | Safe/Combat/Boss layout is identical both times. | Runtime controller layout comparison returned matching dictionaries. | PASS |
| Set Run ID to `AC1.2-B`. | Fixed fixture layout differs from `AC1.2-A` by at least one non-boss tile. | Runtime controller layout comparison found one or more different non-boss tiles. | PASS |
| Move on the map after encounters are generated. | AC1.1 movement still works and move count increments for valid moves. | Existing AC1.1 runtime step-count check passed. | PASS |

**Overall Result:** PASS
```

- [ ] **Step 3: Create implementation link**

After the implementation commits exist, run:

```powershell
git rev-parse HEAD
git branch --show-current
git remote get-url origin
```

Create `Docs/Specs/AC1/Evidence/AC1.2/2026-07-22/implementation-link.txt`:

```text
Commit: value printed by `git rev-parse HEAD`
Branch: value printed by `git branch --show-current`
Remote: value printed by `git remote get-url origin`
Pull Request: not opened
Source Spec: Docs/Specs/GAME_DESIGN_SPEC_MVP.md
Implementation Spec: Docs/Specs/AC1/AC1.2_SEEDED_ENCOUNTERS_IMPLEMENTATION_SPEC.md
Plan: Docs/superpowers/plans/2026-07-22-ac1-2-seeded-encounters.md
```

- [ ] **Step 4: Mark AC1.2 complete in MVP spec only after evidence exists**

Confirm these files exist and contain current results before changing the MVP checkbox:

```powershell
Test-Path Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\automated-test.log
Test-Path Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\manual-runtime-check.md
Test-Path Docs\Specs\AC1\Evidence\AC1.2\2026-07-22\implementation-link.txt
```

Expected:

```text
True
True
True
```

Modify `Docs/Specs/GAME_DESIGN_SPEC_MVP.md`:

```diff
-- [ ] AC1.2 - Hex encounter types (Safe/Combat/Boss) are seeded and deterministic per run ID
+ [x] AC1.2 - Hex encounter types (Safe/Combat/Boss) are seeded and deterministic per run ID
```

- [ ] **Step 5: Commit evidence**

```powershell
git add Docs/Specs/GAME_DESIGN_SPEC_MVP.md Docs/Specs/AC1/Evidence/AC1.2/2026-07-22
git commit -m "docs: record AC1.2 seeded encounter evidence"
```

---

## Final Verification

Run:

```text
godotiq_validate(target="project", detail="brief")
godotiq_check_errors(scope="project")
```

Run:

```powershell
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_hex_map_model.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_map_controller_runtime.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_1_runtime_step_counts.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_encounter_determinism.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_runtime_encounter_layout.gd
& "D:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script res://Tests/Map/test_ac1_2_hex_tile_view_states.gd
```

Expected:

```text
AC1.1 map logic tests: PASS (7/7)
AC1.1 runtime map controller tests: PASS (8/8)
AC1.1 runtime step-count check: PASS (8/8)
AC1.2 encounter determinism tests: PASS (6/6)
AC1.2 runtime encounter layout tests: PASS (5/5)
AC1.2 hex tile view state tests: PASS (1/1)
```

Run runtime check:

```text
godotiq_run(action="play")
godotiq_verify_project_runs()
godotiq_read_debug_console()
godotiq_state_inspect(detail="brief", queries=[{"node":"/root/GameWorld","properties":["run_id","encounter_types.size()","get_encounter_type_at(Vector2i(0, 0))","get_encounter_type_at(Vector2i(4, 4))"]}])
godotiq_run(action="stop")
```

Expected:

```text
No parser or runtime errors.
encounter_types.size(): 25
start encounter: "safe"
boss encounter: "boss"
```

## Self-Review

- Spec coverage: AC1.2 is covered by pure model determinism, runtime controller determinism, fixed boss assignment, Safe start assignment, and evidence capture.
- Specification authority: `Docs/Specs/AC1/AC1.2_SEEDED_ENCOUNTERS_IMPLEMENTATION_SPEC.md` is the formal implementation spec, while this file is the executable implementation plan.
- Placeholder scan: the plan contains exact file paths, exact scripts, exact commands, and exact expected outputs. The implementation worker must fill `implementation-link.txt` with command output for commit, branch, and remote because those values only exist after commits are made.
- Type consistency: `HexMapModel.ENCOUNTER_SAFE`, `HexMapModel.ENCOUNTER_COMBAT`, and `HexMapModel.ENCOUNTER_BOSS` are defined before controller and tests use them. `MapController.set_run_id()`, `get_encounter_layout()`, and `get_encounter_type_at()` are defined before runtime tests use them.
- Scope check: AC1.2 does not add combat entry, reward handling, Sudden Death, run persistence, or run history. Those remain owned by later acceptance criteria.
