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
var effect_text: String:
	get:
		return _effect_text
var targeting_text: String:
	get:
		return _targeting_text
var requirements_text: String:
	get:
		return _requirements_text
var cooldown_text: String:
	get:
		return _cooldown_text

var _skill_id: StringName = &""
var _display_name: String = ""
var _kind: Kind = Kind.ACTIVE
var _effect_text: String = ""
var _targeting_text: String = ""
var _requirements_text: String = ""
var _cooldown_text: String = ""
var _is_valid: bool = false


func _init(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> void:
	if not is_valid_definition(id, name, skill_kind, effect, targeting, requirements, cooldown):
		push_error("CharacterSkill requires non-blank identity, preview fields, and a valid kind.")
		return
	_skill_id = id
	_display_name = name
	_kind = skill_kind as Kind
	_effect_text = effect
	_targeting_text = targeting
	_requirements_text = requirements
	_cooldown_text = cooldown
	_is_valid = true


static func create(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> CharacterSkill:
	var skill: CharacterSkill = CharacterSkill.new(
		id, name, skill_kind, effect, targeting, requirements, cooldown
	)
	return skill if skill.is_valid() else null


static func is_valid_definition(
	id: StringName,
	name: String,
	skill_kind: int,
	effect: String,
	targeting: String,
	requirements: String,
	cooldown: String
) -> bool:
	return (
		not String(id).strip_edges().is_empty()
		and not name.strip_edges().is_empty()
		and skill_kind in [Kind.ACTIVE, Kind.PASSIVE]
		and not effect.strip_edges().is_empty()
		and not targeting.strip_edges().is_empty()
		and not requirements.strip_edges().is_empty()
		and not cooldown.strip_edges().is_empty()
	)


func is_valid() -> bool:
	return _is_valid


func duplicate_skill() -> CharacterSkill:
	if not _is_valid:
		return null
	return CharacterSkill.new(
		_skill_id,
		_display_name,
		_kind,
		_effect_text,
		_targeting_text,
		_requirements_text,
		_cooldown_text
	)
