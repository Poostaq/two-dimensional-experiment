class_name BattleSetupIdentity
extends RefCounted

var encounter_coord: Vector2i:
	get:
		return _encounter_coord
var encounter_type: String:
	get:
		return _encounter_type
var unit_rows: Array[Dictionary]:
	get:
		return _unit_rows.duplicate(true)
var canonical_key: String:
	get:
		return _canonical_key

var _encounter_coord: Vector2i = Vector2i.ZERO
var _encounter_type: String = ""
var _unit_rows: Array[Dictionary] = []
var _canonical_key: String = ""


static func capture(
	coord: Vector2i,
	type: String,
	units: Array[BattleUnitState]
) -> RefCounted:
	var normalized_type: String = type.to_lower()
	if normalized_type != WorldEncounterType.COMBAT:
		return null
	var seen: Dictionary[StringName, bool] = {}
	var rows: Array[Dictionary] = []
	for unit: BattleUnitState in units:
		if not is_instance_valid(unit) or unit.unit_id.is_empty() or seen.has(unit.unit_id):
			return null
		if unit.slot_index < 0:
			return null
		seen[unit.unit_id] = true
		rows.append({
			"unit_id": String(unit.unit_id),
			"side": int(unit.side),
			"slot_index": unit.slot_index,
			"active": unit.is_active(),
		})
	rows.sort_custom(_row_precedes)
	var identity_script: GDScript = load("res://Scripts/Battle/battle_setup_identity.gd")
	var identity: RefCounted = identity_script.new()
	identity._encounter_coord = coord
	identity._encounter_type = normalized_type
	identity._unit_rows = rows.duplicate(true)
	identity._canonical_key = JSON.stringify(identity.to_dictionary()).sha256_text()
	return identity


func matches(other: RefCounted) -> bool:
	return (
		is_instance_valid(other)
		and not _canonical_key.is_empty()
		and _canonical_key == other.canonical_key
	)


func to_dictionary() -> Dictionary:
	return {
		"encounter_coord": [_encounter_coord.x, _encounter_coord.y],
		"encounter_type": _encounter_type,
		"units": _unit_rows.duplicate(true),
	}


static func _row_precedes(left: Dictionary, right: Dictionary) -> bool:
	var left_key := "%d:%08d:%s" % [
		int(left.get("side", -1)),
		int(left.get("slot_index", -1)),
		String(left.get("unit_id", "")),
	]
	var right_key := "%d:%08d:%s" % [
		int(right.get("side", -1)),
		int(right.get("slot_index", -1)),
		String(right.get("unit_id", "")),
	]
	return left_key < right_key
