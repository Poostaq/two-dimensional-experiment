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
	declared_move_path: Array[int] = []
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
	if not _conditions_met(actor, skill, locked_targets, units, round_number, history):
		return null

	var damage_operations: Array[Dictionary] = []
	var speed_operations: Array[Dictionary] = []
	var keyword_operations: Array[RefCounted] = []
	var locked_advantage_source: RefCounted = null
	var consume_advantage: bool = false
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
			if int(authored_effect.get("target_role")) == effect_script.TargetRole.HISTORY_ALLY:
				continue
			return null
		match int(authored_effect.get("kind")):
			effect_script.Kind.DAMAGE:
				for target: BattleUnitState in targets:
					var percent: int = int(authored_effect.get("power_percent"))
					var advantage_percent: int = int(authored_effect.get("advantage_power_percent"))
					if advantage_percent > 0 and target.has_advantage(round_number):
						percent = advantage_percent
						locked_advantage_source = target.get_advantage_source(round_number)
						consume_advantage = is_instance_valid(locked_advantage_source)
					var requested: int = BattleDamageRules.physical_damage(
						actor.power,
						float(percent) / 100.0,
						target.defense
					)
					damage_operations.append({
						&"target_id": target.unit_id,
						&"base_damage": requested,
						&"combo_bonus_damage": 0,
						&"total_requested_damage": requested,
					})
			effect_script.Kind.KEYWORD:
				for target: BattleUnitState in targets:
					var source: RefCounted = null
					var operation_kind: int = int(authored_effect.get("keyword_kind"))
					if operation_kind in [
						BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
						BattleKeywordOperation.Kind.APPLY_SNARED,
						BattleKeywordOperation.Kind.APPLY_BLEED,
					]:
						source = BattleKeywordSource.create(actor.unit_id, skill.skill_id, actor.power)
					var operation: RefCounted = BattleKeywordOperation.create(
						operation_kind,
						target.unit_id,
						int(authored_effect.get("magnitude")),
						int(authored_effect.get("duration")),
						source,
						&"",
						bool(authored_effect.get("arms_snared_follow_up"))
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
				pass
			_:
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
		actor.unit_id if not declared_move_path.is_empty() else &"",
		declared_move_path
	)


static func _conditions_met(
	actor: BattleUnitState,
	skill: CharacterSkill,
	locked_targets: Array[BattleUnitState],
	units: Array[BattleUnitState],
	round_number: int,
	history: Array[BattleActionLogEntry]
) -> bool:
	var condition_script: Script = load("res://Scripts/Battle/battle_skill_condition.gd") as Script
	for condition: RefCounted in skill.conditions:
		match int(condition.get("kind")):
			condition_script.Kind.PRIMARY_SNARED:
				if locked_targets.is_empty() or not locked_targets[0].is_snared(round_number):
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
