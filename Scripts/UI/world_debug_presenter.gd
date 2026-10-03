class_name WorldDebugPresenter
extends RefCounted
## Formats detached diagnostics without reading or mutating gameplay state.

const UNAVAILABLE: String = "Unavailable"


static func format_sections(view: Dictionary) -> Dictionary:
	var town_index: Variant = view.get("town_index")
	var town: String = UNAVAILABLE
	if town_index is int and town_index >= -1:
		town = _value(town_index >= 0)
	var pending_reward: Variant = view.get("pending_reward_battle_id")
	var reward_text: String = "None" if pending_reward is String and pending_reward.is_empty() else _value(pending_reward)
	var habitat: Dictionary = _dictionary(view.get("habitat"))
	var ownership: Dictionary = _dictionary(view.get("ownership"))
	var habitat_cell_counts: Dictionary = _dictionary(view.get("habitat_cell_counts"))
	var habitat_town_counts: Dictionary = _dictionary(view.get("habitat_town_counts"))
	var habitat_ok: bool = habitat.get("ok") == true
	var habitat_id: String = _value(habitat.get("habitat_id")) if habitat_ok else UNAVAILABLE
	if habitat_ok and habitat.get("habitat_id") == "":
		habitat_id = "Not generated"
	var ownership_ok: bool = ownership.get("ok") == true
	var owner: String = UNAVAILABLE
	if ownership_ok:
		owner = _value(ownership.get("clan_id"))
	elif ownership.get("error") == "not_a_town":
		owner = "Not a town"
	var habitat_lines: Array[String] = [
		"Habitat: " + (_value(habitat.get("display_name")) if habitat_ok else UNAVAILABLE),
		"Habitat clan: " + (_value(habitat.get("clan_id")) if habitat_ok else UNAVAILABLE),
		"Habitat source: " + (_value(habitat.get("source")) if habitat_ok else UNAVAILABLE),
		"Habitat ID: " + habitat_id,
		"Town owner: " + owner,
		"Habitat role: " + (_value(habitat.get("role")) if habitat_ok else UNAVAILABLE),
		"Habitat anchor: " + (_value(habitat.get("anchor")) if habitat_ok else UNAVAILABLE),
		"Habitat cell count: " + (_integer(habitat.get("cell_count")) if habitat_ok else UNAVAILABLE),
		"Town ID: " + (_value(ownership.get("town_id")) if ownership_ok else UNAVAILABLE),
		"Town local index: " + (_integer(ownership.get("local_index")) if ownership_ok else UNAVAILABLE),
		"Town habitat ID: " + (_value(ownership.get("habitat_id")) if ownership_ok else UNAVAILABLE),
		"Town role: " + (_value(ownership.get("role")) if ownership_ok else UNAVAILABLE),
		"Town clan: " + (_value(ownership.get("clan_id")) if ownership_ok else UNAVAILABLE),
	]
	if habitat.get("ok") == false:
		habitat_lines.append("Habitat error: " + _value(habitat.get("error")))
	if ownership.get("ok") == false and ownership.get("error") != "not_a_town":
		habitat_lines.append("Ownership error: " + _value(ownership.get("error")))
	return {
		"hex": _lines(view, {
			"Coordinate": "coord", "Terrain": "terrain",
			"Base encounter": "base_encounter", "Effective encounter": "effective_encounter",
			"Consumed": "consumed", "Town index": "town_index",
		}) + "\nTown: " + town,
		"habitat": "\n".join(habitat_lines),
		"map": "\n".join([
			"Neighbors: " + _array(view.get("neighbors")),
			"Valid destinations: " + _array(view.get("destinations")),
			"Road links: " + _roads(view.get("road_links")),
			"Forest clusters: " + _array(view.get("forest_clusters")),
			"World seed: " + _value(view.get("seed")),
			"World version: " + _value(view.get("version")),
			"Generated player start: " + _value(view.get("generated_player_start")),
			"Generated enemy start: " + _value(view.get("generated_enemy_start")),
			"Habitat cells main: " + _integer(habitat_cell_counts.get("main")),
			"Habitat cells ally_0: " + _integer(habitat_cell_counts.get("ally_0")),
			"Habitat cells ally_1: " + _integer(habitat_cell_counts.get("ally_1")),
			"Habitat cells enemy: " + _integer(habitat_cell_counts.get("enemy")),
			"Habitat towns main: " + _integer(habitat_town_counts.get("main")),
			"Habitat towns ally_0: " + _integer(habitat_town_counts.get("ally_0")),
			"Habitat towns ally_1: " + _integer(habitat_town_counts.get("ally_1")),
			"Habitat towns enemy: " + _integer(habitat_town_counts.get("enemy")),
			"Enemy footprint: " + _integer(view.get("enemy_footprint_count")),
			"Generated towns: " + _integer(view.get("generated_town_count")),
			"Generated roads: " + _integer(view.get("generated_road_count")),
		]),
		"run": _lines(view, {
			"Player coordinate": "player_coord", "Boss coordinate": "boss_coord",
			"Moves": "move_count", "Boss active": "boss_active",
			"Boss engaged": "boss_engaged", "Boss defeated": "boss_defeated",
			"Run status": "run_status", "Gold": "gold",
			"Preparation state": "preparation_state",
			"Cache progress": "cache_progress", "Cache ready": "cache_ready",
		}),
		"persistence": _lines(view, {
			"Session applied": "session_applied", "Input blocked": "input_blocked",
			"Active encounter": "active_encounter", "Active battle": "active_battle",
			"Active party": "active_party", "Autosave blocked": "autosave_blocked",
			"Integration failed": "integration_failed",
		}) + "\nPending reward battle ID: " + reward_text,
	}


static func _lines(view: Dictionary, fields: Dictionary) -> String:
	var lines: Array[String] = []
	for label: String in fields:
		lines.append(label + ": " + _value(view.get(fields[label])))
	return "\n".join(lines)


static func _value(value: Variant) -> String:
	if value == null:
		return UNAVAILABLE
	if value is bool:
		return "Yes" if value else "No"
	if value is Vector2i:
		return "(%d, %d)" % [value.x, value.y]
	if value is String or value is StringName:
		return String(value) if not String(value).is_empty() else UNAVAILABLE
	if value is int:
		return str(value)
	return UNAVAILABLE


static func _integer(value: Variant) -> String:
	return str(value) if value is int else UNAVAILABLE


static func _dictionary(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _array(value: Variant) -> String:
	if not value is Array:
		return UNAVAILABLE
	if value.is_empty():
		return "None"
	var values: Array[String] = []
	for item: Variant in value:
		values.append(_value(item))
	return ", ".join(values)


static func _roads(value: Variant) -> String:
	if not value is Array:
		return UNAVAILABLE
	if value.is_empty():
		return "None"
	var links: Array[String] = []
	for item: Variant in value:
		var link: Dictionary = _dictionary(item)
		links.append(_value(link.get("a")) + " -> " + _value(link.get("b")))
	return ", ".join(links)
