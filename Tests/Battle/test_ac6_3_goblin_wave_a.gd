class_name Ac6_3GoblinWaveATests
extends SceneTree

const TARGET_PROFILE_PATH := "res://Scripts/Battle/battle_skill_target_profile.gd"
const EFFECT_DEFINITION_PATH := "res://Scripts/Battle/battle_skill_effect_definition.gd"
const CONDITION_PATH := "res://Scripts/Battle/battle_skill_condition.gd"
const AUTHORING_RESOLVER_PATH := "res://Scripts/Battle/battle_skill_authoring_resolver.gd"
const WAVE_A_CATALOG_PATH := "res://Scripts/Run/goblin_wave_a_catalog.gd"

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	_test_authoring_value_objects()
	_test_character_skill_authoring()
	_test_advantage_damage_definition()
	_test_authoring_resolver()
	_test_authored_target_profiles()
	_test_multi_target_and_movement_transaction()
	_test_wave_a_catalog()
	if _failures.is_empty():
		print("AC6.3 Goblin wave A: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AC6.3 Goblin wave A: %d assertion(s), %d failure(s)." % [_assertions, _failures.size()])
	quit(1)


func _test_authoring_value_objects() -> void:
	var target_profile_script := load(TARGET_PROFILE_PATH) as Script
	var effect_definition_script := load(EFFECT_DEFINITION_PATH) as Script
	var condition_script := load(CONDITION_PATH) as Script
	_expect(is_instance_valid(target_profile_script), "target profile script exists")
	_expect(is_instance_valid(effect_definition_script), "effect definition script exists")
	_expect(is_instance_valid(condition_script), "condition script exists")
	if not is_instance_valid(target_profile_script) or not is_instance_valid(effect_definition_script) or not is_instance_valid(condition_script):
		return

	var one_enemy: RefCounted = target_profile_script.create(1, 1, BattleUnitState.Side.ENEMY, false, false)
	var one_or_two_enemies: RefCounted = target_profile_script.create(1, 2, BattleUnitState.Side.ENEMY, false, false)
	var adjacent_ally: RefCounted = target_profile_script.create(1, 1, BattleUnitState.Side.PLAYER, true, false)
	var optional_self_move: RefCounted = target_profile_script.create(0, 0, BattleUnitState.Side.PLAYER, false, true)
	var damage: RefCounted = effect_definition_script.damage(
		effect_definition_script.TargetRole.PRIMARY,
		85
	)
	var armor: RefCounted = effect_definition_script.keyword(
		effect_definition_script.TargetRole.HISTORY_ALLY,
		BattleKeywordOperation.Kind.ADD_ARMOR,
		2
	)
	var snared: RefCounted = condition_script.create(condition_script.Kind.PRIMARY_SNARED)

	_expect(is_instance_valid(one_enemy) and one_enemy.is_valid(), "single enemy profile is valid")
	_expect(one_or_two_enemies.maximum_targets == 2, "Ring Net can lock two enemies")
	_expect(adjacent_ally.require_adjacent_lane, "Pack Brace requires adjacency")
	_expect(optional_self_move.allows_optional_self_move, "Slipstep exposes optional Move 1")
	_expect(damage.power_percent == 85, "damage stores integer Power percentage")
	_expect(armor.target_role == effect_definition_script.TargetRole.HISTORY_ALLY, "history recipient is semantic")
	_expect(is_instance_valid(snared) and snared.is_valid(), "Snared condition is valid")

	_expect(target_profile_script.create(0, 0, BattleUnitState.Side.ENEMY, false, false) == null, "empty non-movement profile rejects")
	_expect(target_profile_script.create(2, 1, BattleUnitState.Side.ENEMY, false, false) == null, "minimum above maximum rejects")
	_expect(target_profile_script.create(1, 3, BattleUnitState.Side.ENEMY, false, false) == null, "more than two selected targets rejects")
	_expect(target_profile_script.create(1, 1, BattleUnitState.Side.PLAYER, false, true) == null, "movement combined with selection rejects")
	_expect(effect_definition_script.damage(effect_definition_script.TargetRole.PRIMARY, 0) == null, "non-positive Power percentage rejects")
	_expect(
		effect_definition_script.keyword(
			effect_definition_script.TargetRole.PRIMARY,
			BattleKeywordOperation.Kind.ADD_ARMOR,
			0
		) == null,
		"Armor without magnitude rejects"
	)
	_expect(
		effect_definition_script.keyword(
			effect_definition_script.TargetRole.PRIMARY,
			BattleKeywordOperation.Kind.APPLY_SNARED,
			0,
			0
		) == null,
		"Snared without duration rejects"
	)
	_expect(condition_script.create(999) == null, "unknown condition rejects")


