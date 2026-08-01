class_name BattleUnitState
extends RefCounted

enum Side {
	PLAYER,
	ENEMY,
}

enum ModifierExpiry {
	NEXT_ACTION,
	CURRENT_ROUND,
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
var skills: Array[CharacterSkill]:
	get:
		return _skills.duplicate()

var _skills: Array[CharacterSkill] = []
var _base_speed: int = 0
var _skill_cooldowns: Dictionary[StringName, int] = {}
var _speed_modifiers: Dictionary[StringName, Dictionary] = {}


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
	_base_speed = unit_speed
	speed = unit_speed
	max_hp = max_hp_value
	current_hp = max_hp_value
	set_skills(unit_skills)


static func is_valid_skill_roster(candidate: Array) -> bool:
	if candidate.size() > MAX_CHARACTER_SKILLS:
		return false
	var seen_ids: Dictionary = {}
	for entry: Variant in candidate:
		if not is_instance_valid(entry) or not entry is CharacterSkill:
			return false
		var skill := entry as CharacterSkill
		if not skill.is_valid() or seen_ids.has(skill.skill_id):
			return false
		seen_ids[skill.skill_id] = true
	return true


func set_skills(candidate: Array) -> bool:
	if not is_valid_skill_roster(candidate):
		_skills.clear()
		push_error("BattleUnitState requires zero to four unique, valid CharacterSkill entries.")
		return false
	var copied: Array[CharacterSkill] = []
	for entry: Variant in candidate:
		var copy := (entry as CharacterSkill).duplicate_skill()
		if not is_instance_valid(copy):
			_skills.clear()
			push_error("BattleUnitState could not copy an invalid CharacterSkill entry.")
			return false
		copied.append(copy)
	_skills = copied
	return true


func get_base_speed() -> int:
	return _base_speed


func get_effective_speed() -> int:
	var total := _base_speed
	for modifier: Dictionary in _speed_modifiers.values():
		total += int(modifier.get("amount", 0))
	return total


func get_skill_cooldown(skill_id: StringName) -> int:
	return _skill_cooldowns.get(skill_id, 0)


func set_skill_cooldown(skill_id: StringName, actions: int) -> bool:
	if skill_id.is_empty() or actions < 0 or not _has_skill(skill_id):
		return false
	if actions == 0:
		_skill_cooldowns.erase(skill_id)
	else:
		_skill_cooldowns[skill_id] = actions
	return true


func tick_skill_cooldowns(excluded_skill_ids: Array[StringName] = []) -> void:
	for skill_id: StringName in _skill_cooldowns.keys():
		if excluded_skill_ids.has(skill_id):
			continue
		var remaining := _skill_cooldowns[skill_id] - 1
		if remaining <= 0:
			_skill_cooldowns.erase(skill_id)
		else:
			_skill_cooldowns[skill_id] = remaining


func add_speed_modifier(
	source_id: StringName,
	amount: int,
	expiry: ModifierExpiry,
	duration: int,
	applied_round: int = 1
) -> bool:
	if (
		source_id.is_empty()
		or amount <= 0
		or duration <= 0
		or expiry not in [ModifierExpiry.NEXT_ACTION, ModifierExpiry.CURRENT_ROUND]
		or applied_round < 1
	):
		return false
	_speed_modifiers[source_id] = {
		"amount": amount,
		"expiry": expiry,
		"remaining_actions": duration if expiry == ModifierExpiry.NEXT_ACTION else 0,
		"expiry_round": applied_round if expiry == ModifierExpiry.CURRENT_ROUND else 0,
	}
	return true


func expire_speed_modifiers_after_action() -> void:
	for source_id: StringName in _speed_modifiers.keys():
		var modifier: Dictionary = _speed_modifiers[source_id]
		if modifier.get("expiry") != ModifierExpiry.NEXT_ACTION:
			continue
		var remaining := int(modifier.get("remaining_actions", 0)) - 1
		if remaining <= 0:
			_speed_modifiers.erase(source_id)
		else:
			modifier["remaining_actions"] = remaining
			_speed_modifiers[source_id] = modifier


func expire_speed_modifiers_for_round(completed_round: int) -> void:
	for source_id: StringName in _speed_modifiers.keys():
		var modifier: Dictionary = _speed_modifiers[source_id]
		if (
			modifier.get("expiry") == ModifierExpiry.CURRENT_ROUND
			and int(modifier.get("expiry_round", 0)) <= completed_round
		):
			_speed_modifiers.erase(source_id)


func get_speed_modifier_snapshot() -> Dictionary[StringName, Dictionary]:
	return _speed_modifiers.duplicate(true)


func get_skill_cooldown_snapshot() -> Dictionary[StringName, int]:
	return _skill_cooldowns.duplicate()


func _has_skill(skill_id: StringName) -> bool:
	for skill: CharacterSkill in _skills:
		if skill.skill_id == skill_id:
			return true
	return false


func is_active() -> bool:
	return current_hp > 0
