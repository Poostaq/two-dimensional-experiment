class_name BattleSkillRules
extends RefCounted


static func evaluate_targets(
	actor: BattleUnitState,
	skill: CharacterSkill,
	units: Array[BattleUnitState],
	current_actor_id: StringName,
	battle_complete: bool,
	round_number: int,
	battle_revision: int,
	history_snapshot: Array[BattleActionLogEntry]
) -> SkillTargetEvaluation:
	var reason: SkillActionReason = _evaluate_actor_and_skill(
		actor, skill, current_actor_id, battle_complete, round_number
	)
	var valid_ids: Array[StringName] = []
	var invalid_targets: Dictionary[StringName, SkillActionReason] = {}
	var affected_ids: Array[StringName] = []
	var authored_profile: RefCounted = skill.target_profile if is_instance_valid(skill) else null
	if is_instance_valid(actor) and is_instance_valid(skill) and is_instance_valid(authored_profile):
		if int(authored_profile.get("maximum_targets")) > 0:
			for unit: BattleUnitState in _sorted_units(units):
				if (
					not is_instance_valid(unit)
					or unit == actor
					or unit.side != int(authored_profile.get("target_side"))
				):
					continue
				if not unit.is_active():
					invalid_targets[unit.unit_id] = _reason(
						SkillActionReason.Code.TARGET_DEFEATED,
						"Target was defeated. Select another target.",
						actor,
						skill,
						unit.unit_id
					)
					continue
				if (
					bool(authored_profile.get("require_adjacent_lane"))
					and BattleFormationRules.lane_distance(actor.slot_index, unit.slot_index) != 1
				):
					continue
				valid_ids.append(unit.unit_id)
	elif is_instance_valid(actor) and is_instance_valid(skill):
		if skill.targeting_mode == CharacterSkill.TargetingMode.FREE:
			for unit: BattleUnitState in _sorted_units(units):
				if not is_instance_valid(unit) or unit.side == actor.side:
					continue
				if unit.is_active():
					valid_ids.append(unit.unit_id)
				else:
					invalid_targets[unit.unit_id] = _reason(
						SkillActionReason.Code.TARGET_DEFEATED,
						"Target was defeated. Select another target.",
						actor,
						skill,
						unit.unit_id
					)
		else:
			affected_ids = _predefined_targets(actor, skill, units)
	var combo_ready_ids: Array[StringName] = []
	var combo_bonus_by_target: Dictionary[StringName, int] = {}
	if is_instance_valid(skill) and is_instance_valid(skill.combo_definition):
		var combo_rules: Script = load("res://Scripts/Battle/battle_combo_rules.gd")
		var combo_candidate_ids: Array[StringName] = (
			valid_ids if skill.targeting_mode == CharacterSkill.TargetingMode.FREE else affected_ids
		)
		for candidate_id: StringName in combo_candidate_ids:
			var candidate_ids: Array[StringName] = [candidate_id]
			var combo_evaluation: RefCounted = combo_rules.evaluate(
				skill.combo_definition, actor, candidate_ids, round_number, history_snapshot
			)
			if not combo_evaluation.activated:
				continue
			var bonus_total: int = 0
			for operation: Dictionary in combo_evaluation.bonus_operations:
				bonus_total += int(operation[&"magnitude"])
			if bonus_total > 0:
				combo_ready_ids.append(candidate_id)
				combo_bonus_by_target[candidate_id] = bonus_total
	if (
		reason.code == SkillActionReason.Code.NONE
		and skill.targeting_mode == CharacterSkill.TargetingMode.PREDEFINED
		and affected_ids.is_empty()
	):
		reason = _reason(
			SkillActionReason.Code.TARGET_INVALID,
			"No valid target is available.",
			actor,
			skill
		)
	var legacy_target_count: int = 1
	if not is_instance_valid(authored_profile) and is_instance_valid(skill) and skill.targeting_mode == CharacterSkill.TargetingMode.PREDEFINED:
		legacy_target_count = affected_ids.size()
	return SkillTargetEvaluation.new(
		actor.unit_id if is_instance_valid(actor) else &"",
		skill.skill_id if is_instance_valid(skill) else &"",
		skill.targeting_mode if is_instance_valid(skill) else CharacterSkill.TargetingMode.PREDEFINED,
		reason.code == SkillActionReason.Code.NONE,
		reason,
		valid_ids,
		invalid_targets,
		affected_ids,
		battle_revision,
		combo_ready_ids,
		combo_bonus_by_target,
		skill.effect_magnitude if is_instance_valid(skill) else 0,
		int(authored_profile.get("minimum_targets")) if is_instance_valid(authored_profile) else legacy_target_count,
		int(authored_profile.get("maximum_targets")) if is_instance_valid(authored_profile) else legacy_target_count,
		bool(authored_profile.get("allows_optional_self_move")) if is_instance_valid(authored_profile) else false
	)


