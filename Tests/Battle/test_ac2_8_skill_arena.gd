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
	_test_rally_expires_at_round_end(arena)
	_test_savage_blow_hp_boundary(arena)
	_test_shadow_lunge_round_gate_and_farthest_lock(arena)
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
	_expect(arena.get_battle_action_log_entries().size() == 1, "Confirmed damage skill should create one logical action log.")
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
	var action_logs: Array = arena.get_battle_action_log_entries()
	_expect(action_logs.size() == 1, "Speed skill should create one logical action log.")
	if action_logs.size() == 1:
		_expect(action_logs[0].skill_id == &"quick_step", "Speed action log should identify Quick Step.")
		_expect(action_logs[0].target_ids == [&"player_speed"], "Speed action log should preserve locked targets.")


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
	var initial_battle_log_count: int = arena.get_battle_log_entries().size()
	var initial_action_log_count: int = arena.get_battle_action_log_entries().size()
	var initial_current_unit_id: StringName = arena.get_current_unit().unit_id
	var initial_actor_speed: int = actor.get_effective_speed()
	enemy.current_hp = 0
	arena.notify_authoritative_battle_change()
	_expect(arena.get_battle_revision() == 1, "Authoritative target defeat should increment revision once.")
	_expect(not arena.confirm_skill_action(), "Defeated locked target should reject confirmation.")
	_expect(arena.get_skill_transaction_state() == BattleSkillTransaction.State.REJECTED_STALE, "Stale target should enter REJECTED_STALE.")
	_expect(actor.get_skill_cooldown(&"shield_bash") == 0, "Rejected stale action must not apply cooldown.")
	_expect(actor.get_effective_speed() == initial_actor_speed, "Rejected stale action must not apply Speed modifiers.")
	_expect(arena.get_battle_log_entries().size() == initial_battle_log_count, "Rejected stale action must not append damage logs.")
	_expect(arena.get_battle_action_log_entries().size() == initial_action_log_count, "Rejected stale action must not append action logs.")
	_expect(arena.get_current_unit().unit_id == initial_current_unit_id, "Rejected stale action must not advance the turn.")
	_expect(arena.get_battle_revision() == 1, "Rejected stale action must not commit an additional revision.")


func _test_rally_expires_at_round_end(arena: BattleArena) -> void:
	var rally := CharacterSkill.new(
		&"rally", "Rally", CharacterSkill.Kind.ACTIVE,
		"Grant allies 2 Speed.", "All active allies.", "None", "2 turns.",
		CharacterSkill.TargetingMode.PREDEFINED,
		CharacterSkill.TargetSide.ALLY,
		CharacterSkill.TargetRule.ALL_ACTIVE_ALLIES,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.SPEED_BOOST,
		2,
		1,
		CharacterSkill.EffectDuration.CURRENT_ROUND,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		2
	)
	var skills: Array[CharacterSkill] = [rally]
	var actor := BattleUnitState.new(
		&"player_rally", "Player Rally", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
	)
	var ally := BattleUnitState.new(
		&"player_ally", "Player Ally", BattleUnitState.Side.PLAYER, 1, 5
	)
	var enemy := BattleUnitState.new(
		&"enemy_rally", "Enemy Rally", BattleUnitState.Side.ENEMY, 0, 1
	)
	var units: Array[BattleUnitState] = [actor, ally, enemy]
	arena.configure_units(units)
	_expect(arena.begin_skill_action(&"player_rally", &"rally"), "Rally should start with predefined ally locks.")
	_expect(arena.confirm_skill_action(), "Rally should resolve.")
	_expect(actor.get_effective_speed() == 12, "Rally should affect its user.")
	_expect(ally.get_effective_speed() == 7, "Rally should affect every active ally.")
	while arena.round_number == 1:
		arena.advance_turn()
	_expect(actor.get_effective_speed() == 10, "Rally should expire from its user at round end.")
	_expect(ally.get_effective_speed() == 5, "Rally should expire from allies at round end.")
	_expect(arena.get_battle_revision() > 1, "Authoritative turn advancement should increment revision.")


func _test_savage_blow_hp_boundary(arena: BattleArena) -> void:
	var savage_blow := CharacterSkill.new(
		&"savage_blow", "Savage Blow", CharacterSkill.Kind.ACTIVE,
		"Deal 12 damage.", "One selected active enemy.", "Above 50% HP.", "2 turns.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.ABOVE_HALF_HP,
		CharacterSkill.Effect.DAMAGE,
		12,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		2
	)
	var skills: Array[CharacterSkill] = [savage_blow]
	var actor := BattleUnitState.new(
		&"player_savage", "Player Savage", BattleUnitState.Side.PLAYER, 0, 10, 20, skills
	)
	var enemy := BattleUnitState.new(
		&"enemy_savage", "Enemy Savage", BattleUnitState.Side.ENEMY, 0, 5
	)
	var units: Array[BattleUnitState] = [actor, enemy]
	actor.current_hp = 10
	arena.configure_units(units)
	_expect(not arena.begin_skill_action(&"player_savage", &"savage_blow"), "Savage Blow must reject exactly 50% HP.")
	actor.current_hp = 11
	arena.configure_units(units)
	_expect(arena.begin_skill_action(&"player_savage", &"savage_blow"), "Savage Blow should accept above 50% HP.")
	arena.select_skill_target(&"enemy_savage")
	_expect(arena.confirm_skill_action(), "Savage Blow should resolve above 50% HP.")
	_expect(enemy.current_hp == 8, "Savage Blow should deal exactly 12 damage.")
	_expect(actor.get_skill_cooldown(&"savage_blow") == 2, "Savage Blow should apply cooldown 2.")


func _test_shadow_lunge_round_gate_and_farthest_lock(arena: BattleArena) -> void:
	var shadow_lunge := CharacterSkill.new(
		&"shadow_lunge", "Shadow Lunge", CharacterSkill.Kind.ACTIVE,
		"Deal 10 damage.", "Farthest active enemy.", "Back row.", "Round 1 gate.",
		CharacterSkill.TargetingMode.PREDEFINED,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.FARTHEST_ACTIVE_ENEMY,
		CharacterSkill.Requirement.BACK_ROW,
		CharacterSkill.Effect.DAMAGE,
		10,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.ROUND_GATE,
		0,
		1
	)
	var skills: Array[CharacterSkill] = [shadow_lunge]
	var actor := BattleUnitState.new(
		&"player_shadow", "Player Shadow", BattleUnitState.Side.PLAYER, 4, 10, 20, skills
	)
	var enemy_front := BattleUnitState.new(
		&"enemy_shadow_front", "Enemy Front", BattleUnitState.Side.ENEMY, 0, 5
	)
	var enemy_back := BattleUnitState.new(
		&"enemy_shadow_back", "Enemy Back", BattleUnitState.Side.ENEMY, 5, 1
	)
	var units: Array[BattleUnitState] = [actor, enemy_front, enemy_back]
	arena.configure_units(units)
	_expect(not arena.begin_skill_action(&"player_shadow", &"shadow_lunge"), "Shadow Lunge must reject round 1.")
	while arena.round_number == 1:
		arena.advance_turn()
	_expect(arena.begin_skill_action(&"player_shadow", &"shadow_lunge"), "Shadow Lunge should unlock in round 2.")
	_expect(arena.confirm_skill_action(), "Shadow Lunge predefined lock should confirm.")
	_expect(enemy_front.current_hp == 20, "Shadow Lunge should leave nearer enemy unchanged.")
	_expect(enemy_back.current_hp == 10, "Shadow Lunge should hit deterministic farthest enemy for 10.")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
