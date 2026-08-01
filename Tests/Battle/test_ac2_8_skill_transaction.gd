class_name Ac2_8SkillTransactionTests
extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	_test_free_targeting_and_confirmation_gate()
	_test_predefined_lock_and_supersession()
	_test_cancel_and_stale_rejection()
	if failures.is_empty():
		print("AC2.8 skill transaction tests: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("AC2.8 skill transaction tests: FAIL (%d)" % failures.size())
		quit(1)


func _test_free_targeting_and_confirmation_gate() -> void:
	var transaction := BattleSkillTransaction.new()
	var evaluation := SkillTargetEvaluation.new(
		&"player_0",
		&"shield_bash",
		CharacterSkill.TargetingMode.FREE,
		true,
		SkillActionReason.none(),
		[&"enemy_0"],
		{&"enemy_1": SkillActionReason.new(
			SkillActionReason.Code.TARGET_DEFEATED,
			"Target was defeated. Select another target."
		)},
		[],
		12
	)
	var generation: int = transaction.preview(evaluation)
	_expect(transaction.state == BattleSkillTransaction.State.PREVIEWING, "Hover should enter PREVIEWING.")
	_expect(transaction.begin_targeting(generation), "Current skill preview should enter targeting.")
	_expect(transaction.state == BattleSkillTransaction.State.TARGETING, "Click should enter TARGETING.")
	_expect(transaction.locked_target_ids.is_empty(), "Free skill should not lock a target on skill click.")
	_expect(not transaction.select_target(&"enemy_1", generation), "Invalid target must not lock.")
	_expect(transaction.last_reason.code == SkillActionReason.Code.TARGET_DEFEATED, "Invalid target should retain its reason.")
	_expect(transaction.select_target(&"enemy_0", generation), "Valid free target should lock.")
	_expect(transaction.locked_target_ids == [&"enemy_0"], "Free target lock should contain the selected unit.")
	_expect(transaction.begin_confirmation(generation), "First confirmation should enter VALIDATING.")
	_expect(transaction.state == BattleSkillTransaction.State.VALIDATING, "Confirmation should enter VALIDATING.")
	_expect(not transaction.begin_confirmation(generation), "Repeated confirmation must be de-duplicated.")


func _test_predefined_lock_and_supersession() -> void:
	var transaction := BattleSkillTransaction.new()
	var first := SkillTargetEvaluation.new(
		&"player_2", &"quick_step", CharacterSkill.TargetingMode.PREDEFINED,
		true, SkillActionReason.none(), [], {}, [&"player_2"], 20
	)
	var first_generation: int = transaction.preview(first)
	_expect(transaction.begin_targeting(first_generation), "Predefined skill should enter targeting.")
	_expect(transaction.locked_target_ids == [&"player_2"], "Predefined targets should lock on skill click.")
	var second := SkillTargetEvaluation.new(
		&"player_4", &"rally", CharacterSkill.TargetingMode.PREDEFINED,
		true, SkillActionReason.none(), [], {}, [&"player_0", &"player_4"], 20
	)
	var second_generation: int = transaction.preview(second)
	_expect(second_generation > first_generation, "New skill should supersede the previous generation.")
	_expect(not transaction.begin_targeting(first_generation), "Superseded callbacks must be ignored.")
	_expect(transaction.skill_id == &"rally", "Newest skill must own the transaction.")
	_expect(transaction.begin_targeting(second_generation), "Newest callback should be accepted.")
	_expect(transaction.locked_target_ids == [&"player_0", &"player_4"], "Newest predefined targets should lock.")


func _test_cancel_and_stale_rejection() -> void:
	var transaction := BattleSkillTransaction.new()
	var evaluation := SkillTargetEvaluation.new(
		&"player_0", &"shield_bash", CharacterSkill.TargetingMode.FREE,
		true, SkillActionReason.none(), [&"enemy_0"], {}, [], 30
	)
	var generation: int = transaction.preview(evaluation)
	transaction.begin_targeting(generation)
	transaction.select_target(&"enemy_0", generation)
	transaction.cancel(generation)
	_expect(transaction.state == BattleSkillTransaction.State.CANCELLED, "Cancel should enter CANCELLED.")
	_expect(transaction.locked_target_ids.is_empty(), "Cancel should clear target locks.")
	generation = transaction.preview(evaluation)
	transaction.begin_targeting(generation)
	transaction.select_target(&"enemy_0", generation)
	transaction.begin_confirmation(generation)
	var rejection := SkillConfirmationValidation.new(
		false,
		SkillActionReason.new(
			SkillActionReason.Code.REVISION_MISMATCH,
			"Battle state changed. Review this skill again."
		),
		&"player_0",
		&"shield_bash",
		[&"enemy_0"],
		31,
		null
	)
	_expect(transaction.complete_confirmation(rejection, generation), "Current validation callback should be accepted.")
	_expect(transaction.state == BattleSkillTransaction.State.REJECTED_STALE, "Stale validation should enter REJECTED_STALE.")
	_expect(transaction.locked_target_ids.is_empty(), "Stale rejection should clear locks immediately.")
	_expect(not transaction.complete_confirmation(rejection, generation), "Completed validation callback must not re-enter.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