func _test_character_skill_authoring() -> void:
	var target_profile_script := load(TARGET_PROFILE_PATH) as Script
	var effect_definition_script := load(EFFECT_DEFINITION_PATH) as Script
	var condition_script := load(CONDITION_PATH) as Script
	var profile: RefCounted = target_profile_script.create(
		1,
		1,
		BattleUnitState.Side.ENEMY,
		false,
		false
	)
	var condition: RefCounted = condition_script.create(condition_script.Kind.PRIMARY_SNARED)
	var effect: RefCounted = effect_definition_script.damage(
		effect_definition_script.TargetRole.PRIMARY,
		115
	)
	var conditions: Array[RefCounted] = [condition]
	var effects: Array[RefCounted] = [effect]
	var skill := CharacterSkill.create(
		&"holdfast_wire",
		"Holdfast Wire",
		CharacterSkill.Kind.ACTIVE,
		"Against a Snared enemy, deal 115% Power and reduce Speed by 1 this round.",
		"One selected active enemy.",
		"Target must be Snared.",
		"CD2",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.NONE,
		0,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		2,
		0,
		null,
		[],
		null,
		null,
		profile,
		conditions,
		effects
	)
	_expect(is_instance_valid(skill) and skill.is_valid(), "authored CharacterSkill is valid")
	if not is_instance_valid(skill):
		return
	_expect(skill.target_profile.maximum_targets == 1, "skill retains target profile")
	_expect(skill.conditions.size() == 1, "skill retains conditions")
	_expect(skill.authored_effects.size() == 1, "skill retains authored effects")

	var returned_conditions: Array[RefCounted] = skill.conditions
	returned_conditions.clear()
	_expect(skill.conditions.size() == 1, "condition getter is defensive")
	var returned_effects: Array[RefCounted] = skill.authored_effects
	returned_effects.clear()
	_expect(skill.authored_effects.size() == 1, "effect getter is defensive")

	var duplicate: CharacterSkill = skill.duplicate_skill()
	_expect(is_instance_valid(duplicate) and duplicate.is_valid(), "authored skill duplicates")
	_expect(duplicate.target_profile.maximum_targets == 1, "duplicate retains profile")
	_expect(duplicate.conditions.size() == 1, "duplicate retains conditions")
	_expect(duplicate.authored_effects.size() == 1, "duplicate retains effects")

	var legacy := CharacterSkill.create(
		&"legacy_hit",
		"Legacy Hit",
		CharacterSkill.Kind.ACTIVE,
		"Deal 3 damage.",
		"One enemy.",
		"None",
		"None",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		3
	)
	_expect(is_instance_valid(legacy) and legacy.is_valid(), "legacy CharacterSkill remains valid")

	var duplicate_conditions: Array[RefCounted] = [
		condition,
		condition.duplicate_condition(),
	]
	var invalid := CharacterSkill.create(
		&"duplicate_condition",
		"Duplicate Condition",
		CharacterSkill.Kind.ACTIVE,
		"Invalid.",
		"One enemy.",
		"Target must be Snared.",
		"CD1",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.NONE,
		0,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		1,
		0,
		null,
		[],
		null,
		null,
		profile,
		duplicate_conditions,
		effects
	)
	_expect(invalid == null, "duplicate authored condition kinds reject")


