class_name Ac2_9ComboSystemTests
extends SceneTree

const CONDITION_PATH := "res://Scripts/Battle/combo_condition.gd"
const EFFECT_PATH := "res://Scripts/Battle/combo_bonus_effect.gd"
const DEFINITION_PATH := "res://Scripts/Battle/combo_definition.gd"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_combo_value_contracts()
	_test_character_skill_combo_contract()
	_test_action_entry_migration_contract()
	_test_effect_plan_damage_contract()
	_test_quick_strike_and_combo_probe_have_identical_generic_results()
	_test_same_actor_enemy_other_target_zero_and_prior_round_do_not_activate()
	_test_setup_actor_removal_preserves_current_round_evidence()
	_test_preview_combo_state_is_not_confirmation_evidence()
	_test_rules_and_transaction_retain_no_authoritative_history()
	_test_combo_bonus_composes_into_effect_plan()
	await _test_rejected_combo_has_zero_partial_mutation()
	await _test_configure_exit_and_teardown_clear_history_idempotently()
	if _failures.is_empty():
		print("AC2.9 combo system tests: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_combo_value_contracts() -> void:
	_expect(FileAccess.file_exists(CONDITION_PATH), "combo condition script should exist")
	_expect(FileAccess.file_exists(EFFECT_PATH), "combo bonus effect script should exist")
	_expect(FileAccess.file_exists(DEFINITION_PATH), "combo definition script should exist")
	if not (
		FileAccess.file_exists(CONDITION_PATH)
		and FileAccess.file_exists(EFFECT_PATH)
		and FileAccess.file_exists(DEFINITION_PATH)
	):
		return
	var condition_script: Script = load(CONDITION_PATH)
	var effect_script: Script = load(EFFECT_PATH)
	var definition_script: Script = load(DEFINITION_PATH)
	var condition: Variant = condition_script.create(0)
	var effect: Variant = effect_script.create(0, 3)
	var conditions: Array = [condition]
	var effects: Array = [effect]
	var definition: Variant = definition_script.create(
		conditions,
		effects,
		"+3 damage if another ally damaged this target with a skill this round."
	)
	_expect(is_instance_valid(condition), "supported combo condition should construct")
	_expect(is_instance_valid(effect), "positive combo bonus should construct")
	_expect(is_instance_valid(definition), "valid combo definition should construct")
	if not is_instance_valid(definition):
		return
	_expect(definition.conditions.size() == 1, "definition should retain one condition")
	_expect(definition.bonus_effects.size() == 1, "definition should retain one bonus effect")
	_expect(definition.bonus_effects[0].magnitude == 3, "definition should retain bonus magnitude")
	var leaked_conditions: Array = definition.conditions
	leaked_conditions.clear()
	_expect(definition.conditions.size() == 1, "condition getter should be defensive")
	var leaked_effects: Array = definition.bonus_effects
	leaked_effects[0] = null
	_expect(is_instance_valid(definition.bonus_effects[0]), "effect getter should be deeply defensive")
	_expect(condition_script.create(99) == null, "unsupported condition should reject")
	_expect(effect_script.create(0, 0) == null, "non-positive bonus should reject")
	var empty_conditions: Array = []
	var empty_effects: Array = []
	_expect(
		definition_script.create(empty_conditions, effects, "Combo") == null,
		"empty conditions should reject"
	)
	_expect(
		definition_script.create(conditions, empty_effects, "Combo") == null,
		"empty effects should reject"
	)
	_expect(
		definition_script.create(conditions, effects, "   ") == null,
		"blank description should reject"
	)
	var duplicate: Variant = definition.duplicate_definition()
	_expect(duplicate != definition, "duplicate definition should be distinct")
	_expect(duplicate.description_text == definition.description_text, "duplicate should preserve text")


func _test_character_skill_combo_contract() -> void:
	var character_script: Script = load("res://Scripts/Battle/character_skill.gd")
	var create_argument_count := 0
	for method: Dictionary in character_script.get_script_method_list():
		if method.get("name", "") == "create":
			create_argument_count = method.get("args", []).size()
			break
	_expect(create_argument_count >= 19, "CharacterSkill.create should retain combo definition before optional extensions")
	if create_argument_count < 19:
		return
	var condition_script: Script = load(CONDITION_PATH)
	var effect_script: Script = load(EFFECT_PATH)
	var definition_script: Script = load(DEFINITION_PATH)
	var definition: Variant = definition_script.create(
		[condition_script.create(0)],
		[effect_script.create(0, 3)],
		"+3 damage if another ally damaged this target with a skill this round."
	)
	var skill: Variant = character_script.call(
		"create",
		&"combo_probe",
		"Combo Probe",
		CharacterSkill.Kind.ACTIVE,
		"Deal 5 damage.",
		"One active enemy.",
		"None",
		"None",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		5,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		definition
	)
	_expect(is_instance_valid(skill), "active single-target skill should accept combo definition")
	if not is_instance_valid(skill):
		return
	_expect(is_instance_valid(skill.combo_definition), "combo getter should return definition")
	_expect(skill.combo_definition != definition, "combo definition should be copied on input")
	var mechanical: Dictionary = skill.mechanical_definition()
	_expect(mechanical.has("combo_definition"), "mechanical definition should expose combo")
	var leaked: Variant = mechanical["combo_definition"]
	var leaked_conditions: Array = leaked.conditions
	leaked_conditions.clear()
	_expect(skill.combo_definition.conditions.size() == 1, "mechanical combo should be defensive")
	var duplicate: Variant = skill.duplicate_skill()
	_expect(duplicate != skill, "duplicate skill should be distinct")
	_expect(duplicate.combo_definition != skill.combo_definition, "duplicate combo should be distinct")
	var passive: Variant = character_script.call(
		"create",
		&"bad_passive",
		"Bad Passive",
		CharacterSkill.Kind.PASSIVE,
		"None",
		"Self",
		"None",
		"None",
		CharacterSkill.TargetingMode.PREDEFINED,
		CharacterSkill.TargetSide.SELF,
		CharacterSkill.TargetRule.SELF,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.NONE,
		0,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		definition
	)
	_expect(passive == null, "passive skill should reject combo definition")


func _test_action_entry_migration_contract() -> void:
	var script: Script = load("res://Scripts/Battle/battle_action_log_entry.gd")
	var init_argument_count := 0
	var has_duplicate := false
	for method: Dictionary in script.get_script_method_list():
		if method.get("name", "") == "_init":
			init_argument_count = method.get("args", []).size()
		if method.get("name", "") == "duplicate_entry":
			has_duplicate = true
	_expect(init_argument_count == 11, "BattleActionLogEntry constructor should use migrated schema")
	_expect(has_duplicate, "BattleActionLogEntry should deep-duplicate")
	if init_argument_count != 11 or not has_duplicate:
		return
	var result := BattleDamageResult.new(&"actor", &"target", 8, 8, 12, false)
	var target_ids: Array[StringName] = [&"target"]
	var damage_results: Array[BattleDamageResult] = [result]
	var base_by_target: Dictionary[StringName, int] = {&"target": 5}
	var bonus_by_target: Dictionary[StringName, int] = {&"target": 3}
	var speed_targets: Array[StringName] = []
	var entry: Variant = script.new(
		1, 2, &"actor", BattleUnitState.Side.PLAYER, &"combo_probe",
		target_ids, damage_results, base_by_target, bonus_by_target, speed_targets, true
	)
	_expect(entry.actor_side == BattleUnitState.Side.PLAYER, "entry should retain actor side")
	_expect(entry.base_damage_by_target[&"target"] == 5, "entry should retain base damage")
	_expect(entry.combo_bonus_damage_by_target[&"target"] == 3, "entry should retain combo bonus")
	_expect(entry.combo_activated, "entry should retain combo state")
	var duplicate: Variant = entry.duplicate_entry()
	_expect(duplicate != entry, "entry duplicate should be distinct")
	_expect(duplicate.damage_results[0] != entry.damage_results[0], "damage results should deep-copy")


func _test_effect_plan_damage_contract() -> void:
	var script: Script = load("res://Scripts/Battle/skill_effect_plan.gd")
	_expect(script.has_method("create"), "SkillEffectPlan should expose validated create")
	if not script.has_method("create"):
		return
	var operations: Array[Dictionary] = [{
		&"target_id": &"target",
		&"base_damage": 5,
		&"combo_bonus_damage": 3,
		&"total_requested_damage": 8,
	}]
	var target_ids: Array[StringName] = [&"target"]
	var speed_operations: Array[Dictionary] = []
	var plan: Variant = script.create(
		&"actor", &"combo_probe", target_ids, operations, speed_operations, 0, true, 4
	)
	_expect(is_instance_valid(plan), "valid damage operation should construct")
	if not is_instance_valid(plan):
		return
	var leaked: Array[Dictionary] = plan.damage_operations
	leaked[0][&"total_requested_damage"] = 99
	_expect(plan.damage_operations[0][&"total_requested_damage"] == 8, "plan operations should be defensive")
	var invalid: Array[Dictionary] = [{
		&"target_id": &"target",
		&"base_damage": 5,
		&"combo_bonus_damage": 3,
		&"total_requested_damage": 7,
	}]
	_expect(
		script.create(
			&"actor", &"combo_probe", target_ids, invalid, speed_operations, 0, true, 4
		) == null,
		"invalid damage arithmetic should reject"
	)


func _test_quick_strike_and_combo_probe_have_identical_generic_results() -> void:
	var rules_path := "res://Scripts/Battle/battle_combo_rules.gd"
	_expect(FileAccess.file_exists(rules_path), "generic combo rules script should exist")
	if not FileAccess.file_exists(rules_path):
		return
	var rules_script: Script = load(rules_path)
	var condition_script: Script = load(CONDITION_PATH)
	var effect_script: Script = load(EFFECT_PATH)
	var definition_script: Script = load(DEFINITION_PATH)
	var definition: RefCounted = definition_script.create(
		[condition_script.create(0)],
		[effect_script.create(0, 3)],
		"Combo"
	)
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 5)
	var setup_result := BattleDamageResult.new(&"ally", &"target", 5, 5, 15, false)
	var target_ids: Array[StringName] = [&"target"]
	var results: Array[BattleDamageResult] = [setup_result]
	var base: Dictionary[StringName, int] = {&"target": 5}
	var bonus: Dictionary[StringName, int] = {&"target": 0}
	var speed_targets: Array[StringName] = []
	var history: Array[BattleActionLogEntry] = [BattleActionLogEntry.new(
		1, 2, &"ally", BattleUnitState.Side.PLAYER, &"setup",
		target_ids, results, base, bonus, speed_targets, false
	)]
	var evaluation: Variant = rules_script.evaluate(definition, actor, target_ids, 2, history)
	_expect(evaluation.has_combo and evaluation.activated, "different ally setup should activate")
	_expect(evaluation.bonus_operations[0][&"magnitude"] == 3, "activated bonus should be +3")
	var same_actor_history: Array[BattleActionLogEntry] = [BattleActionLogEntry.new(
		1, 2, &"actor", BattleUnitState.Side.PLAYER, &"setup",
		target_ids, results, base, bonus, speed_targets, false
	)]
	var same_actor: Variant = rules_script.evaluate(definition, actor, target_ids, 2, same_actor_history)
	_expect(same_actor.has_combo and not same_actor.activated, "same actor should not activate")
	var previous_round: Variant = rules_script.evaluate(definition, actor, target_ids, 3, history)
	_expect(not previous_round.activated, "previous-round setup should not activate")
	var quick_definition: RefCounted = definition.duplicate_definition()
	var probe_definition: RefCounted = definition.duplicate_definition()
	var quick_result: Variant = rules_script.evaluate(quick_definition, actor, target_ids, 2, history)
	var probe_result: Variant = rules_script.evaluate(probe_definition, actor, target_ids, 2, history)
	_expect(
		quick_result.activated == probe_result.activated
		and quick_result.bonus_operations == probe_result.bonus_operations,
		"differently owned equivalent definitions should evaluate identically"
	)


