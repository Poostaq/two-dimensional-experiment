class_name Ac2_8SkillArenaTests
extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	await process_frame
	_test_confirmed_damage_resolves_once(arena)
	await _test_real_ui_signal_wiring(arena)
	_test_speed_action_ticks_prior_cooldown(arena)
	_test_stale_target_rejects_without_mutation(arena)
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("AC2.8 skill arena tests: PASS")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("AC2.8 skill arena tests: FAIL (%d)" % failures.size())
		quit(1)


func _test_confirmed_damage_resolves_once(arena: BattleArena) -> void:
	var shield_bash := CharacterSkill.new(
		&"shield_bash", "Shield Bash", CharacterSkill.Kind.ACTIVE,
		"Deal 7 damage.", "One selected active enemy.",
		"User must occupy a front-row slot.", "1 turn after use.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.FRONT_ROW,
		CharacterSkill.Effect.DAMAGE,
		7,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		1,
		0
	)
	var skills: Array[CharacterSkill] = [shield_bash]
	var actor := BattleUnitState.new(
		&"player_actor", "Player Actor", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
	)
	var enemy := BattleUnitState.new(
		&"enemy_target", "Enemy Target", BattleUnitState.Side.ENEMY, 0, 5
	)
	var units: Array[BattleUnitState] = [actor, enemy]
	arena.configure_units(units)
	_expect(arena.get_battle_revision() == 0, "New fixture should start at revision zero.")
	_expect(arena.begin_skill_action(&"player_actor", &"shield_bash"), "Current player active skill should start.")
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.TARGETING, "Free skill should enter TARGETING.")
	_expect(arena.select_skill_target(&"enemy_target"), "Valid enemy should lock.")
	_expect(arena.confirm_skill_action(), "Confirmed skill should resolve.")
	_expect(enemy.current_hp == 13, "Shield Bash should apply exactly 7 damage.")
	_expect(actor.get_skill_cooldown(&"shield_bash") == 1, "Shield Bash should apply one-action cooldown.")
	_expect(arena.get_battle_revision() == 1, "Atomic committed action should increment revision once.")
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.IDLE, "Resolved action should return to IDLE.")
	_expect(not arena.confirm_skill_action(), "Repeated Confirm must not resolve again.")
	_expect(enemy.current_hp == 13, "Repeated Confirm must not duplicate damage.")
	_expect(arena.get_battle_revision() == 1, "Repeated Confirm must not increment revision.")


func _test_real_ui_signal_wiring(arena: BattleArena) -> void:
	var quick_strike := CharacterSkill.new(
		&"quick_strike", "Quick Strike", CharacterSkill.Kind.ACTIVE,
		"Deal 5 damage.", "One selected active enemy.", "None", "None",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		5
	)
	var skills: Array[CharacterSkill] = [quick_strike]
	var actor := BattleUnitState.new(
		&"player_ui", "Player UI", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
	)
	var enemy := BattleUnitState.new(
		&"enemy_ui", "Enemy UI", BattleUnitState.Side.ENEMY, 0, 5
	)
	var units: Array[BattleUnitState] = [actor, enemy]
	arena.configure_units(units)
	arena.inspect_unit(&"player_ui")
	await process_frame
	var skill_buttons: Array[Node] = arena.find_children("", "Button", true, false)
	var skill_button: Button
	for candidate: Button in skill_buttons:
		if candidate.get_meta("skill_id", &"") == &"quick_strike":
			skill_button = candidate
			break
	_expect(is_instance_valid(skill_button), "Inspected active skill should render a button.")
	if not is_instance_valid(skill_button):
		return
	skill_button.mouse_entered.emit()
	var enemy_slot: Control = arena.get_enemy_slots().filter(
		func(slot: Control) -> bool: return slot.get_meta("unit_id", &"") == &"enemy_ui"
	)[0]
	var overlay := enemy_slot.get_node("TargetIndicatorOverlay") as Panel
	_expect(overlay.visible, "Skill hover should preview valid target overlay.")
	_expect(not arena.get_node("%SkillActionRegion").visible, "Hover should not reveal action controls.")
	skill_button.pressed.emit()
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.TARGETING, "Skill button press should enter TARGETING.")
	_expect(arena.get_node("%SkillActionRegion").visible, "Targeting should reveal action controls.")
	enemy_slot.mouse_entered.emit()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	enemy_slot.gui_input.emit(click)
	var confirm := arena.get_node("%SkillConfirmButton") as Button
	_expect(confirm.visible and not confirm.disabled, "Target lock should reveal enabled Confirm.")
	confirm.pressed.emit()
	_expect(enemy.current_hp == 15, "Confirm button should execute the selected skill once.")


func _test_speed_action_ticks_prior_cooldown(arena: BattleArena) -> void:
	var quick_step := CharacterSkill.new(
		&"quick_step", "Quick Step", CharacterSkill.Kind.ACTIVE,
		"Gain 2 Speed.", "Self.", "None", "2 turns after use.",
		CharacterSkill.TargetingMode.PREDEFINED,
		CharacterSkill.TargetSide.SELF,
		CharacterSkill.TargetRule.SELF,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.SPEED_BOOST,
		2,
		1,
		CharacterSkill.EffectDuration.NEXT_ACTION,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		2
	)
	var quick_strike := CharacterSkill.new(
		&"quick_strike", "Quick Strike", CharacterSkill.Kind.ACTIVE,
		"Deal 5 damage.", "One selected active enemy.", "None", "None",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		5
	)
	var skills: Array[CharacterSkill] = [quick_step, quick_strike]
	var actor := BattleUnitState.new(
		&"player_speed", "Player Speed", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
	)
	var enemy := BattleUnitState.new(
		&"enemy_speed", "Enemy Speed", BattleUnitState.Side.ENEMY, 0, 5
	)
	actor.set_skill_cooldown(&"quick_strike", 1)
	actor.add_speed_modifier(&"old_boost", 3, BattleUnitState.ModifierExpiry.NEXT_ACTION, 1)
	var units: Array[BattleUnitState] = [actor, enemy]
	arena.configure_units(units)
	_expect(arena.begin_skill_action(&"player_speed", &"quick_step"), "Quick Step should start with predefined self lock.")
	_expect(arena.confirm_skill_action(), "Quick Step should resolve.")
	_expect(actor.get_effective_speed() == 12, "New next-action Speed modifier must survive its casting action.")
	_expect(actor.get_skill_cooldown(&"quick_step") == 2, "New cooldown must not tick on its casting action.")
	_expect(actor.get_skill_cooldown(&"quick_strike") == 0, "Prior cooldown should tick after the actor acts.")


func _test_stale_target_rejects_without_mutation(arena: BattleArena) -> void:
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
	var actor := BattleUnitState.new(
		&"player_stale", "Player Stale", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
	)
	var enemy := BattleUnitState.new(
		&"enemy_stale", "Enemy Stale", BattleUnitState.Side.ENEMY, 0, 5
	)
	var units: Array[BattleUnitState] = [actor, enemy]
	arena.configure_units(units)
	arena.begin_skill_action(&"player_stale", &"shield_bash")
	arena.select_skill_target(&"enemy_stale")
	enemy.current_hp = 0
	_expect(not arena.confirm_skill_action(), "Defeated locked target should reject confirmation.")
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.REJECTED_STALE, "Stale target should enter REJECTED_STALE.")
	_expect(actor.get_skill_cooldown(&"shield_bash") == 0, "Rejected stale action must not apply cooldown.")
	_expect(arena.get_battle_revision() == 0, "Rejected stale action must not commit a revision.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
