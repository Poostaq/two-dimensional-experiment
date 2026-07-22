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
