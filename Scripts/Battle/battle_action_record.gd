class_name BattleActionRecord
extends RefCounted

enum Kind {
	DEFAULT_ATTACK,
	DEFAULT_SWAP,
	FORMATION_MOVE,
	SKILL,
}

var kind: Kind
var actor_id: StringName
var target_ids: Array[StringName]
var damage_by_target: Dictionary[StringName, int]
var slot_before_by_unit: Dictionary[StringName, int]
var slot_after_by_unit: Dictionary[StringName, int]
var round_number: int
var revision: int


func _init(
	action_kind: Kind,
	action_actor_id: StringName,
	action_target_ids: Array[StringName],
	action_damage_by_target: Dictionary[StringName, int],
	action_slot_before_by_unit: Dictionary[StringName, int],
	action_slot_after_by_unit: Dictionary[StringName, int],
	action_round_number: int,
	action_revision: int
) -> void:
	kind = action_kind
	actor_id = action_actor_id
	target_ids = action_target_ids.duplicate()
	damage_by_target = action_damage_by_target.duplicate()
	slot_before_by_unit = action_slot_before_by_unit.duplicate()
	slot_after_by_unit = action_slot_after_by_unit.duplicate()
	round_number = action_round_number
	revision = action_revision


func is_valid() -> bool:
	return (
		kind in [Kind.DEFAULT_ATTACK, Kind.DEFAULT_SWAP, Kind.FORMATION_MOVE, Kind.SKILL]
		and not actor_id.is_empty()
		and round_number >= 1
		and revision >= 0
	)


func duplicate_record() -> RefCounted:
	var record_script: Script = load("res://Scripts/Battle/battle_action_record.gd")
	return record_script.new(
		kind,
		actor_id,
		target_ids,
		damage_by_target,
		slot_before_by_unit,
		slot_after_by_unit,
		round_number,
		revision
	)