func _test_advantage_damage_definition() -> void:
	var effect_definition_script := load(EFFECT_DEFINITION_PATH) as Script
	var cheap_finish: RefCounted = effect_definition_script.damage(
		effect_definition_script.TargetRole.PRIMARY,
		120,
		160
	)
	_expect(is_instance_valid(cheap_finish), "Advantage damage definition is valid")
	_expect(cheap_finish.power_percent == 120, "base Power percentage is retained")
	_expect(cheap_finish.advantage_power_percent == 160, "Advantage Power percentage is retained")
	var copied: RefCounted = cheap_finish.duplicate_definition()
	_expect(copied.advantage_power_percent == 160, "Advantage percentage duplicates")
	_expect(
		effect_definition_script.damage(effect_definition_script.TargetRole.PRIMARY, 120, 100) == null,
		"Advantage percentage must exceed base percentage"
	)


func _test_authoring_resolver() -> void:
	var resolver_script := load(AUTHORING_RESOLVER_PATH) as Script
	_expect(is_instance_valid(resolver_script), "authoring resolver script exists")
	if not is_instance_valid(resolver_script):
		return
	var profile_script := load(TARGET_PROFILE_PATH) as Script
	var effect_script := load(EFFECT_DEFINITION_PATH) as Script
	var profile: RefCounted = profile_script.create(1, 1, BattleUnitState.Side.ENEMY)
	var damage: RefCounted = effect_script.damage(effect_script.TargetRole.PRIMARY, 120, 160)
	var skill := _authored_test_skill(
		&"cheap_finish",
		2,
		profile,
		[],
		[damage]
	)
	var actor := BattleUnitState.new(
		&"wirefang",
		"Wirefang",
		BattleUnitState.Side.PLAYER,
		0,
		10,
		14,
		[skill],
		6,
		0
	)
	var plain_target := BattleUnitState.new(
		&"plain_target",
		"Plain Target",
		BattleUnitState.Side.ENEMY,
		0,
		5,
		20,
		[],
		4,
		0
	)
	var marked_target := BattleUnitState.new(
		&"marked_target",
		"Marked Target",
		BattleUnitState.Side.ENEMY,
		1,
		5,
		20,
		[],
		4,
		0
	)
	var source := BattleKeywordSource.create(&"setup", &"mark", 4)
	marked_target.apply_advantage(source, 1)
	var units: Array[BattleUnitState] = [actor, plain_target, marked_target]
	var plain_targets: Array[BattleUnitState] = [plain_target]
	var marked_targets: Array[BattleUnitState] = [marked_target]
	var empty_history: Array[BattleActionLogEntry] = []

	var plain_plan: SkillEffectPlan = resolver_script.build_plan(
		actor,
		skill,
		plain_targets,
		units,
		1,
		7,
		empty_history
	)
	_expect(is_instance_valid(plain_plan), "base authored damage plan builds")
	_expect(plain_plan.damage_operations[0][&"base_damage"] == 8, "ceil(6 * 1.20) is 8")
	_expect(not plain_plan.consume_advantage, "unmarked target does not consume Advantage")

	var marked_plan: SkillEffectPlan = resolver_script.build_plan(
		actor,
		skill,
		marked_targets,
		units,
		1,
		7,
		empty_history
	)
	_expect(marked_plan.damage_operations[0][&"base_damage"] == 10, "ceil(6 * 1.60) is 10")
	_expect(marked_plan.consume_advantage, "marked target locks Advantage consumption")


