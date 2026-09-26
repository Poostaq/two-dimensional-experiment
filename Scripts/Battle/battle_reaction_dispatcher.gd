class_name BattleReactionDispatcher
extends RefCounted


static func collect_action_start_reactions(
	actor: BattleUnitState,
	units: Array[BattleUnitState],
	round_number: int
) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []
	if (
		not is_instance_valid(actor)
		or not actor.is_active()
		or round_number < 1
		or not units.has(actor)
	):
		return reactions
	for skill: CharacterSkill in actor.skills:
		if not is_instance_valid(skill) or skill.kind != CharacterSkill.Kind.PASSIVE:
			continue
		var definition: RefCounted = skill.reaction_definition
		if (
			not _is_valid_reaction_definition(definition)
			or int(definition.get("trigger")) != BattleReactionDefinition.Trigger.ACTION_START
		):
			continue
		if not actor.mark_passive_reaction_guard(
			definition.get("passive_skill_id"),
			definition.get("frequency"),
			round_number,
			round_number
		):
			continue
		var targets: Array[BattleUnitState] = _resolve_action_start_targets(
			actor,
			units,
			int(definition.get("target_policy"))
		)
		var target_ids: Array[StringName] = []
		for target: BattleUnitState in targets:
			target_ids.append(target.unit_id)
		if targets.is_empty():
			reactions.append({
				"definition": definition.call("with_owner", actor.unit_id),
				"owner_id": actor.unit_id,
				"target_id": &"",
				"target_ids": target_ids,
			})
			continue
		var operation: RefCounted = definition.get("operation")
		var resolved_operation: RefCounted = operation.call("with_target", targets[0].unit_id)
		var resolved_definition: RefCounted = definition.call(
			"with_owner_and_operation",
			actor.unit_id,
			resolved_operation
		)
		if not is_instance_valid(resolved_definition):
			continue
		reactions.append({
			"definition": resolved_definition,
			"owner_id": actor.unit_id,
			"target_id": targets[0].unit_id,
			"target_ids": target_ids,
		})
	return reactions


static func collect_action_end_reactions(
	actor: BattleUnitState,
	units: Array[BattleUnitState],
	round_number: int
) -> Array[Dictionary]:
	var reactions: Array[Dictionary] = []
	if (
		not is_instance_valid(actor)
		or not actor.is_active()
		or round_number < 1
		or not units.has(actor)
	):
		return reactions
	if not BattleFormationRules.is_in_contact(actor, units):
		return reactions
	for skill: CharacterSkill in actor.skills:
		if not is_instance_valid(skill) or skill.kind != CharacterSkill.Kind.PASSIVE:
			continue
		var definition: RefCounted = skill.reaction_definition
		if (
			not _is_valid_reaction_definition(definition)
			or int(definition.get("trigger")) != BattleReactionDefinition.Trigger.ACTION_END
		):
			continue
		if not actor.mark_passive_reaction_guard(
			definition.get("passive_skill_id"),
			definition.get("frequency"),
			round_number,
			round_number
		):
			continue
		var targets: Array[BattleUnitState] = _resolve_action_start_targets(
			actor,
			units,
			int(definition.get("target_policy"))
		)
		if targets.is_empty():
			continue
		var target_ids: Array[StringName] = []
		for target: BattleUnitState in targets:
			target_ids.append(target.unit_id)
		var operation: RefCounted = definition.get("operation")
		var resolved_operation: RefCounted = operation.call("with_target", targets[0].unit_id)
		var resolved_definition: RefCounted = definition.call(
			"with_owner_and_operation",
			actor.unit_id,
			resolved_operation
		)
		if not is_instance_valid(resolved_definition):
			continue
		reactions.append({
			"definition": resolved_definition,
			"owner_id": actor.unit_id,
			"target_id": targets[0].unit_id,
			"target_ids": target_ids,
		})
	return reactions


static func is_action_start_target_current(
	owner: BattleUnitState,
	target_id: StringName,
	units: Array[BattleUnitState],
	target_policy: int = BattleReactionDefinition.TargetPolicy.CLOSEST_OPPONENT
) -> bool:
	return are_action_start_targets_current(owner, [target_id], units, target_policy)


static func are_action_start_targets_current(
	owner: BattleUnitState,
	target_ids: Array[StringName],
	units: Array[BattleUnitState],
	target_policy: int = BattleReactionDefinition.TargetPolicy.CLOSEST_OPPONENT
) -> bool:
	if target_ids.is_empty():
		return false
	var current_ids: Array[StringName] = []
	for target: BattleUnitState in _resolve_action_start_targets(owner, units, target_policy):
		current_ids.append(target.unit_id)
	return current_ids == target_ids