static func validate_confirmation(
	actor: BattleUnitState,
	skill: CharacterSkill,
	units: Array[BattleUnitState],
	current_actor_id: StringName,
	battle_complete: bool,
	round_number: int,
	proposed_target_ids: Array[StringName],
	expected_revision: int,
	current_revision: int,
	history_snapshot: Array[BattleActionLogEntry],
	proposed_move_path: Array[int] = []
) -> SkillConfirmationValidation:
	if expected_revision != current_revision:
		return _rejected(
			actor,
			skill,
			proposed_target_ids,
			current_revision,
			_reason(
				SkillActionReason.Code.REVISION_MISMATCH,
				"Battle state changed. Review this skill again.",
				actor,
				skill
			)
		)
	var evaluation: SkillTargetEvaluation = evaluate_targets(
		actor,
		skill,
		units,
		current_actor_id,
		battle_complete,
		round_number,
		current_revision,
		history_snapshot
	)
	if not evaluation.can_start:
		return _rejected(
			actor,
			skill,
			proposed_target_ids,
			current_revision,
			evaluation.blocking_reason
		)
	var accepted_ids: Array[StringName] = []
	var authored_profile: RefCounted = skill.target_profile
	if is_instance_valid(authored_profile):
		var minimum_targets: int = int(authored_profile.get("minimum_targets"))
		var maximum_targets: int = int(authored_profile.get("maximum_targets"))
		if proposed_target_ids.size() < minimum_targets or proposed_target_ids.size() > maximum_targets:
			return _rejected(
				actor,
				skill,
				proposed_target_ids,
				current_revision,
				_reason(
					SkillActionReason.Code.TARGET_INVALID,
					"Select between %d and %d valid targets." % [minimum_targets, maximum_targets],
					actor,
					skill
				)
			)
		for target_id: StringName in proposed_target_ids:
			if accepted_ids.has(target_id) or not evaluation.valid_target_ids.has(target_id):
				return _rejected(
					actor,
					skill,
					proposed_target_ids,
					current_revision,
					_target_rejection(actor, skill, units, target_id)
				)
			accepted_ids.append(target_id)
		var locked_targets: Array[BattleUnitState] = []
		for target_id: StringName in accepted_ids:
			locked_targets.append(_find_unit(units, target_id))
		var resolver_script: Script = load("res://Scripts/Battle/battle_skill_authoring_resolver.gd") as Script
		var authored_plan: SkillEffectPlan = resolver_script.build_plan(
			actor,
			skill,
			locked_targets,
			units,
			round_number,
			current_revision,
			history_snapshot,
			proposed_move_path
		)
		if not is_instance_valid(authored_plan):
			return _rejected(
				actor,
				skill,
				proposed_target_ids,
				current_revision,
				_reason(
					SkillActionReason.Code.TARGET_INVALID,
					"Authored skill requirements changed. Review this skill again.",
					actor,
					skill
				)
			)
		return SkillConfirmationValidation.new(
			true,
			SkillActionReason.none(),
			actor.unit_id,
			skill.skill_id,
			accepted_ids,
			current_revision,
			authored_plan
		)
	if skill.targeting_mode == CharacterSkill.TargetingMode.FREE:
		if (
			proposed_target_ids.size() != 1
			or not evaluation.valid_target_ids.has(proposed_target_ids[0])
		):
			var target_id: StringName = proposed_target_ids[0] if not proposed_target_ids.is_empty() else &""
			return _rejected(
				actor,
				skill,
				proposed_target_ids,
				current_revision,
				_target_rejection(actor, skill, units, target_id)
			)
		accepted_ids = proposed_target_ids.duplicate()
	elif proposed_target_ids != evaluation.affected_target_ids:
		return _rejected(
			actor,
			skill,
			proposed_target_ids,
			current_revision,
			_reason(
				SkillActionReason.Code.TARGET_INVALID,
				"Battle state changed. Review this skill again.",
				actor,
				skill
			)
		)
	else:
		accepted_ids = evaluation.affected_target_ids.duplicate()
	var damage_operations: Array[Dictionary] = []
	var speed_operations: Array[Dictionary] = []
	var combo_bonus_by_target: Dictionary[StringName, int] = {}
	if is_instance_valid(skill.combo_definition):
		var combo_rules: Script = load("res://Scripts/Battle/battle_combo_rules.gd")
		var combo_evaluation: RefCounted = combo_rules.evaluate(
			skill.combo_definition, actor, accepted_ids, round_number, history_snapshot
		)
		if combo_evaluation.activated:
			for operation: Dictionary in combo_evaluation.bonus_operations:
				for target_id: StringName in operation[&"target_ids"]:
					combo_bonus_by_target[target_id] = (
						combo_bonus_by_target.get(target_id, 0) + int(operation[&"magnitude"])
					)
	match skill.effect:
		CharacterSkill.Effect.DAMAGE:
			for target_id: StringName in accepted_ids:
				damage_operations.append({
					&"target_id": target_id,
					&"base_damage": skill.effect_magnitude,
					&"combo_bonus_damage": combo_bonus_by_target.get(target_id, 0),
					&"total_requested_damage": (
						skill.effect_magnitude + combo_bonus_by_target.get(target_id, 0)
					),
				})
		CharacterSkill.Effect.SPEED_BOOST:
			var expiry: BattleUnitState.ModifierExpiry = (
				BattleUnitState.ModifierExpiry.NEXT_ACTION
				if skill.effect_duration_mode == CharacterSkill.EffectDuration.NEXT_ACTION
				else BattleUnitState.ModifierExpiry.CURRENT_ROUND
			)
			for target_id: StringName in accepted_ids:
				speed_operations.append({
					"target_id": target_id,
					"source_id": skill.skill_id,
					"amount": skill.effect_magnitude,
					"expiry": expiry,
					"duration": skill.effect_duration,
					"applied_round": round_number,
				})
	var plan: SkillEffectPlan = SkillEffectPlan.create(
		actor.unit_id,
		skill.skill_id,
		accepted_ids,
		damage_operations,
		speed_operations,
		skill.cooldown_actions,
		true,
		current_revision,
		skill.keyword_operations,
		null,
		skill.advantage_rider
	)
	return SkillConfirmationValidation.new(
		true,
		SkillActionReason.none(),
		actor.unit_id,
		skill.skill_id,
		accepted_ids,
		current_revision,
		plan
	)


