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
const MAX_ARMOR := 10
const BLEED_STATE_PATH := "res://Scripts/Battle/battle_bleed_state.gd"

var unit_id: StringName
var display_name: String
var side: Side
var slot_index: int
var speed: int
var power: int = 1
var defense: int = 0
var max_hp: int
var current_hp: int
var skills: Array[CharacterSkill]:
	get:
		return _skills.duplicate()

var _skills: Array[CharacterSkill] = []
var _base_speed: int = 0
var _skill_cooldowns: Dictionary[StringName, int] = {}
var _speed_modifiers: Dictionary[StringName, Dictionary] = {}
var _armor: int = 0
var _advantage_source: RefCounted = null
var _advantage_expiry_round: int = 0
var _snared_source: RefCounted = null
var _snared_expiry_round: int = 0
var _snared_follow_up_armed: bool = false
var _bleed_states: Dictionary[StringName, RefCounted] = {}
var _passive_action_guards: Dictionary[StringName, bool] = {}
var _passive_round_guards: Dictionary[StringName, bool] = {}
var _passive_battle_guards: Dictionary[StringName, bool] = {}


func _init(
	id: StringName,
	name: String,
	unit_side: int,
	unit_slot_index: int,
	unit_speed: int,
	max_hp_value: int = DEFAULT_MAX_HP,
	unit_skills: Array[CharacterSkill] = [],
	unit_power: int = 1,
	unit_defense: int = 0
) -> void:
	unit_id = id
	display_name = name
	side = unit_side
	slot_index = unit_slot_index
	_base_speed = unit_speed
	speed = unit_speed
	if unit_power < 1 or unit_defense < 0:
		push_error("BattleUnitState requires Power >= 1 and Defense >= 0.")
	else:
		power = unit_power
		defense = unit_defense
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
	return max(1, total)


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
		or amount == 0
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


func expire_speed_modifiers_after_action(excluded_source_ids: Array[StringName] = []) -> void:
	for source_id: StringName in _speed_modifiers.keys():
		if excluded_source_ids.has(source_id):
			continue
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


func add_armor(amount: int) -> int:
	if amount <= 0 or _armor >= MAX_ARMOR:
		return 0
	var applied: int = min(amount, MAX_ARMOR - _armor)
	_armor += applied
	return applied


func spend_armor(requested: int) -> int:
	if requested <= 0 or _armor <= 0:
		return 0
	var spent: int = min(requested, _armor)
	_armor -= spent
	return spent


func get_armor() -> int:
	return _armor


func apply_advantage(source: RefCounted, expiry_round: int) -> bool:
	if not _is_valid_keyword_source(source) or expiry_round < 1:
		return false
	_advantage_source = source.call("duplicate_source")
	_advantage_expiry_round = expiry_round
	return true


func has_advantage(current_round: int) -> bool:
	if current_round < 1 or not is_instance_valid(_advantage_source):
		return false
	if _advantage_expiry_round < current_round:
		_clear_advantage()
		return false
	return true


func get_advantage_source(current_round: int) -> RefCounted:
	if not has_advantage(current_round):
		return null
	return _advantage_source.call("duplicate_source")


func consume_advantage(current_round: int) -> RefCounted:
	if not has_advantage(current_round):
		return null
	var consumed: RefCounted = _advantage_source.call("duplicate_source")
	_clear_advantage()
	return consumed


func apply_snared(source: RefCounted, expiry_round: int, arm_follow_up: bool = false) -> bool:
	if not _is_valid_keyword_source(source) or expiry_round < 1:
		return false
	_snared_source = source.call("duplicate_source")
	_snared_expiry_round = max(_snared_expiry_round, expiry_round)
	_snared_follow_up_armed = arm_follow_up
	return true


func is_snared(current_round: int) -> bool:
	if current_round < 1 or not is_instance_valid(_snared_source):
		return false
	if _snared_expiry_round < current_round:
		_clear_snared()
		return false
	return true


func has_snared_follow_up(current_round: int) -> bool:
	return _snared_follow_up_armed and is_snared(current_round)


func get_snared_follow_up_source(current_round: int) -> RefCounted:
	if not has_snared_follow_up(current_round):
		return null
	return _snared_source.call("duplicate_source")


func consume_snared_follow_up(current_round: int) -> RefCounted:
	if not has_snared_follow_up(current_round):
		return null
	_snared_follow_up_armed = false
	return _snared_source.call("duplicate_source")