func _test_same_actor_enemy_other_target_zero_and_prior_round_do_not_activate() -> void:
	var rules_script: Script = load("res://Scripts/Battle/battle_combo_rules.gd")
	var definition: RefCounted = _combo_definition_for_test()
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 5)
	var target_ids: Array[StringName] = [&"target"]
	var same_actor: Array[BattleActionLogEntry] = [
		_combo_history_entry(&"actor", BattleUnitState.Side.PLAYER, &"target", 2, 5)
	]
	var enemy_actor: Array[BattleActionLogEntry] = [
		_combo_history_entry(&"enemy", BattleUnitState.Side.ENEMY, &"target", 2, 5)
	]
	var other_target: Array[BattleActionLogEntry] = [
		_combo_history_entry(&"ally", BattleUnitState.Side.PLAYER, &"other", 2, 5)
	]
	var zero_damage: Array[BattleActionLogEntry] = [
		_combo_history_entry(&"ally", BattleUnitState.Side.PLAYER, &"target", 2, 0)
	]
	var prior_round: Array[BattleActionLogEntry] = [
		_combo_history_entry(&"ally", BattleUnitState.Side.PLAYER, &"target", 1, 5)
	]
	for case: Dictionary in [
		{"name": "same actor", "history": same_actor},
		{"name": "enemy actor", "history": enemy_actor},
		{"name": "other target", "history": other_target},
		{"name": "zero applied damage", "history": zero_damage},
		{"name": "prior round", "history": prior_round},
	]:
		var evaluation: RefCounted = rules_script.evaluate(
			definition, actor, target_ids, 2, case["history"]
		)
		_expect(not evaluation.activated, "%s must not activate combo" % case["name"])


