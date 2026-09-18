class_name GoblinEncounterIntegrationTests
extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var starters: Array[RunCharacter] = RunCharacterCatalog.create_starters()
	_expect(starters.size() == 3, "three starters")
	var names: Array[String] = ["Scrapshield Bruiser", "Wirefang Skirmisher", "Snarewright"]
	for index: int in starters.size():
		_expect(starters[index].race_id == &"goblin", "starter is goblin")
		_expect(starters[index].display_name == names[index], "starter has authored class")
		_expect(starters[index].get_skills().size() == 3, "starter has full kit")
		_expect(starters[index].character_id == StringName("player_%d" % index), "legacy save identity preserved")
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	var players: int = 0
	var enemies: int = 0
	for unit: BattleUnitState in arena.get_turn_queue():
		if unit.side == BattleUnitState.Side.PLAYER:
			players += 1
			_expect(unit.race_id == &"goblin", "standalone player is goblin")
		else:
			enemies += 1
			_expect(unit.race_id == &"human", "first standalone team is human")
	_expect(players == 3 and enemies == 2, "default battle has three goblins and two enemies")
	arena.free()
	for index: int in 3:
		_test_enemy_pair(index)
	_test_selection_and_scheduling()
	if failures.is_empty():
		print("Goblin encounter integration: PASS")
		quit(0)
	else:
		for failure: String in failures:
			printerr(failure)
		quit(1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)


func _test_enemy_pair(index: int) -> void:
	var catalog: Script = load("res://Scripts/Battle/debug_encounter_catalog.gd")
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	var target: BattleUnitState = BattleUnitState.new(&"target", "Test target", BattleUnitState.Side.PLAYER, 1, 1, 100, [], 4)
	if index == 1:
		target.add_armor(10)
	var enemies: Array[BattleUnitState] = catalog.create_enemies(index)
	var units: Array[BattleUnitState] = [target]
	units.append_array(enemies)
	arena.configure_units(units)
	_expect(not arena.begin_skill_action(enemies[0].unit_id, enemies[0].skills[0].skill_id), "player cannot submit enemy skills")
	_expect(arena.call("_perform_enemy_turn"), "enemy opener commits through transaction")
	var first: Array[BattleActionRecord] = arena.get_action_records()
	_expect(first.size() == 1, "one opener record")
	if index == 0:
		_expect(target.is_snared(1), "human opener snares")
	elif index == 1:
		_expect(target.get_armor() == 0, "dwarf strips and absorbs Armor")
		var colors: Dictionary = arena.call("_collect_effect_highlight_colors", first[0].keyword_deltas)
		_expect(colors.get(target.unit_id) == arena.EFFECT_NEGATIVE_BORDER_COLOR, "Armor loss has negative feedback")
		_expect(BattleHistoryQuery.armor_lost_this_round(first, target.unit_id, 1) == 10, "record actual Armor loss")
	else:
		_expect(target.has_advantage(1), "elf opener marks")
	_expect(arena.call("_perform_enemy_turn"), "enemy partner commits payoff")
	var records: Array[BattleActionRecord] = arena.get_action_records()
	var payoff: Array[StringName] = [&"repeating_shot", &"cracked_foundation", &"crescent_collapse"]
	_expect(records.size() == 2 and records[1].source_skill_id == payoff[index], "partner uses intended combo")
	_expect(records.size() == 2 and records[0].target_ids == records[1].target_ids, "pair focuses prepared target")
	_expect(arena.get_current_unit() == target, "control returns to player")
	arena.free()

func _test_selection_and_scheduling() -> void:
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	arena.debug_encounter_index = 2
	root.add_child(arena)
	_expect(arena.get_unit_by_id(&"enemy_0").race_id == &"elf", "standalone exported selection")
	for index: int in 3:
		arena.configure(Vector2i(index, 0), WorldEncounterType.COMBAT)
		arena.configure_party_units(RunRoster.new().create_battle_units())
		var races: Array[StringName] = [&"human", &"dwarf", &"elf"]
		_expect(arena.get_unit_by_id(&"enemy_0").race_id == races[index], "coordinates choose stable team")
	arena.configure(Vector2i(0, 0), WorldEncounterType.COMBAT)
	arena.configure_party_units(RunRoster.new().create_battle_units())
	while arena.get_current_unit().side == BattleUnitState.Side.PLAYER:
		arena.advance_turn()
	arena.call("_process", 0.7)
	_expect(arena.get_action_records().size() == 1, "default encounter automatically takes enemy turn")
	var catalog: Script = load("res://Scripts/Battle/debug_encounter_catalog.gd")
	var enemies: Array[BattleUnitState] = catalog.create_enemies()
	var target: BattleUnitState = BattleUnitState.new(&"target", "Target", 0, 1, 1, 100)
	var units: Array[BattleUnitState] = [target]
	units.append_array(enemies)
	arena.configure_units(units)
	arena.call("_process", 1.0)
	_expect(arena.get_action_records().is_empty(), "explicit fixture remains manually controlled")
	for skill: CharacterSkill in enemies[0].skills:
		enemies[0].set_skill_cooldown(skill.skill_id, 3)
	_expect(arena.call("_perform_enemy_turn"), "enemy can fall back to Default Attack")
	_expect(arena.get_action_records()[0].kind == BattleActionRecord.Kind.DEFAULT_ATTACK, "fallback is ordinary attack")
	arena.free()
