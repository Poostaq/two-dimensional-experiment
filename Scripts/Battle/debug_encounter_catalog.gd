class_name DebugEncounterCatalog
extends RefCounted


static func get_encounter_name(encounter_index: int = 0) -> String:
	return ["Human Marksmen", "Dwarven Breakers", "Elven Moonwatch"][posmod(encounter_index, 3)]


static func create_enemies(encounter_index: int = 0) -> Array[BattleUnitState]:
	match posmod(encounter_index, 3):
		0:
			return _create_roster_units([
				{&"class_id": &"human_ranger", &"unit_id": &"enemy_0", &"slot": 0},
				{&"class_id": &"human_crosbowman", &"unit_id": &"enemy_4", &"slot": 4},
			])
		1:
			return _create_roster_units([
				{&"class_id": &"dwarf_siege_smith", &"unit_id": &"enemy_0", &"slot": 0},
				{&"class_id": &"dwarf_thunderbreaker", &"unit_id": &"enemy_4", &"slot": 4},
			])
		2:
			return _create_roster_units([
				{&"class_id": &"elf_star_archer", &"unit_id": &"enemy_0", &"slot": 0},
				{&"class_id": &"elf_moon_sage", &"unit_id": &"enemy_4", &"slot": 4},
			])
	return []


static func create_boss_enemies(encounter_index: int = 0) -> Array[BattleUnitState]:
	var clan_ids: Array[StringName] = [&"human", &"dwarf", &"elf"]
	var party: Array[RunCharacter] = BossPartyCatalog.create_by_enemy_clan_id(
		clan_ids[posmod(encounter_index, clan_ids.size())]
	)
	if party.size() != 4:
		return []
	var slots: Array[int] = [1, 0, 2, 4]
	var result: Array[BattleUnitState] = []
	for index: int in party.size():
		result.append(_battle_unit_from_character(
			party[index],
			party[index].class_id,
			slots[index]
		))
	return result


static func _create_roster_units(entries: Array[Dictionary]) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for entry: Dictionary in entries:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(
			entry.get(&"class_id", &"")
		)
		if not is_instance_valid(character):
			return []
		result.append(_battle_unit_from_character(
			character,
			entry.get(&"unit_id", &""),
			int(entry.get(&"slot", -1))
		))
	return result


static func _battle_unit_from_character(
	character: RunCharacter,
	unit_id: StringName,
	slot_index: int
) -> BattleUnitState:
	if (
		not is_instance_valid(character)
		or unit_id.is_empty()
		or not BattleFormationRules.is_valid_slot(slot_index)
	):
		return null
	return BattleUnitState.new(
		unit_id,
		character.display_name,
		BattleUnitState.Side.ENEMY,
		slot_index,
		character.base_speed,
		character.max_hp,
		_enemy_skills(character.get_skills()),
		character.power,
		character.defense,
		character.race_id
	)


static func _enemy_skills(source_skills: Array[CharacterSkill]) -> Array[CharacterSkill]:
	var result: Array[CharacterSkill] = []
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	for skill: CharacterSkill in source_skills:
		var source_profile: RefCounted = skill.target_profile
		if skill.kind != CharacterSkill.Kind.ACTIVE or not is_instance_valid(source_profile):
			result.append(skill.duplicate_skill())
			continue
		var ordered_sides: Array[int] = []
		for target_side: int in source_profile.get("target_sides"):
			ordered_sides.append(_opposing_side(target_side))
		var enemy_profile: RefCounted = profile_script.create(
			int(source_profile.get("minimum_targets")),
			int(source_profile.get("maximum_targets")),
			_opposing_side(int(source_profile.get("target_side"))),
			bool(source_profile.get("require_adjacent_lane")),
			bool(source_profile.get("allows_optional_self_move")),
			ordered_sides
		)
		var enemy_skill: CharacterSkill = CharacterSkill.create(
			skill.skill_id,
			skill.display_name,
			skill.kind,
			skill.effect_text,
			skill.targeting_text,
			skill.requirements_text,
			skill.cooldown_text,
			skill.targeting_mode,
			skill.target_side,
			skill.target_rule,
			skill.requirement,
			skill.effect,
			skill.effect_magnitude,
			skill.effect_duration,
			skill.effect_duration_mode,
			skill.cooldown_mode,
			skill.cooldown_actions,
			skill.unavailable_through_round,
			skill.combo_definition,
			skill.keyword_operations,
			skill.advantage_rider,
			skill.reaction_definition,
			enemy_profile,
			skill.conditions,
			skill.authored_effects
		)
		if not is_instance_valid(enemy_skill):
			return []
		result.append(enemy_skill)
	return result


