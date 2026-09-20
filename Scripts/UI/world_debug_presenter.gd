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
	var habitat_ok: bool = habitat.get("ok") == true
	var habitat_id: String = _value(habitat.get("habitat_id")) if habitat_ok else UNAVAILABLE
	if habitat_ok and habitat.get("habitat_id") == "":
		habitat_id = "Not generated"
	var owner: String = UNAVAILABLE
	if ownership.get("ok") == true:
		owner = _value(ownership.get("clan_id"))
	elif ownership.get("error") == "not_a_town":
		owner = "Not a town"
	var habitat_lines: Array[String] = [
		"Habitat: " + (_value(habitat.get("display_name")) if habitat_ok else UNAVAILABLE),
		"Habitat clan: " + (_value(habitat.get("clan_id")) if habitat_ok else UNAVAILABLE),
		"Habitat source: " + (_value(habitat.get("source")) if habitat_ok else UNAVAILABLE),
		"Habitat ID: " + habitat_id,
		"Town owner: " + owner,
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
