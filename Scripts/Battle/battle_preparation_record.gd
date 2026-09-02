class_name BattlePreparationRecord
extends RefCounted

enum State {
	NONE,
	OFFERED,
	COMMITTED,
}

enum Choice {
	NONE,
	FRONTLINE_BRIEFING,
	SPARE_PLATING,
}

const STATE_NAMES: Array[String] = ["none", "offered", "committed"]
const CHOICE_NAMES: Array[String] = ["none", "frontline_briefing", "spare_plating"]

var state: State = State.NONE
var preparation_id: StringName = &""
var encounter_coord: Vector2i = Vector2i.ZERO
var encounter_type: String = ""
var setup_key: String = ""
var choice: Choice = Choice.NONE
var target_unit_id: StringName = &""


static func none() -> RefCounted:
	var record_script: GDScript = load("res://Scripts/Battle/battle_preparation_record.gd")
	return record_script.new()


static func offered(
	new_preparation_id: StringName,
	new_encounter_coord: Vector2i,
	new_encounter_type: String,
	new_setup_key: String
) -> RefCounted:
	var record_script: GDScript = load("res://Scripts/Battle/battle_preparation_record.gd")
	var record: RefCounted = record_script.new()
	record.state = State.OFFERED
	record.preparation_id = new_preparation_id
	record.encounter_coord = new_encounter_coord
	record.encounter_type = new_encounter_type.to_lower()
	record.setup_key = new_setup_key
	return record if record.is_valid() else null


static func committed(
	new_preparation_id: StringName,
	new_encounter_coord: Vector2i,
	new_encounter_type: String,
	new_setup_key: String,
	new_choice: Choice,
	new_target_unit_id: StringName = &""
) -> RefCounted:
	var record_script: GDScript = load("res://Scripts/Battle/battle_preparation_record.gd")
	var record: RefCounted = record_script.new()
	record.state = State.COMMITTED
	record.preparation_id = new_preparation_id
	record.encounter_coord = new_encounter_coord
	record.encounter_type = new_encounter_type.to_lower()
	record.setup_key = new_setup_key
	record.choice = new_choice
	record.target_unit_id = new_target_unit_id
	return record if record.is_valid() else null


static func from_dictionary(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "value": null}
	var data := value as Dictionary
	var state_value := String(data.get("state", ""))
	var state_index := STATE_NAMES.find(state_value)
	if state_index < 0:
		return {"ok": false, "value": null}
	if state_index == State.NONE:
		var empty_record := none()
		return {"ok": true, "value": empty_record}
	var coord_value: Variant = data.get("encounter_coord")
	if not coord_value is Array or coord_value.size() != 2:
		return {"ok": false, "value": null}
	if (
		(not coord_value[0] is int and not coord_value[0] is float)
		or (not coord_value[1] is int and not coord_value[1] is float)
	):
		return {"ok": false, "value": null}
	var choice_index := CHOICE_NAMES.find(String(data.get("choice", "none")))
	if choice_index < 0:
		return {"ok": false, "value": null}
	var record_script: GDScript = load("res://Scripts/Battle/battle_preparation_record.gd")
	var record: RefCounted = record_script.new()
	record.state = state_index as State
	record.preparation_id = StringName(String(data.get("preparation_id", "")))
	record.encounter_coord = Vector2i(int(coord_value[0]), int(coord_value[1]))
	record.encounter_type = String(data.get("encounter_type", "")).to_lower()
	record.setup_key = String(data.get("setup_key", ""))
	record.choice = choice_index as Choice
	record.target_unit_id = StringName(String(data.get("target_unit_id", "")))
	if not record.is_valid():
		return {"ok": false, "value": null}
	return {"ok": true, "value": record}


func is_valid() -> bool:
	if state == State.NONE:
		return (
			preparation_id.is_empty()
			and encounter_type.is_empty()
			and setup_key.is_empty()
			and choice == Choice.NONE
			and target_unit_id.is_empty()
		)
	if (
		state not in [State.OFFERED, State.COMMITTED]
		or preparation_id.is_empty()
		or encounter_type != WorldEncounterType.COMBAT
		or setup_key.is_empty()
	):
		return false
	if state == State.OFFERED:
		return choice == Choice.NONE and target_unit_id.is_empty()
	if choice == Choice.FRONTLINE_BRIEFING:
		return not target_unit_id.is_empty()
	if choice == Choice.SPARE_PLATING:
		return target_unit_id.is_empty()
	return false


func to_dictionary() -> Dictionary:
	if state == State.NONE:
		return {"state": STATE_NAMES[State.NONE]}
	return {
		"state": STATE_NAMES[state],
		"preparation_id": String(preparation_id),
		"encounter_coord": [encounter_coord.x, encounter_coord.y],
		"encounter_type": encounter_type,
		"setup_key": setup_key,
		"choice": CHOICE_NAMES[choice],
		"target_unit_id": String(target_unit_id),
	}
