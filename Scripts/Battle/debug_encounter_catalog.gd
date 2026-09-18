class_name DebugEncounterCatalog
extends RefCounted

const EFFECT_PATH: String = "res://Scripts/Battle/battle_skill_effect_definition.gd"
const CONDITION_PATH: String = "res://Scripts/Battle/battle_skill_condition.gd"

static func get_encounter_name(encounter_index: int = 0) -> String:
	return ["Human Marksmen", "Dwarven Breakers", "Elven Moonwatch"][posmod(encounter_index, 3)]

static func create_enemies(encounter_index: int = 0) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	match posmod(encounter_index, 3):
		0:
			result.append(_unit(&"enemy_0", "Ranger", &"human", 0, 18, 7, 7, 1, _ranger()))
			result.append(_unit(&"enemy_4", "Crossbowman", &"human", 4, 20, 6, 6, 2, _crossbowman()))
		1:
			result.append(_unit(&"enemy_0", "Siege Smith", &"dwarf", 0, 26, 8, 3, 3, _siege_smith()))
			result.append(_unit(&"enemy_4", "Thunderbreaker", &"dwarf", 4, 25, 8, 2, 3, _thunderbreaker()))
		2:
			result.append(_unit(&"enemy_0", "Star Archer", &"elf", 0, 16, 7, 8, 1, _star_archer()))
			result.append(_unit(&"enemy_4", "Moon Sage", &"elf", 4, 15, 7, 7, 0, _moon_sage()))
	return result

static func _unit(id: StringName, title: String, race: StringName, slot: int, hp: int, power: int, speed: int, defense: int, skills: Array[CharacterSkill]) -> BattleUnitState:
	return BattleUnitState.new(id, title, BattleUnitState.Side.ENEMY, slot, speed, hp, skills, power, defense, race)

