class_name RunCharacter
extends RefCounted

var character_id: StringName
var display_name: String
var base_speed: int
var max_hp: int
var power: int = 1
var defense: int = 0
var race_id: StringName = &"unknown"

var _skills: Array[CharacterSkill] = []


func _init(
	id: StringName,
	name: String,
	speed: int,
	maximum_hp: int,
	character_skills: Array[CharacterSkill],
	unit_power: int = 1,
	unit_defense: int = 0,
	unit_race_id: StringName = &"unknown"
) -> void:
	character_id = id
	display_name = name
	base_speed = speed
	max_hp = maximum_hp
	if unit_power < 1 or unit_defense < 0:
		push_error("RunCharacter requires Power >= 1 and Defense >= 0.")
	else:
		power = unit_power
		defense = unit_defense
	race_id = unit_race_id if not unit_race_id.is_empty() else &"unknown"
	_skills = character_skills.duplicate()


func get_skills() -> Array[CharacterSkill]:
	return _skills.duplicate()