static func _evaluate_actor_and_skill(
	actor: BattleUnitState,
	skill: CharacterSkill,
	current_actor_id: StringName,
	battle_complete: bool,
	round_number: int
) -> SkillActionReason:
	if not is_instance_valid(actor) or not actor.is_active():
		return _reason(
			SkillActionReason.Code.ACTOR_INACTIVE,
			"Acting unit is no longer active.",
			actor,
			skill
		)
	if battle_complete:
		return _reason(
			SkillActionReason.Code.BATTLE_COMPLETE,
			"Battle is already complete.",
			actor,
			skill
		)
	if actor.side != BattleUnitState.Side.PLAYER:
		return _reason(
			SkillActionReason.Code.ENEMY_NOT_PLAYER_CONTROLLABLE,
			"Enemy skills can only be inspected.",
			actor,
			skill
		)
	if actor.unit_id != current_actor_id:
		return _reason(
			SkillActionReason.Code.NOT_CURRENT_ACTOR,
			"Only the current player unit can act.",
			actor,
			skill
		)
	if not is_instance_valid(skill) or skill.kind == CharacterSkill.Kind.PASSIVE:
		return _reason(
			SkillActionReason.Code.PASSIVE_NOT_ACTIONABLE,
			"Passive skills can only be inspected.",
			actor,
			skill
		)
	if not _actor_owns_skill(actor, skill.skill_id):
		return _reason(
			SkillActionReason.Code.SKILL_AVAILABILITY_CHANGED,
			"Skill availability changed. Review this skill again.",
			actor,
			skill
		)
	if (
		skill.requirement == CharacterSkill.Requirement.FRONT_ROW
		and not BattleFormationRules.is_front_slot(actor.slot_index)
	):
		return _reason(
			SkillActionReason.Code.POSITION_REQUIRED,
			"Requires a front-row position.",
			actor,
			skill
		)
	if (
		skill.requirement == CharacterSkill.Requirement.BACK_ROW
		and not BattleFormationRules.is_back_slot(actor.slot_index)
	):
		return _reason(
			SkillActionReason.Code.POSITION_REQUIRED,
			"Requires a back-row position.",
			actor,
			skill
		)
	if (
		skill.requirement == CharacterSkill.Requirement.ABOVE_HALF_HP
		and actor.current_hp * 2 <= actor.max_hp
	):
		return _reason(
			SkillActionReason.Code.HEALTH_REQUIRED,
			"Requires more than 50% HP.",
			actor,
			skill
		)
	if (
		skill.cooldown_mode == CharacterSkill.CooldownMode.ROUND_GATE
		and round_number <= skill.unavailable_through_round
	):
		return _reason(
			SkillActionReason.Code.PRE_USE_COOLDOWN,
			"Unavailable during round %d." % round_number,
			actor,
			skill
		)
	var remaining: int = actor.get_skill_cooldown(skill.skill_id)
	if remaining > 0:
		return _reason(
			SkillActionReason.Code.POST_USE_COOLDOWN,
			"Ready in %d actions." % remaining,
			actor,
			skill
		)
	return SkillActionReason.none()


