class_name RunCharacter
extends RefCounted

var character_id: StringName
var display_name: String
var base_speed: int
var max_hp: int

var _skills: Array[CharacterSkill] = []


func _init(
	id: StringName,
	name: String,
	speed: int,
	maximum_hp: int,
	character_skills: Array[CharacterSkill]
) -> void:
	character_id = id
	display_name = name
	base_speed = speed
	max_hp = maximum_hp
	_skills = character_skills.duplicate()


func get_skills() -> Array[CharacterSkill]:
	return _skills.duplicate()
