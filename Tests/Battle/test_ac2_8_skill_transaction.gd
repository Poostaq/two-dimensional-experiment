class_name Ac2_8SkillTransactionTests
extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	_test_free_targeting_and_confirmation_gate()
	_test_predefined_lock_and_supersession()
	_test_cancel_and_stale_rejection()
	_test_presentation_snapshot_and_hover_supersession()
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


func _test_presentation_snapshot_and_hover_supersession() -> void:
	var transaction := BattleSkillTransaction.new()
	var evaluation := SkillTargetEvaluation.new(
		&"player_0", &"shield_bash", CharacterSkill.TargetingMode.FREE,
		true, SkillActionReason.none(), [&"enemy_0"], {
			&"enemy_1": SkillActionReason.new(
				SkillActionReason.Code.TARGET_DEFEATED,
				"Target was defeated. Select another target."
			)
		}, [], 41
	)
	var generation: int = transaction.preview(evaluation)
	var preview_snapshot: Dictionary = transaction.presentation_snapshot()
	_expect(preview_snapshot["state"] == BattleSkillTransaction.State.PREVIEWING, "Snapshot should expose PREVIEWING.")
	_expect(not preview_snapshot["action_region_visible"], "Hover preview should not expose action controls.")
	_expect(preview_snapshot["indicator_roles"][&"enemy_0"] == &"valid_preview", "Valid preview role should be green+tint.")
	_expect(preview_snapshot["indicator_roles"][&"enemy_1"] == &"invalid_preview", "Invalid preview role should be red+tint.")
	transaction.begin_targeting(generation)
	var targeting_snapshot: Dictionary = transaction.presentation_snapshot()
	_expect(targeting_snapshot["action_region_visible"], "Targeting should reveal contextual controls.")
	_expect(targeting_snapshot["message"] == "Select a target for Shield Bash", "Targeting message should name the skill.")
	_expect(targeting_snapshot["cancel_visible"], "Cancel should be visible while targeting.")
	_expect(not targeting_snapshot["confirm_visible"], "Confirm should remain hidden before a free target lock.")
	_expect(transaction.hover_target(&"enemy_1", generation), "Current invalid hover should be accepted.")
	var invalid_snapshot: Dictionary = transaction.presentation_snapshot()
	_expect(invalid_snapshot["indicator_roles"][&"enemy_1"] == &"invalid_hover", "Invalid targeting hover should be red+tint.")
	_expect(transaction.hover_target(&"enemy_0", generation), "Newest valid hover should replace the prior hover.")
	var valid_snapshot: Dictionary = transaction.presentation_snapshot()
	_expect(not valid_snapshot["indicator_roles"].has(&"enemy_1"), "Last hover event should clear the old hover role.")
	_expect(valid_snapshot["indicator_roles"][&"enemy_0"] == &"valid_hover", "Valid targeting hover should be green border.")
	transaction.select_target(&"enemy_0", generation)
	var locked_snapshot: Dictionary = transaction.presentation_snapshot()
	_expect(locked_snapshot["indicator_roles"][&"enemy_0"] == &"locked", "Locked target should be green+tint.")
	_expect(locked_snapshot["confirm_visible"], "Confirm should appear after a target locks.")
	_expect(locked_snapshot["confirm_enabled"], "Confirm should be enabled after a target locks.")
	_expect(not transaction.hover_target(&"enemy_1", generation - 1), "Stale hover callback should be ignored.")
	var defensive_roles: Dictionary = locked_snapshot["indicator_roles"]
	defensive_roles.clear()
	_expect(transaction.presentation_snapshot()["indicator_roles"].has(&"enemy_0"), "Snapshot indicator roles must be defensive.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
