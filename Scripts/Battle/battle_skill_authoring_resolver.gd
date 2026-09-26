class_name BattleSkillAuthoringResolver
extends RefCounted


static func build_plan(
	actor: BattleUnitState,
	skill: CharacterSkill,
	locked_targets: Array[BattleUnitState],
	units: Array[BattleUnitState],
	round_number: int,
	revision: int,
	history: Array[BattleActionLogEntry],
	declared_move_path: Array[int] = [],
	action_records: Array[BattleActionRecord] = []
) -> SkillEffectPlan:
	if (
		not is_instance_valid(actor)
		or not actor.is_active()
		or not is_instance_valid(skill)
		or not skill.is_valid()
		or revision < 0
	):
		return null
	var target_ids: Array[StringName] = []
	for target: BattleUnitState in locked_targets:
		if (
			not is_instance_valid(target)
			or not target.is_active()
			or target_ids.has(target.unit_id)
		):
			return null
		target_ids.append(target.unit_id)
	var profile: RefCounted = skill.target_profile
	if target_ids.is_empty() and (
		not is_instance_valid(profile)
		or int(profile.get("maximum_targets")) != 0
	):
		return null
	if target_ids.is_empty():
		target_ids.append(actor.unit_id)
	if not _conditions_met(actor, skill, locked_targets, units, round_number, history, action_records):
		return null

	var damage_operations: Array[Dictionary] = []
	var speed_operations: Array[Dictionary] = []
	var keyword_operations: Array[RefCounted] = []
	var locked_advantage_source: RefCounted = null
	var consume_advantage: bool = false
	var movement_unit_id: StringName = &""
	var movement_effect_seen: bool = false
	var effect_script: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	for authored_effect: RefCounted in skill.authored_effects:
		var targets: Array[BattleUnitState] = _targets_for_role(
			int(authored_effect.get("target_role")),
			actor,
			locked_targets,
			units,
			history,
			round_number,
			effect_script
		)
		if targets.is_empty():
			if int(authored_effect.get("target_role")) in [effect_script.TargetRole.HISTORY_ALLY, effect_script.TargetRole.SECONDARY]:
				continue
			return null
		match int(authored_effect.get("kind")):
			effect_script.Kind.DAMAGE:
				for target: BattleUnitState in targets:
					var percent: int = int(authored_effect.get("power_percent"))
					var advantage_percent: int = int(authored_effect.get("advantage_power_percent"))
					var resolved_armor_strip: int = int(authored_effect.get("armor_strip"))
					var advantage_armor_strip: int = int(authored_effect.get("advantage_armor_strip"))
					if target.has_advantage(round_number) and (advantage_percent > 0 or advantage_armor_strip > 0):
						if advantage_percent > 0:
							percent = advantage_percent
						if advantage_armor_strip > 0:
							resolved_armor_strip = advantage_armor_strip
						locked_advantage_source = target.get_advantage_source(round_number)
						consume_advantage = is_instance_valid(locked_advantage_source)
					if _damage_bonus_met(int(authored_effect.get("bonus_condition")), target, round_number, action_records):
						percent = int(authored_effect.get("upgraded_power_percent"))
						if bool(authored_effect.get("consume_bonus_advantage")):
							locked_advantage_source = target.get_advantage_source(round_number)
							consume_advantage = is_instance_valid(locked_advantage_source)
					var requested: int = BattleDamageRules.physical_damage(
						actor.get_effective_power(),
						float(percent) / 100.0,
						target.get_effective_defense()
					)
					damage_operations.append({
						&"target_id": target.unit_id,
						&"base_damage": requested,
						&"combo_bonus_damage": 0,
						&"total_requested_damage": requested,
						&"armor_strip": resolved_armor_strip,
						&"ignore_armor": bool(authored_effect.get("ignore_armor")),
					})
			effect_script.Kind.HISTORY_SCALED_DAMAGE:
				for target: BattleUnitState in targets:
					var count: int = BattleHistoryQuery.distinct_allied_attackers_this_round(
						action_records, actor.side as BattleUnitState.Side, target.unit_id, actor.unit_id, round_number
					).size()
					if _has_condition(skill, BattleSkillCondition.Kind.ALLY_ACTED_BEFORE_ACTOR_THIS_ROUND):
						count = 1 if BattleHistoryQuery.ally_acted_before_this_round(
							action_records, actor.side as BattleUnitState.Side, actor.unit_id, round_number
						) else 0
					var percent: int = min(
						int(authored_effect.get("maximum_power_percent")),
						int(authored_effect.get("power_percent")) + count * int(authored_effect.get("history_increment"))
					)
					var requested: int = BattleDamageRules.physical_damage(actor.get_effective_power(), float(percent) / 100.0, target.get_effective_defense())
					damage_operations.append({
						&"target_id": target.unit_id,
						&"base_damage": requested,
						&"combo_bonus_damage": 0,
						&"total_requested_damage": requested,
					})
			effect_script.Kind.POISON_SCALED_DAMAGE:
				for target: BattleUnitState in targets:
					var stack_count: int = 0
					var axis: StringName = authored_effect.get("poison_axis") as StringName
					var source_skill_id: StringName = authored_effect.get("source_skill_id") as StringName
					var poison_axes: Array[StringName] = []
					if axis.is_empty():
						poison_axes.assign([&"power", &"defense", &"speed"])
					else:
						poison_axes.append(axis)
					for poison_axis: StringName in poison_axes:
						if bool(authored_effect.get("source_only")):
							stack_count += target.get_poison_source_stacks(
								poison_axis, actor.unit_id, source_skill_id, round_number
							)
						else:
							stack_count += target.get_poison_stacks(poison_axis, round_number)
					var poison_percent: int = min(
						int(authored_effect.get("maximum_power_percent")),
						int(authored_effect.get("power_percent"))
							+ stack_count * int(authored_effect.get("history_increment"))
					)
					var poison_advantage_bonus: int = int(authored_effect.get("advantage_power_percent"))
					if poison_advantage_bonus > 0 and target.has_advantage(round_number):
						poison_percent += poison_advantage_bonus
						locked_advantage_source = target.get_advantage_source(round_number)
						consume_advantage = is_instance_valid(locked_advantage_source)
					var poison_damage: int = BattleDamageRules.physical_damage(
						actor.get_effective_power(),
						float(poison_percent) / 100.0,
						target.get_effective_defense()
					)
					damage_operations.append({
						&"target_id": target.unit_id,
						&"base_damage": poison_damage,
						&"combo_bonus_damage": 0,
						&"total_requested_damage": poison_damage,
					})
			effect_script.Kind.ARMOR_SPEND_DAMAGE:
				var armor_spend: int = min(actor.get_armor(), int(authored_effect.get("magnitude")))
				if armor_spend <= 0:
					return null
				for target: BattleUnitState in targets:
					var armor_spend_percent: int = armor_spend * int(authored_effect.get("power_percent"))
					var armor_spend_damage: int = BattleDamageRules.physical_damage(
						actor.get_effective_power(),
						float(armor_spend_percent) / 100.0,
						target.get_effective_defense()
					)
					damage_operations.append({
						&"target_id": target.unit_id,
						&"base_damage": armor_spend_damage,
						&"combo_bonus_damage": 0,
						&"total_requested_damage": armor_spend_damage,
						&"actor_armor_spend": armor_spend,
					})
			effect_script.Kind.POISON_TRANSFER:
				if locked_targets.size() != 2:
					return null
				var transfer_ally: BattleUnitState = locked_targets[0]
				var transfer_enemy: BattleUnitState = locked_targets[1]
				var transfer_snapshot: Dictionary = {}
				for transfer_axis: StringName in [&"power", &"defense", &"speed"]:
					var source_snapshots: Array[Dictionary] = transfer_ally.get_poison_source_snapshots(
						transfer_axis, round_number
					)
					if not source_snapshots.is_empty():
						transfer_snapshot = source_snapshots[0]
						break
				if transfer_snapshot.is_empty():
					return null
				var transfer_source: RefCounted = transfer_snapshot.get("source") as RefCounted
				var remaining_rounds: int = int(transfer_snapshot.get("expiry_round", 0)) - round_number + 1
				var transfer_operation: RefCounted = BattleKeywordOperation.create(
					BattleKeywordOperation.Kind.TRANSFER_POISON,
					transfer_ally.unit_id,
					1,
					remaining_rounds,
					transfer_source,
					transfer_enemy.unit_id,
					false,
					transfer_snapshot.get("axis") as StringName
				)
				if not is_instance_valid(transfer_operation):
					return null
				keyword_operations.append(transfer_operation)
			effect_script.Kind.CONDITIONAL_ARMOR:
				for target: BattleUnitState in targets:
					var amount: int = int(authored_effect.get("magnitude"))
					var armor_bonus_condition: int = int(authored_effect.get("bonus_condition"))
					var armor_bonus_met: bool = (
						BattleHistoryQuery.consumed_advantage_this_round(action_records, target.unit_id, round_number)
						if armor_bonus_condition == effect_script.BonusCondition.NONE
						else armor_bonus_condition == effect_script.BonusCondition.PRIMARY_ADVANTAGE and not locked_targets.is_empty() and locked_targets[0].has_advantage(round_number)
					)
					if armor_bonus_met:
						amount = int(authored_effect.get("conditional_magnitude"))
					var armor_operation: RefCounted = BattleKeywordOperation.create(
						BattleKeywordOperation.Kind.ADD_ARMOR, target.unit_id, amount
					)
					if not is_instance_valid(armor_operation):
						return null
					keyword_operations.append(armor_operation)
			effect_script.Kind.KEYWORD:
				for target: BattleUnitState in targets:
					var source: RefCounted = null
					var operation_kind: int = int(authored_effect.get("keyword_kind"))
					if operation_kind in [
						BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
						BattleKeywordOperation.Kind.APPLY_SNARED,
						BattleKeywordOperation.Kind.APPLY_BLEED,
						BattleKeywordOperation.Kind.APPLY_POISON,
						BattleKeywordOperation.Kind.APPLY_STUN,
					]:
						var authored_source_skill_id: StringName = authored_effect.get("source_skill_id") as StringName
						if authored_source_skill_id.is_empty():
							authored_source_skill_id = skill.skill_id
						source = BattleKeywordSource.create(actor.unit_id, authored_source_skill_id, actor.power)
					var operation: RefCounted = BattleKeywordOperation.create(
						operation_kind,
						target.unit_id,
						int(authored_effect.get("magnitude")),
						int(authored_effect.get("duration")),
						source,
						&"",
						bool(authored_effect.get("arms_snared_follow_up")),
						authored_effect.get("poison_axis") as StringName
					)
					if not is_instance_valid(operation):
						return null
					keyword_operations.append(operation)
			effect_script.Kind.SPEED:
				for target: BattleUnitState in targets:
					speed_operations.append({
						"target_id": target.unit_id,
						"source_id": skill.skill_id,
						"amount": int(authored_effect.get("magnitude")),
						"expiry": BattleUnitState.ModifierExpiry.CURRENT_ROUND,
						"duration": int(authored_effect.get("duration")),
						"applied_round": round_number,
					})
			effect_script.Kind.OPTIONAL_SELF_MOVE:
				if movement_effect_seen:
					return null
				movement_effect_seen = true
				var maximum_distance: int = int(authored_effect.get("magnitude"))
				var minimum_distance: int = int(authored_effect.get("conditional_magnitude"))
				if declared_move_path.is_empty():
					if minimum_distance > 0:
						return null
				else:
					var move_distance: int = declared_move_path.size() - 1
					if (
						declared_move_path[0] != actor.slot_index
						or move_distance < minimum_distance
						or move_distance > maximum_distance
						or not BattleFormationRules.is_valid_ring_path(declared_move_path, maximum_distance)
					):
						return null
					movement_unit_id = actor.unit_id
			effect_script.Kind.FORCED_TARGET_MOVE:
				if movement_effect_seen or targets.size() != 1 or declared_move_path.is_empty():
					return null
				movement_effect_seen = true
				var distance: int = int(authored_effect.get("magnitude"))
				if (
					declared_move_path.size() != distance + 1
					or declared_move_path[0] != targets[0].slot_index
					or not BattleFormationRules.is_valid_ring_path(declared_move_path, distance)
				):
					return null
				movement_unit_id = targets[0].unit_id
			_:
				return null
	if not declared_move_path.is_empty() and movement_unit_id.is_empty():
		return null

	return SkillEffectPlan.create(
		actor.unit_id,
		skill.skill_id,
		target_ids,
		damage_operations,
		speed_operations,
		skill.cooldown_actions,
		true,
		revision,
		keyword_operations,
		locked_advantage_source,
		null,
		consume_advantage,
		movement_unit_id,
		declared_move_path
	)


