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
var sequence_number: int
var actor_side: BattleUnitState.Side
var source_skill_id: StringName
var voluntary_movement: bool
var direct_hit_by_target: Dictionary[StringName, bool]
var keyword_deltas: Array[Dictionary]
var advantage_consumed: RefCounted
var bleed_ticks: Array[RefCounted]
var is_reaction: bool


func _init(
	action_kind: Kind,
	action_actor_id: StringName,
	action_target_ids: Array[StringName],
	action_damage_by_target: Dictionary[StringName, int],
	action_slot_before_by_unit: Dictionary[StringName, int],
	action_slot_after_by_unit: Dictionary[StringName, int],
	action_round_number: int,
	action_revision: int,
	action_sequence_number: int = 0,
	action_actor_side: int = -1,
	action_source_skill_id: StringName = &"",
	action_voluntary_movement: bool = true,
	action_direct_hit_by_target: Dictionary[StringName, bool] = {},
	action_keyword_deltas: Array[Dictionary] = [],
	action_advantage_consumed: RefCounted = null,
	action_bleed_ticks: Array[RefCounted] = [],
	action_is_reaction: bool = false
) -> void:
	kind = action_kind
	actor_id = action_actor_id
	target_ids = action_target_ids.duplicate()
	damage_by_target = action_damage_by_target.duplicate()
	slot_before_by_unit = action_slot_before_by_unit.duplicate()
	slot_after_by_unit = action_slot_after_by_unit.duplicate()
	round_number = action_round_number
	revision = action_revision
	sequence_number = action_sequence_number if action_sequence_number > 0 else action_revision
	actor_side = action_actor_side as BattleUnitState.Side
	source_skill_id = action_source_skill_id
	voluntary_movement = action_voluntary_movement
	direct_hit_by_target = action_direct_hit_by_target.duplicate()
	keyword_deltas = action_keyword_deltas.duplicate(true)
	advantage_consumed = (
		action_advantage_consumed.call("duplicate_source")
		if is_instance_valid(action_advantage_consumed)
		else null
	)
	bleed_ticks = _duplicate_bleed_ticks(action_bleed_ticks)
	is_reaction = action_is_reaction


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
		revision,
		sequence_number,
		actor_side,
		source_skill_id,
		voluntary_movement,
		direct_hit_by_target,
		keyword_deltas,
		advantage_consumed,
		bleed_ticks,
		is_reaction
	)


static func _duplicate_bleed_ticks(source_ticks: Array[RefCounted]) -> Array[RefCounted]:
	var copied: Array[RefCounted] = []
	for tick: RefCounted in source_ticks:
		if is_instance_valid(tick) and tick.has_method("duplicate_state"):
			copied.append(tick.call("duplicate_state"))
	return copied
