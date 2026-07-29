class_name BattleUnitState
extends RefCounted

enum Side {
	PLAYER,
	ENEMY,
}

const DEFAULT_MAX_HP := 20
const MAX_CHARACTER_SKILLS := 4

var unit_id: StringName
var display_name: String
var side: Side
var slot_index: int
var speed: int
var max_hp: int
var current_hp: int
var skills: Array[CharacterSkill] = []


func _init(
	id: StringName,
	name: String,
	unit_side: int,
	unit_slot_index: int,
	unit_speed: int,
	max_hp_value: int = DEFAULT_MAX_HP,
	unit_skills: Array[CharacterSkill] = []
) -> void:
	unit_id = id
	display_name = name
	side = unit_side
	slot_index = unit_slot_index
	speed = unit_speed
	max_hp = max_hp_value
	current_hp = max_hp_value
	assert(
		is_valid_skill_roster(unit_skills),
		"BattleUnitState requires zero to four unique, valid CharacterSkill entries."
	)
	skills = unit_skills.duplicate()


static func is_valid_skill_roster(candidate: Array) -> bool:
	if candidate.size() > MAX_CHARACTER_SKILLS:
		return false
	var seen_ids: Dictionary = {}
	for entry: Variant in candidate:
		if not is_instance_valid(entry) or not entry is CharacterSkill:
			return false
		var skill := entry as CharacterSkill
		if seen_ids.has(skill.skill_id):
			return false
		seen_ids[skill.skill_id] = true
	return true


func is_active() -> bool:
	return current_hp > 0