static func _conditions_met(
	actor: BattleUnitState,
	skill: CharacterSkill,
	locked_targets: Array[BattleUnitState],
	units: Array[BattleUnitState],
	round_number: int,
	history: Array[BattleActionLogEntry],
	action_records: Array[BattleActionRecord]
) -> bool:
	var condition_script: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	for condition: RefCounted in skill.conditions:
		match int(condition.get("kind")):
			condition_script.Kind.PRIMARY_ADVANTAGE:
				if locked_targets.is_empty() or not locked_targets[0].has_advantage(round_number):
					return false
			condition_script.Kind.PRIMARY_SNARED_OR_ADVANTAGE:
				if locked_targets.is_empty() or not (locked_targets[0].is_snared(round_number) or locked_targets[0].has_advantage(round_number)):
					return false
			condition_script.Kind.PRIMARY_LOST_ARMOR_THIS_ROUND:
				if locked_targets.is_empty() or BattleHistoryQuery.armor_lost_this_round(action_records, locked_targets[0].unit_id, round_number) <= 0:
					return false
			condition_script.Kind.PRIMARY_MOVED_THIS_ROUND:
				if locked_targets.is_empty() or not BattleHistoryQuery.moved_this_round(action_records, locked_targets[0].unit_id, round_number):
					return false
			condition_script.Kind.PRIMARY_MOVED_OR_STUNNED_THIS_ROUND:
				if locked_targets.is_empty() or not (BattleHistoryQuery.moved_this_round(action_records, locked_targets[0].unit_id, round_number) or locked_targets[0].is_stunned()):
					return false
			condition_script.Kind.ALLIES_BELOW_HALF_AT_LEAST_TWO:
				var wounded_allies: int = 0
				for unit: BattleUnitState in units:
					if is_instance_valid(unit) and unit.is_active() and unit.side == actor.side and unit.current_hp * 2 < unit.max_hp:
						wounded_allies += 1
				if wounded_allies < 2:
					return false
			condition_script.Kind.PRIMARY_POWER_POISON_FROM_ACTOR:
				if locked_targets.is_empty() or not _has_poison_from_actor(
					locked_targets[0], actor.unit_id, &"power", round_number
				):
					return false
			condition_script.Kind.PRIMARY_SPEED_POISON_FROM_ACTOR:
				if locked_targets.is_empty() or not _has_poison_from_actor(
					locked_targets[0], actor.unit_id, &"speed", round_number
				):
					return false
			condition_script.Kind.PRIMARY_HAS_ANY_POISON:
				if locked_targets.is_empty() or (
					locked_targets[0].get_poison_stacks(&"power", round_number)
					+ locked_targets[0].get_poison_stacks(&"defense", round_number)
					+ locked_targets[0].get_poison_stacks(&"speed", round_number)
				) <= 0:
					return false
			condition_script.Kind.ACTOR_NOT_MOVED_THIS_ROUND:
				if BattleHistoryQuery.moved_this_round(action_records, actor.unit_id, round_number):
					return false
			condition_script.Kind.ACTOR_ARMOR_AT_MOST_TWO:
				if actor.get_armor() > 2:
					return false
			condition_script.Kind.ACTOR_HAS_ARMOR:
				if actor.get_armor() <= 0:
					return false
			condition_script.Kind.PRIMARY_SNARED:
				if locked_targets.is_empty() or not locked_targets[0].is_snared(round_number):
					return false
			condition_script.Kind.PRIMARY_BLEEDING:
				if locked_targets.is_empty() or locked_targets[0].get_bleed_snapshot().is_empty():
					return false
			condition_script.Kind.PRIMARY_BELOW_HALF_HP:
				if locked_targets.is_empty() or locked_targets[0].current_hp * 2 >= locked_targets[0].max_hp:
					return false
			condition_script.Kind.PRIMARY_HIT_BY_ALLY_THIS_ROUND:
				if locked_targets.is_empty() or not BattleHistoryQuery.was_directly_hit_by_ally_this_round(
					action_records, actor.side as BattleUnitState.Side, locked_targets[0].unit_id, actor.unit_id, round_number
				):
					return false
			condition_script.Kind.PRIMARY_CONSUMED_ADVANTAGE_THIS_ROUND:
				if locked_targets.is_empty() or not BattleHistoryQuery.consumed_advantage_this_round(
					action_records, locked_targets[0].unit_id, round_number
				):
					return false
			condition_script.Kind.ALLY_ACTED_BEFORE_ACTOR_THIS_ROUND:
				if not BattleHistoryQuery.ally_acted_before_this_round(
					action_records, actor.side as BattleUnitState.Side, actor.unit_id, round_number
				):
					return false
			condition_script.Kind.PRIMARY_DIFFERENT_RACE_FROM_ACTOR:
				if locked_targets.is_empty() or locked_targets[0].race_id == actor.race_id:
					return false
			condition_script.Kind.PRIMARY_ATTACKED_ALLY_THIS_ROUND:
				if _latest_ally_attacked_by_primary(
					actor,
					locked_targets,
					units,
					history,
					round_number
				).is_empty():
					return false
			_:
				return false
	return true


