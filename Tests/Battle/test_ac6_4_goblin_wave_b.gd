class_name Ac6_4GoblinWaveBTests
extends SceneTree

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var goblin := RunCharacter.new(
		&"scrapbroker",
		"Scrapbroker",
		8,
		18,
		[],
		3,
		1,
		&"goblin"
	)
	var roster := RunRoster.new([goblin])
	var battle_units := roster.create_battle_units()
	_expect(goblin.race_id == &"goblin", "run character stores stable race identity")
	_expect(battle_units[0].race_id == &"goblin", "battle conversion preserves race identity")
	_expect(battle_units[0].unit_id == goblin.character_id, "race propagation preserves identity")
	var legacy := RunCharacter.new(&"legacy", "Legacy", 1, 10, [])
	_expect(legacy.race_id == &"unknown", "legacy constructors default race identity")
	_test_wave_b_condition_contracts()
	_test_wave_b_history_queries()
	_test_wave_b_effect_contracts()
	_test_ordered_target_profile_contract()
	_test_wave_b_catalog_contracts()
	_test_wave_b_resolver_contracts()
	_test_mixed_side_confirmation_contract()
	_test_wave_b_rejections()
	await _test_wave_b_arena_resolution()
	if _failures.is_empty():
		print("AC6.4 Goblin wave B: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_wave_b_condition_contracts() -> void:
	var kinds: Array[int] = [
		BattleSkillCondition.Kind.PRIMARY_BLEEDING,
		BattleSkillCondition.Kind.PRIMARY_BELOW_HALF_HP,
		BattleSkillCondition.Kind.PRIMARY_HIT_BY_ALLY_THIS_ROUND,
		BattleSkillCondition.Kind.PRIMARY_CONSUMED_ADVANTAGE_THIS_ROUND,
		BattleSkillCondition.Kind.ALLY_ACTED_BEFORE_ACTOR_THIS_ROUND,
		BattleSkillCondition.Kind.PRIMARY_DIFFERENT_RACE_FROM_ACTOR,
	]
	for kind: int in kinds:
		var condition := BattleSkillCondition.create(kind)
		_expect(is_instance_valid(condition), "Wave B condition is constructible: %d" % kind)
		_expect(condition.duplicate_condition().kind == kind, "Wave B condition duplicates: %d" % kind)


func _test_wave_b_history_queries() -> void:
	var source := BattleKeywordSource.create(&"setter", &"spot_buyer", 3)
	var records: Array[BattleActionRecord] = [
		BattleActionRecord.new(
			BattleActionRecord.Kind.SKILL, &"ally_a", [&"enemy"], {&"enemy": 2},
			{}, {}, 1, 1, 1, BattleUnitState.Side.PLAYER, &"attack", true,
			{&"enemy": true}
		),
		BattleActionRecord.new(
			BattleActionRecord.Kind.SKILL, &"ally_b", [&"enemy"], {&"enemy": 3},
			{}, {}, 1, 2, 2, BattleUnitState.Side.PLAYER, &"finish", true,
			{&"enemy": true}, [], source
		),
	]
	_expect(
		BattleHistoryQuery.consumed_advantage_this_round(records, &"ally_b", 1),
		"history finds the selected ally's Advantage consumption"
	)
	_expect(
		BattleHistoryQuery.ally_acted_before_this_round(
			records, BattleUnitState.Side.PLAYER, &"shivrunner", 1
		),
		"history finds an earlier allied committed action"
	)
	_expect(
		BattleHistoryQuery.was_directly_hit_by_ally_this_round(
			records, BattleUnitState.Side.PLAYER, &"enemy", &"mobcaller", 1
		),
		"history finds an earlier allied direct hit"
	)
	_expect(
		BattleHistoryQuery.distinct_allied_attackers_this_round(
			records, BattleUnitState.Side.PLAYER, &"enemy", &"mobcaller", 1
		) == [&"ally_a", &"ally_b"],
		"history returns stable distinct prior allied attackers"
	)


func _test_wave_b_effect_contracts() -> void:
	var scaled := BattleSkillEffectDefinition.history_scaled_damage(
		BattleSkillEffectDefinition.TargetRole.PRIMARY, 90, 20, 150
	)
	_expect(is_instance_valid(scaled), "history-scaled damage definition is valid")
	_expect(scaled.history_increment == 20, "history-scaled damage stores increment")
	_expect(scaled.maximum_power_percent == 150, "history-scaled damage stores cap")
	var armor := BattleSkillEffectDefinition.conditional_armor(
		BattleSkillEffectDefinition.TargetRole.PRIMARY, 4, 5
	)
	_expect(is_instance_valid(armor), "conditional Armor definition is valid")
	_expect(armor.magnitude == 4, "conditional Armor stores base amount")
	_expect(armor.conditional_magnitude == 5, "conditional Armor stores upgraded amount")


func _test_ordered_target_profile_contract() -> void:
	var profile := BattleSkillTargetProfile.create(
		2, 2, BattleUnitState.Side.PLAYER, false, false,
		[BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY]
	)
	_expect(is_instance_valid(profile), "mixed-side target profile is valid")
	_expect(
		profile.target_sides == [BattleUnitState.Side.PLAYER, BattleUnitState.Side.ENEMY],
		"mixed-side target profile preserves selection order"
	)
	_expect(
		profile.duplicate_profile().target_sides == profile.target_sides,
		"mixed-side selection contract duplicates defensively"
	)


func _test_wave_b_catalog_contracts() -> void:
	var expected: Array[Dictionary] = [
		{&"id": &"scrapbroker", &"name": "Scrapbroker", &"hp": 18, &"power": 3, &"speed": 8, &"defense": 1, &"skills": [&"spot_buyer", &"hand_me_down", &"emergency_kit"]},
		{&"id": &"shivrunner", &"name": "Shivrunner", &"hp": 12, &"power": 7, &"speed": 10, &"defense": 0, &"skills": [&"quick_nick", &"dirty_window", &"collect_debt"]},
		{&"id": &"mobcaller", &"name": "Mobcaller", &"hp": 17, &"power": 4, &"speed": 9, &"defense": 1, &"skills": [&"point_and_yell", &"dogpile_math", &"louder_together"]},
	]
	for entry: Dictionary in expected:
		var character := RunCharacterCatalog.create_by_class_id(entry[&"id"])
		_expect(is_instance_valid(character), "Wave B catalog resolves %s" % entry[&"id"])
		if not is_instance_valid(character):
			continue
		_expect(character.display_name == entry[&"name"], "catalog display name is exact")
		_expect(character.max_hp == entry[&"hp"], "catalog HP is exact")
		_expect(character.power == entry[&"power"], "catalog Power is exact")
		_expect(character.base_speed == entry[&"speed"], "catalog Speed is exact")
		_expect(character.defense == entry[&"defense"], "catalog Defense is exact")
		_expect(character.race_id == &"goblin", "catalog race is Goblin")
		var ids: Array[StringName] = []
		for skill: CharacterSkill in character.get_skills():
			ids.append(skill.skill_id)
		_expect(ids == entry[&"skills"], "catalog skill order is exact")


func _test_wave_b_resolver_contracts() -> void:
	var scrapbroker := _battle_unit(&"scrapbroker", BattleUnitState.Side.PLAYER, 0)
	var shivrunner := _battle_unit(&"shivrunner", BattleUnitState.Side.PLAYER, 1)
	var mobcaller := _battle_unit(&"mobcaller", BattleUnitState.Side.PLAYER, 2)
	var ally := BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 3, 6, 20, [], 4, 1, &"harpy")
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5, 30, [], 4, 0, &"orc")
	var units: Array[BattleUnitState] = [scrapbroker, shivrunner, mobcaller, ally, enemy]
	var source := BattleKeywordSource.create(&"setter", &"spot_buyer", 3)
	var records: Array[BattleActionRecord] = [
		BattleActionRecord.new(
			BattleActionRecord.Kind.SKILL, ally.unit_id, [enemy.unit_id],
			{enemy.unit_id: 3}, {}, {}, 1, 1, 1, BattleUnitState.Side.PLAYER,
			&"setup_hit", true, {enemy.unit_id: true}, [], source
		)
	]
	var hand_plan := BattleSkillAuthoringResolver.build_plan(
		scrapbroker, _skill(scrapbroker, &"hand_me_down"), [ally], units, 1, 0, [], [], records
	)
	_expect(is_instance_valid(hand_plan), "Hand-Me-Down resolves from action history")
	_expect(
		is_instance_valid(hand_plan) and hand_plan.keyword_operations[0].magnitude == 5,
		"Hand-Me-Down locks upgraded Armor"
	)
	var dogpile_plan := BattleSkillAuthoringResolver.build_plan(
		mobcaller, _skill(mobcaller, &"dogpile_math"), [enemy], units, 1, 0, [], [], records
	)
	_expect(is_instance_valid(dogpile_plan), "Dogpile Math resolves after an allied hit")
	_expect(
		is_instance_valid(dogpile_plan) and dogpile_plan.damage_operations[0][&"base_damage"] == 5,
		"Dogpile Math locks 110 percent Power"
	)
	var louder_plan := BattleSkillAuthoringResolver.build_plan(
		mobcaller, _skill(mobcaller, &"louder_together"), [ally, enemy], units, 1, 0, [], [], records
	)
	_expect(is_instance_valid(louder_plan), "Louder Together resolves ordered mixed targets")
	_expect(
		is_instance_valid(louder_plan) and louder_plan.speed_operations[0][&"target_id"] == ally.unit_id,
		"Louder Together locks Speed on the different-race ally"
	)
	_expect(
		is_instance_valid(louder_plan) and louder_plan.keyword_operations[0].target_id == enemy.unit_id,
		"Louder Together locks Advantage on the enemy"
	)