static func _resolve_action_start_targets(
	owner: BattleUnitState,
	units: Array[BattleUnitState],
	target_policy: int
) -> Array[BattleUnitState]:
	var targets: Array[BattleUnitState] = []
	if target_policy == BattleReactionDefinition.TargetPolicy.CLOSEST_OPPONENT:
		var opponent: BattleUnitState = BattleFormationRules.closest_active_opponent(owner, units)
		if is_instance_valid(opponent):
			targets.append(opponent)
		return targets
	var allies: Array[BattleUnitState] = BattleFormationRules.active_adjacent_allies(owner, units)
	if target_policy == BattleReactionDefinition.TargetPolicy.ADJACENT_ALLY:
		if not allies.is_empty():
			targets.append(allies[0])
		return targets
	if allies.is_empty():
		return targets
	targets.append(owner)
	if target_policy == BattleReactionDefinition.TargetPolicy.OWNER_AND_ADJACENT_ALLY:
		targets.append(allies[0])
	elif target_policy == BattleReactionDefinition.TargetPolicy.OWNER_AND_ALL_ADJACENT_ALLIES:
		targets.append_array(allies)
	return targets


static func collect_reactions(
	trigger: BattleActionRecord,
	units: Array[BattleUnitState],
	round_number: int,
	chain_depth: int
) -> Array[RefCounted]:
	var candidates: Array[Dictionary] = []
	if not is_instance_valid(trigger) or not trigger.is_valid() or round_number < 1 or chain_depth > 1:
		return []
	for unit: BattleUnitState in units:
		if not is_instance_valid(unit) or not unit.is_active() or unit.unit_id == trigger.actor_id:
			continue
		for skill: CharacterSkill in unit.skills:
			if not is_instance_valid(skill) or skill.kind != CharacterSkill.Kind.PASSIVE:
				continue
			var definition: RefCounted = skill.reaction_definition
			if not _matches_trigger(definition, trigger, chain_depth):
				continue
			candidates.append({
				"unit": unit,
				"definition": definition,
			})
	candidates.sort_custom(_reaction_candidate_comes_before)
	var reactions: Array[RefCounted] = []
	for candidate: Dictionary in candidates:
		var owner: BattleUnitState = candidate["unit"]
		var definition: RefCounted = candidate["definition"]
		if not owner.mark_passive_reaction_guard(
			definition.get("passive_skill_id"),
			definition.get("frequency"),
			trigger.sequence_number,
			round_number
		):
			continue
		reactions.append(definition.call("with_owner", owner.unit_id))
	return reactions


static func _matches_trigger(definition: RefCounted, trigger: BattleActionRecord, chain_depth: int) -> bool:
	if not _is_valid_reaction_definition(definition):
		return false
	if chain_depth > 0 and not definition.get("allow_reaction_chain"):
		return false
	match int(definition.get("trigger")):
		0:
			return _record_has_direct_hit(trigger)
		1:
			return _record_has_forced_movement(trigger)
	return false


static func _record_has_direct_hit(trigger: BattleActionRecord) -> bool:
	for target_id: StringName in trigger.direct_hit_by_target.keys():
		if trigger.direct_hit_by_target.get(target_id, false):
			return true
	return false


static func _record_has_forced_movement(trigger: BattleActionRecord) -> bool:
	if trigger.voluntary_movement:
		return false
	for unit_id: StringName in trigger.slot_before_by_unit.keys():
		if (
			trigger.slot_after_by_unit.has(unit_id)
			and trigger.slot_before_by_unit[unit_id] != trigger.slot_after_by_unit[unit_id]
		):
			return true
	return false


static func _reaction_candidate_comes_before(first: Dictionary, second: Dictionary) -> bool:
	var first_definition: RefCounted = first["definition"]
	var second_definition: RefCounted = second["definition"]
	var first_unit: BattleUnitState = first["unit"]
	var second_unit: BattleUnitState = second["unit"]
	if int(first_definition.get("priority")) != int(second_definition.get("priority")):
		return int(first_definition.get("priority")) < int(second_definition.get("priority"))
	if first_unit.side != second_unit.side:
		return first_unit.side < second_unit.side
	if first_unit.slot_index != second_unit.slot_index:
		return first_unit.slot_index < second_unit.slot_index
	return String(first_unit.unit_id) < String(second_unit.unit_id)


static func _is_valid_reaction_definition(definition: RefCounted) -> bool:
	return (
		is_instance_valid(definition)
		and definition.has_method("is_valid")
		and definition.has_method("duplicate_definition")
		and definition.has_method("with_owner")
		and definition.call("is_valid")
	)