static func _targets_for_role(
	role: int,
	actor: BattleUnitState,
	locked_targets: Array[BattleUnitState],
	units: Array[BattleUnitState],
	history: Array[BattleActionLogEntry],
	round_number: int,
	effect_script: Script
) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	match role:
		effect_script.TargetRole.ACTOR:
			result.append(actor)
		effect_script.TargetRole.PRIMARY:
			if not locked_targets.is_empty():
				result.append(locked_targets[0])
		effect_script.TargetRole.ALL_SELECTED:
			result = locked_targets.duplicate()
		effect_script.TargetRole.SECONDARY:
			if locked_targets.size() > 1:
				result.append(locked_targets[1])
		effect_script.TargetRole.HISTORY_ALLY:
			var ally_id: StringName = _latest_ally_attacked_by_primary(
				actor,
				locked_targets,
				units,
				history,
				round_number
			)
			for unit: BattleUnitState in units:
				if is_instance_valid(unit) and unit.unit_id == ally_id and unit.is_active():
					result.append(unit)
					break
	return result


static func _has_condition(skill: CharacterSkill, kind: int) -> bool:
	for condition: RefCounted in skill.conditions:
		if int(condition.get("kind")) == kind:
			return true
	return false


static func _latest_ally_attacked_by_primary(
	actor: BattleUnitState,
	locked_targets: Array[BattleUnitState],
	units: Array[BattleUnitState],
	history: Array[BattleActionLogEntry],
	round_number: int
) -> StringName:
	if locked_targets.is_empty():
		return &""
	var attacker_id: StringName = locked_targets[0].unit_id
	for index: int in range(history.size() - 1, -1, -1):
		var record: BattleActionLogEntry = history[index]
		if (
			not is_instance_valid(record)
			or record.round_number != round_number
			or record.actor_id != attacker_id
		):
			continue
		for target_id: StringName in record.target_ids:
			var was_direct_hit: bool = false
			for damage_result: BattleDamageResult in record.damage_results:
				if damage_result.receiver_id == target_id and damage_result.was_direct_hit:
					was_direct_hit = true
					break
			if not was_direct_hit:
				continue
			for unit: BattleUnitState in units:
				if (
					is_instance_valid(unit)
					and unit.unit_id == target_id
					and unit.side == actor.side
					and unit.is_active()
				):
					return unit.unit_id
	return &""