func _test_mixed_side_confirmation_contract() -> void:
	var mobcaller := _battle_unit(&"mobcaller", BattleUnitState.Side.PLAYER, 0)
	var ally := BattleUnitState.new(&"harpy", "Harpy", BattleUnitState.Side.PLAYER, 1, 6, 20, [], 4, 0, &"harpy")
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 4, 0, &"orc")
	var units: Array[BattleUnitState] = [mobcaller, ally, enemy]
	var validation := BattleSkillRules.validate_confirmation(
		mobcaller, _skill(mobcaller, &"louder_together"), units, mobcaller.unit_id,
		false, 1, [ally.unit_id, enemy.unit_id], 0, 0, [], [], []
	)
	_expect(validation.accepted, "mixed-side ordered confirmation is accepted")
	var reversed := BattleSkillRules.validate_confirmation(
		mobcaller, _skill(mobcaller, &"louder_together"), units, mobcaller.unit_id,
		false, 1, [enemy.unit_id, ally.unit_id], 0, 0, [], [], []
	)
	_expect(not reversed.accepted, "mixed-side reversed selection is rejected")


func _test_wave_b_rejections() -> void:
	var broker := _battle_unit(&"scrapbroker", BattleUnitState.Side.PLAYER, 0)
	var shiv := _battle_unit(&"shivrunner", BattleUnitState.Side.PLAYER, 0)
	var mob := _battle_unit(&"mobcaller", BattleUnitState.Side.PLAYER, 0)
	var ally := BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 1, 5, 20, [], 4, 0, &"goblin")
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 20)
	ally.current_hp = 10
	var units: Array[BattleUnitState] = [broker, ally, enemy]
	var exact_half := BattleSkillRules.validate_confirmation(
		broker, _skill(broker, &"emergency_kit"), units, broker.unit_id,
		false, 1, [ally.unit_id], 0, 0, [], [], []
	)
	_expect(not exact_half.accepted, "Emergency Kit rejects exactly half HP")
	var dirty_units: Array[BattleUnitState] = [shiv, enemy]
	var no_bleed := BattleSkillRules.validate_confirmation(
		shiv, _skill(shiv, &"dirty_window"), dirty_units, shiv.unit_id,
		false, 1, [enemy.unit_id], 0, 0, [], [], []
	)
	_expect(not no_bleed.accepted, "Dirty Window rejects a non-Bleeding enemy")
	var dog_units: Array[BattleUnitState] = [mob, enemy]
	var no_hit := BattleSkillRules.validate_confirmation(
		mob, _skill(mob, &"dogpile_math"), dog_units, mob.unit_id,
		false, 1, [enemy.unit_id], 0, 0, [], [], []
	)
	_expect(not no_hit.accepted, "Dogpile Math rejects without an earlier allied hit")
	var same_race_units: Array[BattleUnitState] = [mob, ally, enemy]
	var same_race := BattleSkillRules.validate_confirmation(
		mob, _skill(mob, &"louder_together"), same_race_units, mob.unit_id,
		false, 1, [ally.unit_id, enemy.unit_id], 0, 0, [], [], []
	)
	_expect(not same_race.accepted, "Louder Together rejects a same-race ally")
	var first := RunCharacterCatalog.create_by_class_id(&"scrapbroker")
	var second := RunCharacterCatalog.create_by_class_id(&"scrapbroker")
	_expect(first != second and first.get_skills()[0] != second.get_skills()[0], "Wave B catalog returns fresh definitions")