func _test_setup_actor_removal_preserves_current_round_evidence() -> void:
	var rules_script: Script = load("res://Scripts/Battle/battle_combo_rules.gd")
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 5)
	var target_ids: Array[StringName] = [&"target"]
	var committed_history: Array[BattleActionLogEntry] = [
		_combo_history_entry(&"removed_ally", BattleUnitState.Side.PLAYER, &"target", 2, 5)
	]
	var evaluation: RefCounted = rules_script.evaluate(
		_combo_definition_for_test(), actor, target_ids, 2, committed_history
	)
	_expect(
		evaluation.activated,
		"removing the setup actor from live units must not erase committed current-round evidence"
	)


func _test_preview_combo_state_is_not_confirmation_evidence() -> void:
	var rules_script: Script = load("res://Scripts/Battle/battle_combo_rules.gd")
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 5)
	var target_ids: Array[StringName] = [&"target"]
	var preview_history: Array[BattleActionLogEntry] = [
		_combo_history_entry(&"ally", BattleUnitState.Side.PLAYER, &"target", 2, 5)
	]
	var preview: RefCounted = rules_script.evaluate(
		_combo_definition_for_test(), actor, target_ids, 2, preview_history
	)
	var current_history: Array[BattleActionLogEntry] = []
	var confirmation: RefCounted = rules_script.evaluate(
		_combo_definition_for_test(), actor, target_ids, 2, current_history
	)
	_expect(preview.activated, "qualifying preview fixture should activate")
	_expect(
		not confirmation.activated,
		"preview readiness must not become confirmation evidence when current history differs"
	)