static func _has_poison_from_actor(
	target: BattleUnitState,
	actor_id: StringName,
	axis: StringName,
	round_number: int
) -> bool:
	for snapshot: Dictionary in target.get_poison_source_snapshots(axis, round_number):
		var source: RefCounted = snapshot.get("source") as RefCounted
		if (
			is_instance_valid(source)
			and source.get("source_unit_id") == actor_id
			and int(snapshot.get("stacks", 0)) > 0
		):
			return true
	return false


static func _damage_bonus_met(
	condition: int,
	target: BattleUnitState,
	round_number: int,
	records: Array[BattleActionRecord]
) -> bool:
	match condition:
		BattleSkillEffectDefinition.BonusCondition.MOVED_THIS_ROUND:
			return BattleHistoryQuery.moved_this_round(records, target.unit_id, round_number)
		BattleSkillEffectDefinition.BonusCondition.SNARED_AND_ADVANTAGE:
			return target.is_snared(round_number) and target.has_advantage(round_number)
		BattleSkillEffectDefinition.BonusCondition.LOST_THREE_ARMOR_THIS_ROUND:
			return BattleHistoryQuery.armor_lost_this_round(records, target.unit_id, round_number) >= 3
		BattleSkillEffectDefinition.BonusCondition.NO_ARMOR:
			return target.get_armor() == 0
		BattleSkillEffectDefinition.BonusCondition.LOST_ARMOR_THIS_ROUND:
			return BattleHistoryQuery.armor_lost_this_round(records, target.unit_id, round_number) > 0
	return false