func _test_authored_target_profiles() -> void:
	var profile_script := load(TARGET_PROFILE_PATH) as Script
	var effect_script := load(EFFECT_DEFINITION_PATH) as Script
	var adjacent_profile: RefCounted = profile_script.create(
		1,
		1,
		BattleUnitState.Side.PLAYER,
		true,
		false
	)
	var armor_effect: RefCounted = effect_script.keyword(
		effect_script.TargetRole.PRIMARY,
		BattleKeywordOperation.Kind.ADD_ARMOR,
		3
	)
	var pack_brace := _authored_test_skill(
		&"pack_brace",
		2,
		adjacent_profile,
		[],
		[armor_effect]
	)
	var actor := BattleUnitState.new(
		&"bruiser",
		"Bruiser",
		BattleUnitState.Side.PLAYER,
		0,
		7,
		20,
		[pack_brace],
		4,
		2
	)
	var adjacent := BattleUnitState.new(
		&"adjacent",
		"Adjacent",
		BattleUnitState.Side.PLAYER,
		1,
		6
	)
	var distant := BattleUnitState.new(
		&"distant",
		"Distant",
		BattleUnitState.Side.PLAYER,
		2,
		6
	)
	var enemy := BattleUnitState.new(
		&"enemy",
		"Enemy",
		BattleUnitState.Side.ENEMY,
		0,
		6
	)
	var units: Array[BattleUnitState] = [actor, adjacent, distant, enemy]
	var history: Array[BattleActionLogEntry] = []
	var evaluation: SkillTargetEvaluation = BattleSkillRules.evaluate_targets(
		actor,
		pack_brace,
		units,
		actor.unit_id,
		false,
		1,
		4,
		history
	)
	_expect(evaluation.minimum_targets == 1, "authored evaluation exposes minimum target count")
	_expect(evaluation.maximum_targets == 1, "authored evaluation exposes maximum target count")
	_expect(evaluation.valid_target_ids == [&"adjacent"], "adjacent ally filter is authoritative")

	var ring_profile: RefCounted = profile_script.create(
		1,
		2,
		BattleUnitState.Side.ENEMY,
		false,
		false
	)
	var snare_effect: RefCounted = effect_script.keyword(
		effect_script.TargetRole.ALL_SELECTED,
		BattleKeywordOperation.Kind.APPLY_SNARED,
		0,
		1
	)
	var ring_net := _authored_test_skill(&"ring_net", 4, ring_profile, [], [snare_effect])
	actor.set_skills([ring_net])
	var ring_evaluation: SkillTargetEvaluation = BattleSkillRules.evaluate_targets(
		actor,
		ring_net,
		units,
		actor.unit_id,
		false,
		1,
		4,
		history
	)
	_expect(ring_evaluation.minimum_targets == 1, "Ring Net minimum is one")
	_expect(ring_evaluation.maximum_targets == 2, "Ring Net maximum is two")
	_expect(ring_evaluation.valid_target_ids == [&"enemy"], "Ring Net exposes active enemies")


func _test_multi_target_and_movement_transaction() -> void:
	var no_invalid: Dictionary[StringName, SkillActionReason] = {}
	var ring_evaluation := SkillTargetEvaluation.new(
		&"snarewright",
		&"ring_net",
		CharacterSkill.TargetingMode.FREE,
		true,
		SkillActionReason.none(),
		[&"enemy_a", &"enemy_b", &"enemy_c"],
		no_invalid,
		[],
		9,
		[],
		{},
		0,
		1,
		2,
		false
	)
	var transaction := BattleSkillTransaction.new()
	var generation: int = transaction.preview(ring_evaluation)
	_expect(transaction.begin_targeting(generation), "Ring Net targeting begins")
	_expect(transaction.select_target(&"enemy_a", generation), "Ring Net selects first target")
	_expect(transaction.select_target(&"enemy_b", generation), "Ring Net selects second target")
	_expect(not transaction.select_target(&"enemy_c", generation), "Ring Net rejects third target")
	_expect(transaction.locked_target_ids == [&"enemy_a", &"enemy_b"], "Ring Net retains two locks")
	_expect(transaction.begin_confirmation(generation), "Ring Net confirms with two targets")
	transaction.cancel(generation)
	_expect(transaction.locked_target_ids.is_empty(), "cancel clears all Ring Net locks")

	var movement_evaluation := SkillTargetEvaluation.new(
		&"wirefang",
		&"slipstep",
		CharacterSkill.TargetingMode.FREE,
		true,
		SkillActionReason.none(),
		[],
		no_invalid,
		[],
		10,
		[],
		{},
		0,
		0,
		0,
		true
	)
	generation = transaction.preview(movement_evaluation)
	_expect(transaction.begin_targeting(generation), "Slipstep targeting begins")
	_expect(transaction.set_declared_move_path([0, 3], generation), "Slipstep accepts declared Move 1")
	_expect(transaction.declared_move_path == [0, 3], "Slipstep retains declared path")
	_expect(transaction.begin_confirmation(generation), "Slipstep confirms without target locks")