static func _opposing_side(side: int) -> int:
	return (
		BattleUnitState.Side.PLAYER
		if side == BattleUnitState.Side.ENEMY
		else BattleUnitState.Side.ENEMY
	)


# The same authoritative confirmation planner filters cooldowns, range and setup requirements.
# Prefer a legal conversion, then an opener, retaining unit/skill order to break ties.
static func choose_action(actor: BattleUnitState, units: Array[BattleUnitState], round_number: int, revision: int, history: Array[BattleActionLogEntry], action_records: Array[BattleActionRecord]) -> Dictionary:
	if not is_instance_valid(actor) or not actor.is_active() or actor.side != BattleUnitState.Side.ENEMY:
		return {}
	var best: Dictionary = {}
	var best_score: int = -1
	for skill_index: int in actor.skills.size():
		var skill: CharacterSkill = actor.skills[skill_index]
		var evaluation: SkillTargetEvaluation = BattleSkillRules.evaluate_targets(actor, skill, units, actor.unit_id, false, round_number, revision, history, true)
		if not evaluation.can_start:
			continue
		for target_id: StringName in evaluation.valid_target_ids:
			var targets: Array[StringName] = [target_id]
			var move_path: Array[int] = _move_path_for(actor, skill, target_id, units)
			var confirmation: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(actor, skill, units, actor.unit_id, false, round_number, targets, revision, revision, history, move_path, action_records, true)
			if not confirmation.accepted:
				continue
			var score: int = 20 if skill_index == 0 else 10
			if not skill.conditions.is_empty():
				score = 40 if skill_index == 1 else 35
			if skill_index == 0 and actor.race_id == &"dwarf":
				for unit: BattleUnitState in units:
					if unit.unit_id == target_id:
						score += unit.get_armor()
			if evaluation.maximum_targets > 1:
				for second_id: StringName in evaluation.valid_target_ids:
					if second_id != target_id:
						var pair: Array[StringName] = [target_id, second_id]
						var pair_check: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(actor, skill, units, actor.unit_id, false, round_number, pair, revision, revision, history, move_path, action_records, true)
						if pair_check.accepted:
							targets = pair
							break
			if score > best_score:
				best_score = score
				best = {"skill_id": skill.skill_id, "target_ids": targets, "move_path": move_path}
	return best


static func _move_path_for(
	actor: BattleUnitState,
	skill: CharacterSkill,
	target_id: StringName,
	units: Array[BattleUnitState]
) -> Array[int]:
	var effect_script: Script = load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	for effect: RefCounted in skill.authored_effects:
		match int(effect.get("kind")):
			effect_script.Kind.FORCED_TARGET_MOVE:
				var target: BattleUnitState = _find_unit(units, target_id)
				if not is_instance_valid(target):
					return []
				return _deterministic_ring_path(target.slot_index, int(effect.get("magnitude")))
			effect_script.Kind.OPTIONAL_SELF_MOVE:
				return _deterministic_ring_path(actor.slot_index, 1)
	return []


static func _deterministic_ring_path(start_slot: int, distance: int) -> Array[int]:
	if not BattleFormationRules.is_valid_slot(start_slot) or distance < 1 or distance > 3:
		return []
	var path: Array[int] = [start_slot]
	if _append_path_step(path, distance):
		return path
	return []


static func _append_path_step(path: Array[int], remaining: int) -> bool:
	if remaining == 0:
		return true
	for candidate: int in BattleFormationRules.SLOT_COUNT:
		if path.has(candidate) or not BattleFormationRules.is_move_one(path[-1], candidate):
			continue
		path.append(candidate)
		if _append_path_step(path, remaining - 1):
			return true
		path.pop_back()
	return false


static func _find_unit(units: Array[BattleUnitState], unit_id: StringName) -> BattleUnitState:
	for unit: BattleUnitState in units:
		if is_instance_valid(unit) and unit.unit_id == unit_id:
			return unit
	return null
