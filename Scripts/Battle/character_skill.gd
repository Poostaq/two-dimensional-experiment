class_name CharacterSkill
extends RefCounted

enum Kind {
	ACTIVE,
	PASSIVE,
}

var skill_id: StringName:
	get:
		return _skill_id
var display_name: String:
	get:
		return _display_name
var kind: Kind:
	get:
		return _kind

var _skill_id: StringName = &""
var _display_name: String = ""
var _kind: Kind = Kind.ACTIVE
var _is_valid: bool = false


func _init(id: StringName, name: String, skill_kind: int) -> void:
	if not is_valid_definition(id, name, skill_kind):
		push_error("CharacterSkill requires non-blank identity and an Active or Passive kind.")
		return
	_skill_id = id
	_display_name = name
	_kind = skill_kind as Kind
	_is_valid = true


static func create(id: StringName, name: String, skill_kind: int) -> CharacterSkill:
	var skill := CharacterSkill.new(id, name, skill_kind)
	return skill if skill.is_valid() else null


static func is_valid_definition(id: StringName, name: String, skill_kind: int) -> bool:
	return (
		not String(id).strip_edges().is_empty()
		and not name.strip_edges().is_empty()
		and skill_kind in [Kind.ACTIVE, Kind.PASSIVE]
	)


func is_valid() -> bool:
	return _is_valid


func duplicate_skill() -> CharacterSkill:
	if not _is_valid:
		return null
	return CharacterSkill.new(_skill_id, _display_name, _kind)