func _test_rules_and_transaction_retain_no_authoritative_history() -> void:
	var transaction := BattleSkillTransaction.new()
	var transaction_properties: PackedStringArray = []
	for property: Dictionary in transaction.get_property_list():
		transaction_properties.append(String(property["name"]))
	_expect(
		not transaction_properties.has("_battle_action_log_entries")
		and not transaction_properties.has("history_snapshot")
		and not transaction_properties.has("committed_history"),
		"transaction must not own authoritative history"
	)
	var rules: RefCounted = load("res://Scripts/Battle/battle_combo_rules.gd").new()
	var rule_properties: PackedStringArray = []
	for property: Dictionary in rules.get_property_list():
		rule_properties.append(String(property["name"]))
	_expect(
		not rule_properties.has("_battle_action_log_entries")
		and not rule_properties.has("history_snapshot")
		and not rule_properties.has("committed_history"),
		"combo rules must remain stateless and retain no authoritative history"
	)


func _combo_definition_for_test() -> RefCounted:
	var condition_script: Script = load(CONDITION_PATH)
	var effect_script: Script = load(EFFECT_PATH)
	var definition_script: Script = load(DEFINITION_PATH)
	return definition_script.create(
		[condition_script.create(0)],
		[effect_script.create(0, 3)],
		"Combo"
	)