static func _predefined_targets(
	actor: BattleUnitState,
	skill: CharacterSkill,
	units: Array[BattleUnitState]
) -> Array[StringName]:
	if skill.target_rule == CharacterSkill.TargetRule.SELF:
		var self_ids: Array[StringName] = []
		if actor.is_active():
			self_ids.append(actor.unit_id)
		return self_ids
	var candidates: Array[BattleUnitState] = []
	for unit: BattleUnitState in units:
		if not is_instance_valid(unit) or not unit.is_active():
			continue
		if (
			skill.target_rule == CharacterSkill.TargetRule.ALL_ACTIVE_ALLIES
			and unit.side == actor.side
		):
			candidates.append(unit)
		elif (
			skill.target_rule == CharacterSkill.TargetRule.FARTHEST_ACTIVE_ENEMY
			and unit.side != actor.side
		):
			candidates.append(unit)
	if skill.target_rule == CharacterSkill.TargetRule.FARTHEST_ACTIVE_ENEMY:
		if candidates.is_empty():
			var empty_ids: Array[StringName] = []
			return empty_ids
		candidates.sort_custom(
			func(first: BattleUnitState, second: BattleUnitState) -> bool:
				return _farthest_comes_before(actor, first, second)
		)
		var farthest_ids: Array[StringName] = [candidates[0].unit_id]
		return farthest_ids
	candidates.sort_custom(
		func(first: BattleUnitState, second: BattleUnitState) -> bool:
			return first.slot_index < second.slot_index
	)
	var ids: Array[StringName] = []
	for candidate: BattleUnitState in candidates:
		ids.append(candidate.unit_id)
	return ids