func apply_bleed(source: RefCounted, duration_actions: int = 2) -> bool:
	if not _is_valid_keyword_source(source) or duration_actions < 1:
		return false
	var key := _keyword_source_key(source)
	if _bleed_states.has(key):
		return _bleed_states[key].call("add_application", source, duration_actions)
	var bleed_script := load(BLEED_STATE_PATH) as Script
	if not is_instance_valid(bleed_script):
		return false
	var bleed: RefCounted = bleed_script.call("create", source, 1, duration_actions)
	if not is_instance_valid(bleed):
		return false
	_bleed_states[key] = bleed
	return true


func resolve_bleed_after_committed_action() -> Array[RefCounted]:
	var ticks: Array[RefCounted] = []
	for key: StringName in _bleed_states.keys():
		var bleed: RefCounted = _bleed_states[key]
		if not is_instance_valid(bleed):
			_bleed_states.erase(key)
			continue
		ticks.append(bleed.call("duplicate_state"))
		if not bleed.call("consume_action"):
			_bleed_states.erase(key)
	return ticks


func get_bleed_snapshot() -> Array[RefCounted]:
	var snapshot: Array[RefCounted] = []
	for bleed: RefCounted in _bleed_states.values():
		if is_instance_valid(bleed):
			snapshot.append(bleed.call("duplicate_state"))
	return snapshot


func reduce_skill_cooldown(skill_id: StringName, amount: int) -> int:
	if skill_id.is_empty() or amount <= 0 or not _has_skill(skill_id):
		return get_skill_cooldown(skill_id)
	var remaining: int = max(0, get_skill_cooldown(skill_id) - amount)
	set_skill_cooldown(skill_id, remaining)
	return remaining


func clear_round_keywords(completed_round: int) -> void:
	if completed_round < 1:
		return
	if is_instance_valid(_advantage_source) and _advantage_expiry_round <= completed_round:
		_clear_advantage()
	if is_instance_valid(_snared_source) and _snared_expiry_round <= completed_round:
		_clear_snared()
	expire_speed_modifiers_for_round(completed_round)
	_passive_action_guards.clear()
	_passive_round_guards.clear()


func mark_passive_reaction_guard(
	passive_skill_id: StringName,
	frequency: int,
	action_sequence: int,
	round_number: int
) -> bool:
	if passive_skill_id.is_empty() or action_sequence < 1 or round_number < 1:
		return false
	var guard_key: StringName = _passive_guard_key(passive_skill_id, action_sequence, round_number)
	match frequency:
		0:
			if _passive_action_guards.has(guard_key):
				return false
			_passive_action_guards[guard_key] = true
			return true
		1:
			if _passive_round_guards.has(guard_key):
				return false
			_passive_round_guards[guard_key] = true
			return true
		2:
			if _passive_battle_guards.has(passive_skill_id):
				return false
			_passive_battle_guards[passive_skill_id] = true
			return true
	return false


func clear_battle_local_state() -> void:
	_skill_cooldowns.clear()
	_speed_modifiers.clear()
	_armor = 0
	_clear_advantage()
	_clear_snared()
	_bleed_states.clear()
	_passive_action_guards.clear()
	_passive_round_guards.clear()
	_passive_battle_guards.clear()


func get_skill_cooldown_snapshot() -> Dictionary[StringName, int]:
	return _skill_cooldowns.duplicate()


func _passive_guard_key(passive_skill_id: StringName, action_sequence: int, round_number: int) -> StringName:
	return StringName("%s::%d::%d" % [passive_skill_id, action_sequence, round_number])


func _clear_advantage() -> void:
	_advantage_source = null
	_advantage_expiry_round = 0


func _clear_snared() -> void:
	_snared_source = null
	_snared_expiry_round = 0
	_snared_follow_up_armed = false


func _is_valid_keyword_source(source: RefCounted) -> bool:
	return (
		is_instance_valid(source)
		and source.has_method("is_valid")
		and source.has_method("duplicate_source")
		and source.call("is_valid")
		and source.get("source_unit_id") is StringName
		and source.get("source_skill_id") is StringName
		and source.get("source_power") is int
	)


func _keyword_source_key(source: RefCounted) -> StringName:
	return StringName("%s::%s" % [source.get("source_unit_id"), source.get("source_skill_id")])


func _has_skill(skill_id: StringName) -> bool:
	for skill: CharacterSkill in _skills:
		if skill.skill_id == skill_id:
			return true
	return false


func is_active() -> bool:
	return current_hp > 0
