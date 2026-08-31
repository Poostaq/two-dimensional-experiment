class_name BattleKeywordSource
extends RefCounted

var source_unit_id: StringName:
	get:
		return _source_unit_id
var source_skill_id: StringName:
	get:
		return _source_skill_id
var source_power: int:
	get:
		return _source_power

var _source_unit_id: StringName = &""
var _source_skill_id: StringName = &""
var _source_power: int = 0


static func create(
	candidate_unit_id: StringName,
	candidate_skill_id: StringName,
	candidate_power: int
) -> RefCounted:
	if candidate_unit_id == &"" or candidate_skill_id == &"" or candidate_power < 1:
		return null
	var source: RefCounted = load("res://Scripts/Battle/battle_keyword_source.gd").new()
	source.set("_source_unit_id", candidate_unit_id)
	source.set("_source_skill_id", candidate_skill_id)
	source.set("_source_power", candidate_power)
	return source


func is_valid() -> bool:
	return _source_unit_id != &"" and _source_skill_id != &"" and _source_power >= 1


func duplicate_source() -> RefCounted:
	var source_script := load("res://Scripts/Battle/battle_keyword_source.gd") as Script
	return source_script.call("create", _source_unit_id, _source_skill_id, _source_power) as RefCounted