static func _farthest_comes_before(
	actor: BattleUnitState,
	first: BattleUnitState,
	second: BattleUnitState
) -> bool:
	var actor_lane: int = actor.slot_index % 3
	var first_distance: int = absi((first.slot_index % 3) - actor_lane)
	var second_distance: int = absi((second.slot_index % 3) - actor_lane)
	if first_distance != second_distance:
		return first_distance > second_distance
	var first_back: bool = BattleFormationRules.is_back_slot(first.slot_index)
	var second_back: bool = BattleFormationRules.is_back_slot(second.slot_index)
	if first_back != second_back:
		return first_back
	return first.slot_index > second.slot_index


static func _sorted_units(units: Array[BattleUnitState]) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for unit: BattleUnitState in units:
		if is_instance_valid(unit):
			result.append(unit)
	result.sort_custom(
		func(first: BattleUnitState, second: BattleUnitState) -> bool:
			if first.side != second.side:
				return first.side < second.side
			return first.slot_index < second.slot_index
	)
	return result


static func _target_rejection(
	actor: BattleUnitState,
	skill: CharacterSkill,
	units: Array[BattleUnitState],
	target_id: StringName
) -> SkillActionReason:
	var target: BattleUnitState = _find_unit(units, target_id)
	if not is_instance_valid(target):
		return _reason(
			SkillActionReason.Code.TARGET_REMOVED,
			"Target is no longer in battle. Select another target.",
			actor,
			skill,
			target_id
		)
	if not target.is_active():
		return _reason(
			SkillActionReason.Code.TARGET_DEFEATED,
			"Target was defeated. Select another target.",
			actor,
			skill,
			target_id
		)
	if target.side == actor.side:
		return _reason(
			SkillActionReason.Code.TARGET_OWNERSHIP_CHANGED,
			"Target changed sides and is no longer valid.",
			actor,
			skill,
			target_id
		)
	return _reason(
		SkillActionReason.Code.TARGET_INVALID,
		"Invalid target.",
		actor,
		skill,
		target_id
	)


static func _find_unit(
	units: Array[BattleUnitState],
	unit_id: StringName
) -> BattleUnitState:
	for unit: BattleUnitState in units:
		if is_instance_valid(unit) and unit.unit_id == unit_id:
			return unit
	return null


static func _actor_owns_skill(actor: BattleUnitState, skill_id: StringName) -> bool:
	for owned_skill: CharacterSkill in actor.skills:
		if owned_skill.skill_id == skill_id:
			return true
	return false


static func _rejected(
	actor: BattleUnitState,
	skill: CharacterSkill,
	target_ids: Array[StringName],
	revision: int,
	reason: SkillActionReason
) -> SkillConfirmationValidation:
	return SkillConfirmationValidation.new(
		false,
		reason,
		actor.unit_id if is_instance_valid(actor) else &"",
		skill.skill_id if is_instance_valid(skill) else &"",
		target_ids,
		revision,
		null
	)


static func _reason(
	code: SkillActionReason.Code,
	message: String,
	actor: BattleUnitState,
	skill: CharacterSkill,
	target_id: StringName = &""
) -> SkillActionReason:
	return SkillActionReason.new(
		code,
		message,
		actor.unit_id if is_instance_valid(actor) else &"",
		skill.skill_id if is_instance_valid(skill) else &"",
		target_id
	)
