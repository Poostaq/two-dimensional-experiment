class_name Ac2_8SkillLifecycleTests
extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	_test_target_removal_and_ownership_change(arena)
	_test_turn_and_cooldown_invalidation(arena)
	await _test_reconfiguration_and_exit_cleanup(arena)
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("AC2.8 skill lifecycle tests: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("AC2.8 skill lifecycle tests: FAIL (%d)" % failures.size())
		quit(1)


func _test_target_removal_and_ownership_change(arena: BattleArena) -> void:
	var units: Array[BattleUnitState] = _fixture_units()
	arena.configure_units(units)
	arena.begin_skill_action(&"player_actor", &"shield_bash")
	arena.select_skill_target(&"enemy_target")
	_expect(arena.remove_battle_unit(&"enemy_target"), "Active target removal should succeed.")
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.REJECTED_STALE, "Removed lock should reject immediately.")
	_expect(
		arena.get_skill_presentation_snapshot()["message"] == "Target is no longer in battle. Select another target.",
		"Removal should show the exact stale message."
	)
	units = _fixture_units()
	arena.configure_units(units)
	arena.begin_skill_action(&"player_actor", &"shield_bash")
	arena.select_skill_target(&"enemy_target")
	var target: BattleUnitState = arena.get_unit_by_id(&"enemy_target")
	target.side = 0
	arena.notify_authoritative_battle_change()
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.REJECTED_STALE, "Ownership change should reject immediately.")
	_expect(
		arena.get_skill_presentation_snapshot()["message"] == "Target changed sides and is no longer valid.",
		"Ownership change should show the exact stale message."
	)


func _test_turn_and_cooldown_invalidation(arena: BattleArena) -> void:
	var units: Array[BattleUnitState] = _fixture_units()
	arena.configure_units(units)
	arena.begin_skill_action(&"player_actor", &"shield_bash")
	arena.select_skill_target(&"enemy_target")
	arena.advance_turn()
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.REJECTED_STALE, "Current-actor change should reject immediately.")
	_expect(
		arena.get_skill_presentation_snapshot()["message"] == "Only the current player unit can act.",
		"Current-actor change should show the exact message."
	)
	units = _fixture_units()
	arena.configure_units(units)
	arena.begin_skill_action(&"player_actor", &"shield_bash")
	arena.select_skill_target(&"enemy_target")
	var actor: BattleUnitState = arena.get_unit_by_id(&"player_actor")
	actor.set_skill_cooldown(&"shield_bash", 2)
	arena.notify_authoritative_battle_change()
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.REJECTED_STALE, "Cooldown change should reject immediately.")
	_expect(
		arena.get_skill_presentation_snapshot()["message"] == "Ready in 2 actions.",
		"Cooldown change should show the exact availability message."
	)


func _test_reconfiguration_and_exit_cleanup(arena: BattleArena) -> void:
	var units: Array[BattleUnitState] = _fixture_units()
	arena.configure_units(units)
	arena.begin_skill_action(&"player_actor", &"shield_bash")
	arena.select_skill_target(&"enemy_target")
	arena.configure_units(_fixture_units())
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.IDLE, "Reconfiguration should reset the transaction.")
	_expect(not arena.get_node("%SkillActionRegion").visible, "Reconfiguration should hide contextual controls.")
	arena.begin_skill_action(&"player_actor", &"shield_bash")
	arena.get_node("%ExitBattleDebugButton").pressed.emit()
	await process_frame
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.IDLE, "Exit should reset the transaction.")
	_expect(not arena.get_node("%SkillActionRegion").visible, "Exit should hide contextual controls.")


func _fixture_units() -> Array[BattleUnitState]:
	var shield_bash := CharacterSkill.new(
		&"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE,
		"Deal 7 damage.", "One selected active enemy.", "Front row.", "1 turn.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.FRONT_ROW,
		CharacterSkill.Effect.DAMAGE,
		7,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		1
	)
	var skills: Array[CharacterSkill] = [shield_bash]
	return [
		BattleUnitState.new(
			&"player_actor", "Player Actor", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
		),
		BattleUnitState.new(
			&"enemy_target", "Enemy Target", BattleUnitState.Side.ENEMY, 0, 5
		),
		BattleUnitState.new(
			&"enemy_control", "Enemy Control", BattleUnitState.Side.ENEMY, 1, 4
		),
	]


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
