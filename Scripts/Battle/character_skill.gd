class_name CharacterSkill
extends RefCounted

enum Kind {
	ACTIVE,
	PASSIVE,
}

var skill_id: StringName
var display_name: String
var kind: Kind


func _init(id: StringName, name: String, skill_kind: int) -> void:
	assert(
		is_valid_definition(id, name, skill_kind),
		"CharacterSkill requires non-blank identity and an Active or Passive kind."
	)
	skill_id = id
	display_name = name
	kind = skill_kind


static func is_valid_definition(id: StringName, name: String, skill_kind: int) -> bool:
	return (
		not String(id).strip_edges().is_empty()
		and not name.strip_edges().is_empty()
		and skill_kind in [Kind.ACTIVE, Kind.PASSIVE]
	)