func _combo_history_entry(
	actor_id: StringName,
	actor_side: BattleUnitState.Side,
	target_id: StringName,
	entry_round: int,
	applied_damage: int
) -> BattleActionLogEntry:
	var target_ids: Array[StringName] = [target_id]
	var results: Array[BattleDamageResult] = [
		BattleDamageResult.new(actor_id, target_id, 5, applied_damage, 15, false)
	]
	var base: Dictionary[StringName, int] = {target_id: 5}
	var bonus: Dictionary[StringName, int] = {target_id: 0}
	var speed_targets: Array[StringName] = []
	return BattleActionLogEntry.new(
		1, entry_round, actor_id, actor_side, &"setup",
		target_ids, results, base, bonus, speed_targets, false
	)


func _test_combo_bonus_composes_into_effect_plan() -> void:
	var condition_script: Script = load(CONDITION_PATH)
	var effect_script: Script = load(EFFECT_PATH)
	var definition_script: Script = load(DEFINITION_PATH)
	var character_script: Script = load("res://Scripts/Battle/character_skill.gd")
	var definition: RefCounted = definition_script.create(
		[condition_script.create(0)],
		[effect_script.create(0, 3)],
		"Combo"
	)
	var skill: CharacterSkill = character_script.call(
		"create",
		&"combo_probe",
		"Combo Probe",
		CharacterSkill.Kind.ACTIVE,
		"Deal 5 damage.",
		"One active enemy.",
		"None",
		"None",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		5,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		definition
	)
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 20)
	actor.set_skills([skill])
	var ally := BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 1, 20)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 20)
	var units: Array[BattleUnitState] = [actor, ally, target]
	var proposed_targets: Array[StringName] = [&"target"]
	var empty_history: Array[BattleActionLogEntry] = []
	var without_combo: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(
		actor, skill, units, &"actor", false, 2, proposed_targets, 4, 4, empty_history
	)
	_expect(without_combo.accepted, "confirmation without setup should remain valid")
	if without_combo.accepted:
		var plain_operation: Dictionary = without_combo.effect_plan.damage_operations[0]
		_expect(
			plain_operation[&"base_damage"] == 5
			and plain_operation[&"combo_bonus_damage"] == 0
			and plain_operation[&"total_requested_damage"] == 5,
			"non-qualifying confirmation should compose 5/0/5 damage"
		)
	var setup_result := BattleDamageResult.new(&"ally", &"target", 5, 5, 15, false)
	var setup_results: Array[BattleDamageResult] = [setup_result]
	var base_by_target: Dictionary[StringName, int] = {&"target": 5}
	var bonus_by_target: Dictionary[StringName, int] = {&"target": 0}
	var no_speed_targets: Array[StringName] = []
	var qualifying_history: Array[BattleActionLogEntry] = [BattleActionLogEntry.new(
		1, 2, &"ally", BattleUnitState.Side.PLAYER, &"setup",
		proposed_targets, setup_results, base_by_target, bonus_by_target, no_speed_targets, false
	)]
	var target_evaluation: SkillTargetEvaluation = BattleSkillRules.evaluate_targets(
		actor, skill, units, &"actor", false, 2, 4, qualifying_history
	)
	_expect(
		target_evaluation.combo_ready_target_ids == [&"target"],
		"target evaluation should derive combo readiness from current history snapshot"
	)
	_expect(
		target_evaluation.combo_bonus_by_target.get(&"target", 0) == 3,
		"target evaluation should expose the qualifying target bonus"
	)
	var with_combo: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(
		actor, skill, units, &"actor", false, 2, proposed_targets, 4, 4, qualifying_history
	)
	_expect(with_combo.accepted, "confirmation with qualifying setup should remain valid")
	if with_combo.accepted:
		var combo_operation: Dictionary = with_combo.effect_plan.damage_operations[0]
		_expect(
			combo_operation[&"base_damage"] == 5
			and combo_operation[&"combo_bonus_damage"] == 3
			and combo_operation[&"total_requested_damage"] == 8,
			"qualifying confirmation should compose 5/3/8 damage"
		)