func _test_wave_b_arena_resolution() -> void:
	var spot_actor := _battle_unit(&"scrapbroker", BattleUnitState.Side.PLAYER, 0)
	var spot_enemy := BattleUnitState.new(&"spot_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 20)
	var spot_arena := await _instantiate_arena()
	spot_arena.configure_units([spot_actor, spot_enemy])
	_expect(spot_arena.begin_skill_action(spot_actor.unit_id, &"spot_buyer"), "Spot Buyer preview opens")
	_expect(spot_arena.select_skill_target(spot_enemy.unit_id), "Spot Buyer target locks")
	_expect(spot_arena.confirm_skill_action(), "Spot Buyer commits")
	_expect(spot_enemy.has_advantage(1), "Spot Buyer applies Advantage")
	spot_arena.queue_free()
	await process_frame

	var nick_actor := _battle_unit(&"shivrunner", BattleUnitState.Side.PLAYER, 0)
	var nick_enemy := BattleUnitState.new(&"nick_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 30)
	var nick_arena := await _instantiate_arena()
	nick_arena.configure_units([nick_actor, nick_enemy])
	var nick_hp: int = nick_enemy.current_hp
	nick_arena.begin_skill_action(nick_actor.unit_id, &"quick_nick")
	nick_arena.select_skill_target(nick_enemy.unit_id)
	_expect(nick_arena.confirm_skill_action(), "Quick Nick commits")
	_expect(nick_enemy.current_hp < nick_hp, "Quick Nick deals damage")
	_expect(not nick_enemy.get_bleed_snapshot().is_empty(), "Quick Nick applies canonical Bleed")
	nick_arena.queue_free()
	await process_frame

	var kit_actor := _battle_unit(&"scrapbroker", BattleUnitState.Side.PLAYER, 0)
	var kit_ally := BattleUnitState.new(&"kit_ally", "Ally", BattleUnitState.Side.PLAYER, 1, 1, 20)
	kit_ally.current_hp = 9
	var kit_enemy := BattleUnitState.new(&"kit_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 20)
	var kit_arena := await _instantiate_arena()
	kit_arena.configure_units([kit_actor, kit_ally, kit_enemy])
	kit_arena.begin_skill_action(kit_actor.unit_id, &"emergency_kit")
	kit_arena.select_skill_target(kit_ally.unit_id)
	_expect(kit_arena.confirm_skill_action(), "Emergency Kit commits below half HP")
	_expect(kit_ally.get_armor() == 6, "Emergency Kit grants 6 Armor")
	kit_arena.queue_free()
	await process_frame


	var setter_character := RunCharacterCatalog.create_by_class_id(&"mobcaller")
	var consumer_character := RunCharacterCatalog.create_by_class_id(&"wirefang_skirmisher")
	var broker_character := RunCharacterCatalog.create_by_class_id(&"scrapbroker")
	var setter := BattleUnitState.new(&"setter", "Setter", BattleUnitState.Side.PLAYER, 0, 9, 20, setter_character.get_skills(), 4, 0, &"goblin")
	var consumer := BattleUnitState.new(&"consumer", "Consumer", BattleUnitState.Side.PLAYER, 1, 8, 20, consumer_character.get_skills(), 6, 0, &"goblin")
	var broker := BattleUnitState.new(&"broker", "Broker", BattleUnitState.Side.PLAYER, 2, 7, 20, broker_character.get_skills(), 3, 1, &"goblin")
	var history_enemy := BattleUnitState.new(&"history_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 40)
	var history_arena := await _instantiate_arena()
	history_arena.configure_units([setter, consumer, broker, history_enemy])
	history_arena.begin_skill_action(setter.unit_id, &"point_and_yell")
	history_arena.select_skill_target(history_enemy.unit_id)
	_expect(history_arena.confirm_skill_action(), "Point and Yell seeds Advantage history")
	history_arena.begin_skill_action(consumer.unit_id, &"cheap_finish")
	history_arena.select_skill_target(history_enemy.unit_id)
	_expect(history_arena.confirm_skill_action(), "Cheap Finish consumes Advantage")
	history_arena.begin_skill_action(broker.unit_id, &"hand_me_down")
	history_arena.select_skill_target(consumer.unit_id)
	_expect(history_arena.confirm_skill_action(), "Hand-Me-Down commits after consumption")
	_expect(consumer.get_armor() == 5, "arena forwards action records for upgraded Armor")
	history_arena.queue_free()
	await process_frame


	var dirty_setter_character := RunCharacterCatalog.create_by_class_id(&"mobcaller")
	var dirty_character := RunCharacterCatalog.create_by_class_id(&"shivrunner")
	var dirty_setter := BattleUnitState.new(&"dirty_setter", "Setter", BattleUnitState.Side.PLAYER, 0, 10, 20, dirty_setter_character.get_skills(), 4, 0, &"goblin")
	var dirty_actor := BattleUnitState.new(&"dirty_actor", "Shivrunner", BattleUnitState.Side.PLAYER, 1, 9, 20, dirty_character.get_skills(), 7, 0, &"goblin")
	var dirty_enemy := BattleUnitState.new(&"dirty_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 40)
	dirty_enemy.apply_bleed(BattleKeywordSource.create(dirty_actor.unit_id, &"quick_nick", dirty_actor.power), 6)
	var dirty_arena := await _instantiate_arena()
	dirty_arena.configure_units([dirty_setter, dirty_actor, dirty_enemy])
	dirty_arena.begin_skill_action(dirty_setter.unit_id, &"point_and_yell")
	dirty_arena.select_skill_target(dirty_enemy.unit_id)
	dirty_arena.confirm_skill_action()
	var dirty_hp: int = dirty_enemy.current_hp
	dirty_arena.begin_skill_action(dirty_actor.unit_id, &"dirty_window")
	dirty_arena.select_skill_target(dirty_enemy.unit_id)
	_expect(dirty_arena.confirm_skill_action(), "Dirty Window commits against Bleeding target")
	_expect(dirty_hp - dirty_enemy.current_hp == 11, "Dirty Window uses 145 percent after allied action")
	dirty_arena.queue_free()
	await process_frame

	var debt_actor := _battle_unit(&"shivrunner", BattleUnitState.Side.PLAYER, 0)
	var debt_enemy := BattleUnitState.new(&"debt_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 40)
	debt_enemy.current_hp = 19
	debt_enemy.apply_bleed(BattleKeywordSource.create(debt_actor.unit_id, &"quick_nick", debt_actor.power), 4)
	var debt_arena := await _instantiate_arena()
	debt_arena.configure_units([debt_actor, debt_enemy])
	var debt_hp: int = debt_enemy.current_hp
	debt_arena.begin_skill_action(debt_actor.unit_id, &"collect_debt")
	debt_arena.select_skill_target(debt_enemy.unit_id)
	_expect(debt_arena.confirm_skill_action(), "Collect Debt commits below half HP with Bleed")
	var debt_history := debt_arena.get_committed_action_history_snapshot()
	_expect(
		debt_history[0].base_damage_by_target[debt_enemy.unit_id] == 13,
		"Collect Debt records 175 percent direct Power damage"
	)
	_expect(debt_hp - debt_enemy.current_hp == 15, "Collect Debt is followed by the existing Bleed tick")
	_expect(not debt_enemy.get_bleed_snapshot().is_empty(), "Collect Debt does not consume Bleed")
	debt_arena.queue_free()
	await process_frame

	var setup_character := RunCharacterCatalog.create_by_class_id(&"wirefang_skirmisher")
	var dog_character := RunCharacterCatalog.create_by_class_id(&"mobcaller")
	var setup_actor := BattleUnitState.new(&"setup_actor", "Setup", BattleUnitState.Side.PLAYER, 0, 10, 20, setup_character.get_skills(), 6, 0, &"goblin")
	var dog_actor := BattleUnitState.new(&"dog_actor", "Mobcaller", BattleUnitState.Side.PLAYER, 1, 9, 20, dog_character.get_skills(), 4, 0, &"goblin")
	var dog_enemy := BattleUnitState.new(&"dog_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 40)
	var dog_arena := await _instantiate_arena()
	dog_arena.configure_units([setup_actor, dog_actor, dog_enemy])
	dog_arena.begin_skill_action(setup_actor.unit_id, &"quick_mark")
	dog_arena.select_skill_target(dog_enemy.unit_id)
	dog_arena.confirm_skill_action()
	var dog_hp: int = dog_enemy.current_hp
	dog_arena.begin_skill_action(dog_actor.unit_id, &"dogpile_math")
	dog_arena.select_skill_target(dog_enemy.unit_id)
	_expect(dog_arena.confirm_skill_action(), "Dogpile Math commits after allied direct hit")
	_expect(dog_hp - dog_enemy.current_hp == 5, "Dogpile Math uses 110 percent for one attacker")
	dog_arena.queue_free()
	await process_frame

	var loud_actor := _battle_unit(&"mobcaller", BattleUnitState.Side.PLAYER, 0)
	var loud_ally := BattleUnitState.new(&"loud_ally", "Harpy", BattleUnitState.Side.PLAYER, 1, 1, 20, [], 4, 0, &"harpy")
	var loud_enemy := BattleUnitState.new(&"loud_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 1, 20)
	var loud_arena := await _instantiate_arena()
	loud_arena.configure_units([loud_actor, loud_ally, loud_enemy])
	loud_arena.begin_skill_action(loud_actor.unit_id, &"louder_together")
	_expect(loud_arena.select_skill_target(loud_ally.unit_id), "Louder Together ally locks first")
	_expect(loud_arena.select_skill_target(loud_enemy.unit_id), "Louder Together enemy locks second")
	_expect(loud_arena.confirm_skill_action(), "Louder Together commits atomically")
	_expect(loud_ally.get_effective_speed() == 2, "Louder Together grants +1 Speed")
	_expect(loud_enemy.has_advantage(1), "Louder Together applies enemy Advantage")
	loud_arena.queue_free()
	await process_frame


func _instantiate_arena() -> BattleArena:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	if packed == null:
		return null
	var arena := packed.instantiate() as BattleArena
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _battle_unit(class_id: StringName, side: int, slot: int) -> BattleUnitState:
	var character := RunCharacterCatalog.create_by_class_id(class_id)
	return BattleUnitState.new(
		character.character_id, character.display_name, side, slot, character.base_speed,
		character.max_hp, character.get_skills(), character.power, character.defense,
		character.race_id
	)


func _skill(unit: BattleUnitState, skill_id: StringName) -> CharacterSkill:
	for skill: CharacterSkill in unit.skills:
		if skill.skill_id == skill_id:
			return skill
	return null


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
