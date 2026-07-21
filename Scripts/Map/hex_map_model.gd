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