func _test_rejected_combo_has_zero_partial_mutation() -> void:
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var skill: CharacterSkill = _make_combo_skill(&"rejected_combo", "Rejected Combo")
	var skills: Array[CharacterSkill] = [skill]
	var actor := BattleUnitState.new(
		&"reject_actor", "Reject Actor", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
	)
	var target := BattleUnitState.new(
		&"reject_target", "Reject Target", BattleUnitState.Side.ENEMY, 0, 5, 20
	)
	var units: Array[BattleUnitState] = [actor, target]
	arena.configure_units(units)
	_expect(
		arena.begin_skill_action(&"reject_actor", &"rejected_combo"),
		"rejected combo fixture should start"
	)
	_expect(arena.select_skill_target(&"reject_target"), "rejected combo target should lock")
	target.current_hp = 0
	arena.notify_authoritative_battle_change()
	var before: Dictionary = _arena_mutation_snapshot(arena, actor, target, skill.skill_id)
	_expect(not arena.confirm_skill_action(), "stale combo confirmation should reject")
	var after: Dictionary = _arena_mutation_snapshot(arena, actor, target, skill.skill_id)
	_expect(after == before, "rejected combo must leave every authoritative field unchanged")
	arena.queue_free()
	await process_frame


func _arena_mutation_snapshot(
	arena: BattleArena,
	actor: BattleUnitState,
	target: BattleUnitState,
	skill_id: StringName
) -> Dictionary:
	var queue_ids: Array[StringName] = []
	for unit: BattleUnitState in arena.get_turn_queue():
		queue_ids.append(unit.unit_id)
	return {
		"actor_hp": actor.current_hp,
		"target_hp": target.current_hp,
		"actor_speed": actor.get_effective_speed(),
		"target_speed": target.get_effective_speed(),
		"cooldown": actor.get_skill_cooldown(skill_id),
		"queue_ids": queue_ids,
		"round": arena.round_number,
		"revision": arena.get_battle_revision(),
		"history_count": arena.get_committed_action_history_snapshot().size(),
		"damage_log_count": arena.get_battle_log_entries().size(),
		"outcome": arena.get_battle_outcome(),
		"transaction_state": arena.get_skill_transaction_state(),
	}


func _make_combo_skill(skill_id: StringName, display_name: String) -> CharacterSkill:
	var character_script: Script = load("res://Scripts/Battle/character_skill.gd")
	return character_script.call(
		"create", skill_id, display_name, CharacterSkill.Kind.ACTIVE,
		"Deal 5 damage.", "One active enemy.", "None", "None",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		5, 0, CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE, 0, 0, _combo_definition_for_test()
	)


func _test_combo_confirmation_reentry_commits_once(
	arena: BattleArena,
	target: BattleUnitState
) -> void:
	var hp_after_first_commit: int = target.current_hp
	var revision_after_first_commit: int = arena.get_battle_revision()
	var history_count_after_first_commit: int = (
		arena.get_committed_action_history_snapshot().size()
	)
	_expect(not arena.confirm_skill_action(), "combo confirmation reentry should reject")
	_expect(target.current_hp == hp_after_first_commit, "reentry must not apply damage twice")
	_expect(
		arena.get_battle_revision() == revision_after_first_commit,
		"reentry must not increment revision twice"
	)
	_expect(
		arena.get_committed_action_history_snapshot().size() == history_count_after_first_commit,
		"reentry must not append a second authoritative entry"
	)