func _test_wave_a_catalog() -> void:
	var catalog_script := load(WAVE_A_CATALOG_PATH) as Script
	_expect(is_instance_valid(catalog_script), "Wave A catalog script exists")
	if not is_instance_valid(catalog_script):
		return
	var expected: Dictionary[StringName, Dictionary] = {
		&"scrapshield_bruiser": {
			"name": "Scrapshield Bruiser",
			"hp": 20,
			"power": 4,
			"speed": 7,
			"defense": 2,
			"skills": [&"shield_tap", &"pack_brace", &"banner_nudge"],
		},
		&"wirefang_skirmisher": {
			"name": "Wirefang Skirmisher",
			"hp": 14,
			"power": 6,
			"speed": 10,
			"defense": 0,
			"skills": [&"quick_mark", &"cheap_finish", &"slipstep"],
		},
		&"snarewright": {
			"name": "Snarewright",
			"hp": 16,
			"power": 4,
			"speed": 9,
			"defense": 1,
			"skills": [&"tripline_tag", &"holdfast_wire", &"ring_net"],
		},
	}
	for class_id: StringName in expected:
		var character: RunCharacter = catalog_script.create_by_class_id(class_id)
		var contract: Dictionary = expected[class_id]
		_expect(is_instance_valid(character), "%s catalog entry exists" % class_id)
		if not is_instance_valid(character):
			continue
		_expect(character.character_id == class_id, "%s stable ID matches" % class_id)
		_expect(character.display_name == contract["name"], "%s display name matches" % class_id)
		_expect(character.max_hp == contract["hp"], "%s Health matches" % class_id)
		_expect(character.power == contract["power"], "%s Power matches" % class_id)
		_expect(character.base_speed == contract["speed"], "%s Speed matches" % class_id)
		_expect(character.defense == contract["defense"], "%s Defense matches" % class_id)
		var skills: Array[CharacterSkill] = character.get_skills()
		var skill_ids: Array[StringName] = []
		for skill: CharacterSkill in skills:
			_expect(skill.kind == CharacterSkill.Kind.ACTIVE and skill.is_valid(), "%s skill is valid Active" % skill.skill_id)
			skill_ids.append(skill.skill_id)
		_expect(skill_ids == contract["skills"], "%s exact loadout matches" % class_id)
	_expect(catalog_script.create_by_class_id(&"unknown") == null, "unknown Wave A class rejects")
	_expect(is_instance_valid(RunCharacterCatalog.create_by_class_id(&"snarewright")), "root catalog delegates Wave A ID")
	_expect(RunCharacterCatalog.create_by_class_id(&"unknown") == null, "root catalog rejects unknown class ID")


func _authored_test_skill(
	skill_id: StringName,
	cooldown: int,
	profile: RefCounted,
	conditions: Array[RefCounted],
	effects: Array[RefCounted]
) -> CharacterSkill:
	return CharacterSkill.create(
		skill_id,
		String(skill_id),
		CharacterSkill.Kind.ACTIVE,
		"Authored effect.",
		"Authored targets.",
		"Authored requirements.",
		"CD%d" % cooldown,
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.NONE,
		0,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		cooldown,
		0,
		null,
		[],
		null,
		null,
		profile,
		conditions,
		effects
	)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