static func _ranger() -> Array[CharacterSkill]:
	var effect: Script = load(EFFECT_PATH)
	var condition: Script = load(CONDITION_PATH)
	return [
		_skill(&"quick_draw", "Quick Draw", 1, "Deal 90% Power and apply Snared until round end.", [], [effect.damage(1, 90), effect.keyword(1, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1)]),
		_skill(&"pinning_volley", "Pinning Volley", 2, "Deal 130% Power to a Snared enemy, then apply Advantage until round end.", [condition.create(condition.Kind.PRIMARY_SNARED)], [effect.damage(1, 130), effect.keyword(1, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
		_skill(&"break_the_angle", "Break the Angle", 4, "Deal 170% Power to a Snared or Advantage enemy; with both, consume Advantage and deal 210%.", [condition.create(condition.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [effect.conditional_damage(1, 170, 210, effect.BonusCondition.SNARED_AND_ADVANTAGE, true)]),
	]

static func _crossbowman() -> Array[CharacterSkill]:
	var effect: Script = load(EFFECT_PATH)
	var condition: Script = load(CONDITION_PATH)
	return [
		_skill(&"sightline_mark", "Sightline Mark", 1, "Deal 80% Power and apply Advantage until round end.", [], [effect.damage(1, 80), effect.keyword(1, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
		_skill(&"repeating_shot", "Repeating Shot", 2, "Deal 140% Power to a Snared or Advantage enemy; consume Advantage for 170%.", [condition.create(condition.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [effect.damage(1, 140, 170)]),
		_skill(&"commanding_volley", "Commanding Volley", 5, "Choose up to two enemies; the first takes 180% Power with Advantage or 120% otherwise, the second takes 120%.", [], [effect.damage(1, 120, 180), effect.damage(effect.TargetRole.SECONDARY, 120)], false, 2),
	]

static func _siege_smith() -> Array[CharacterSkill]:
	var effect: Script = load(EFFECT_PATH)
	var condition: Script = load(CONDITION_PATH)
	return [
		_skill(&"test_the_plate", "Test the Plate", 1, "Remove up to 2 Armor, then deal 110% Power.", [], [effect.armor_stripping_damage(1, 110, 2)], true),
		_skill(&"hollow_core", "Hollow Core", 3, "Deal 150% Power to an enemy that lost Armor this round; 180% if it lost at least 3.", [condition.create(condition.Kind.PRIMARY_LOST_ARMOR_THIS_ROUND)], [effect.conditional_damage(1, 150, 180, effect.BonusCondition.LOST_THREE_ARMOR_THIS_ROUND)]),
		_skill(&"breakers_verdict", "Breaker's Verdict", 5, "Deal 210% Power ignoring Armor; an unarmored target takes 240%.", [], [effect.conditional_damage(1, 210, 240, effect.BonusCondition.NO_ARMOR, false, true)], true),
	]

static func _thunderbreaker() -> Array[CharacterSkill]:
	var effect: Script = load(EFFECT_PATH)
	var condition: Script = load(CONDITION_PATH)
	return [
		_skill(&"weight_of_the_hammer", "Weight of the Hammer", 1, "Remove up to 2 Armor, then deal 100% Power.", [], [effect.armor_stripping_damage(1, 100, 2)], true),
		_skill(&"cracked_foundation", "Cracked Foundation", 3, "Deal 160% Power to an enemy that lost Armor this round; 190% if it lost at least 3.", [condition.create(condition.Kind.PRIMARY_LOST_ARMOR_THIS_ROUND)], [effect.conditional_damage(1, 160, 190, effect.BonusCondition.LOST_THREE_ARMOR_THIS_ROUND)]),
		_skill(&"thunderfall_decision", "Thunderfall Decision", 5, "Deal 220% Power ignoring Armor; Armor-loss targets take 250%.", [], [effect.conditional_damage(1, 220, 250, effect.BonusCondition.LOST_ARMOR_THIS_ROUND, false, true)], true),
	]

static func _star_archer() -> Array[CharacterSkill]:
	var effect: Script = load(EFFECT_PATH)
	var condition: Script = load(CONDITION_PATH)
	return [
		_skill(&"threaded_aim", "Threaded Aim", 1, "Deal 90% Power and apply Advantage until round end.", [], [effect.damage(1, 90), effect.keyword(1, BattleKeywordOperation.Kind.APPLY_ADVANTAGE, 0, 1)]),
		_skill(&"needle_shot", "Needle Shot", 2, "Deal 140% Power to an Advantage enemy; moved targets take 170%.", [condition.create(condition.Kind.PRIMARY_ADVANTAGE)], [effect.conditional_damage(1, 140, 170, effect.BonusCondition.MOVED_THIS_ROUND)]),
		_skill(&"horizon_pierce", "Horizon Pierce", 5, "Deal 200% Power to a Snared or Advantage enemy; consume Advantage for 230%.", [condition.create(condition.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [effect.damage(1, 200, 230)]),
	]

static func _moon_sage() -> Array[CharacterSkill]:
	var effect: Script = load(EFFECT_PATH)
	var condition: Script = load(CONDITION_PATH)
	return [
		_skill(&"silver_sigil", "Silver Sigil", 1, "Deal 70% Power and apply Snared until round end.", [], [effect.damage(1, 70), effect.keyword(1, BattleKeywordOperation.Kind.APPLY_SNARED, 0, 1)]),
		_skill(&"lunar_thread", "Lunar Thread", 2, "Deal 120% Power to a Snared enemy; moved targets take 150%.", [condition.create(condition.Kind.PRIMARY_SNARED)], [effect.conditional_damage(1, 120, 150, effect.BonusCondition.MOVED_THIS_ROUND)]),
		_skill(&"crescent_collapse", "Crescent Collapse", 5, "Deal 210% Power to a Snared or Advantage enemy; with both, consume Advantage and deal 240%.", [condition.create(condition.Kind.PRIMARY_SNARED_OR_ADVANTAGE)], [effect.conditional_damage(1, 210, 240, effect.BonusCondition.SNARED_AND_ADVANTAGE, true)]),
	]

static func _skill(id: StringName, title: String, cooldown: int, description: String, conditions: Array[RefCounted], effects: Array[RefCounted], adjacent: bool = false, maximum: int = 1) -> CharacterSkill:
	var profile: RefCounted = load("res://Scripts/Battle/battle_skill_target_profile.gd").create(1, maximum, BattleUnitState.Side.PLAYER, adjacent, false)
	return CharacterSkill.create(
		id, title, CharacterSkill.Kind.ACTIVE, description,
		"Neighboring enemy." if adjacent else ("Up to two enemies." if maximum == 2 else "One enemy."),
		description if not conditions.is_empty() else "None",
		"CD%d" % cooldown, CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE, CharacterSkill.Effect.NONE,
		0, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		cooldown, 0, null, [], null, null, profile, conditions, effects
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
			var confirmation: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(actor, skill, units, actor.unit_id, false, round_number, targets, revision, revision, history, [], action_records, true)
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
						var pair_check: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(actor, skill, units, actor.unit_id, false, round_number, pair, revision, revision, history, [], action_records, true)
						if pair_check.accepted:
							targets = pair
							break
			if score > best_score:
				best_score = score
				best = {"skill_id": skill.skill_id, "target_ids": targets}
	return best