func _test_snapshot_and_nested_entry_mutation_cannot_reach_arena(arena: BattleArena) -> void:
	var leaked_snapshot: Array[BattleActionLogEntry] = arena.get_committed_action_history_snapshot()
	leaked_snapshot[0].target_ids.clear()
	leaked_snapshot[0].base_damage_by_target.clear()
	leaked_snapshot[0].combo_bonus_damage_by_target[&"history_target"] = 99
	leaked_snapshot.clear()
	var fresh_snapshot: Array[BattleActionLogEntry] = arena.get_committed_action_history_snapshot()
	_expect(fresh_snapshot.size() == 1, "clearing a snapshot must not clear arena history")
	if fresh_snapshot.size() == 1:
		_expect(
			fresh_snapshot[0].target_ids == [&"history_target"],
			"nested target mutation must not reach arena history"
		)
		_expect(
			fresh_snapshot[0].base_damage_by_target.get(&"history_target", 0) == 5,
			"nested base-damage mutation must not reach arena history"
		)
		_expect(
			fresh_snapshot[0].combo_bonus_damage_by_target.get(&"history_target", 0) == 0,
			"nested combo mutation must not reach arena history"
		)


func _test_completion_retains_history_but_clears_presentation(arena: BattleArena) -> void:
	_expect(arena.is_battle_complete(), "defeating the final enemy should complete the fixture")
	_expect(
		arena.get_committed_action_history_snapshot().size() == 1,
		"battle completion should retain authoritative history"
	)
	var snapshot: Dictionary = arena.get_skill_presentation_snapshot()
	_expect(snapshot["combo_ready_target_ids"].is_empty(), "completion should clear combo-ready IDs")
	_expect(snapshot["indicator_roles"].is_empty(), "completion should clear combo target roles")


func _test_configure_exit_and_teardown_clear_history_idempotently() -> void:
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	var character_script: Script = load("res://Scripts/Battle/character_skill.gd")
	var skill: CharacterSkill = character_script.call(
		"create", &"setup_hit", "Setup Hit", CharacterSkill.Kind.ACTIVE,
		"Deal 5 damage.", "One active enemy.", "None", "None",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		5, 0, CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE, 0, 0, _combo_definition_for_test()
	)
	var skills: Array[CharacterSkill] = [skill]
	var actor := BattleUnitState.new(
		&"history_actor", "History Actor", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
	)
	var target := BattleUnitState.new(
		&"history_target", "History Target", BattleUnitState.Side.ENEMY, 0, 5, 20
	)
	target.current_hp = 5
	var units: Array[BattleUnitState] = [actor, target]
	arena.configure_units(units)
	_expect(arena.begin_skill_action(&"history_actor", &"setup_hit"), "history fixture action should start")
	_expect(arena.select_skill_target(&"history_target"), "history fixture target should lock")
	_expect(arena.confirm_skill_action(), "history fixture action should commit")
	_test_combo_confirmation_reentry_commits_once(arena, target)
	_expect(
		arena.get_committed_action_history_snapshot().size() == 1,
		"history fixture should create one authoritative entry"
	)
	_test_snapshot_and_nested_entry_mutation_cannot_reach_arena(arena)
	_test_completion_retains_history_but_clears_presentation(arena)
	arena.call("_on_exit_debug_pressed")
	_expect(
		arena.get_committed_action_history_snapshot().is_empty(),
		"exit cleanup should clear authoritative combo history"
	)
	_expect(
		arena.get_skill_presentation_snapshot()["combo_ready_target_ids"].is_empty(),
		"exit cleanup should clear derived combo presentation"
	)
	arena.call("_on_exit_debug_pressed")
	_expect(
		arena.get_committed_action_history_snapshot().is_empty(),
		"repeated exit cleanup should remain idempotent"
	)
	arena.configure_units(units)
	_expect(
		arena.get_committed_action_history_snapshot().is_empty(),
		"configuration should start with empty authoritative history"
	)
	_expect(
		arena.get_skill_presentation_snapshot()["combo_ready_target_ids"].is_empty(),
		"configuration should start with neutral combo presentation"
	)
	arena.configure_units(units)
	_expect(
		arena.get_committed_action_history_snapshot().is_empty(),
		"repeated configuration cleanup should remain idempotent"
	)
	arena.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
