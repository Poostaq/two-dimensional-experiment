class_name TestDebugEncounterCatalog
extends SceneTree

const CATALOG_PATH: String = "res://Scripts/Battle/debug_encounter_catalog.gd"
var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists(CATALOG_PATH):
		_failures.append("Encounter catalog must exist")
	else:
		var catalog: Script = load(CATALOG_PATH)
		var names: Array = [["Ranger", "Crossbowman"], ["Siege Smith", "Thunderbreaker"], ["Star Archer", "Moon Sage"]]
		var races: Array[StringName] = [&"human", &"dwarf", &"elf"]
		var stats: Array = [[[18, 7, 7, 1], [20, 6, 6, 2]], [[26, 8, 3, 3], [25, 8, 2, 3]], [[16, 7, 8, 1], [15, 7, 7, 0]]]
		for index: int in 3:
			var enemies: Array[BattleUnitState] = catalog.create_enemies(index)
			_expect(enemies.size() == 2, "Each battle has exactly two enemies")
			if enemies.size() != 2:
				continue
			for member: int in 2:
				var unit: BattleUnitState = enemies[member]
				_expect(unit.display_name == names[index][member], "Authored pair identity")
				_expect(unit.race_id == races[index], "Race identity")
				_expect([unit.max_hp, unit.power, unit.speed, unit.defense] == stats[index][member], "Class-sheet stats")
				_expect(unit.unit_id == (&"enemy_0" if member == 0 else &"enemy_4"), "Stable compatibility IDs")
				_expect(unit.slot_index == (0 if member == 0 else 4), "Preserve persisted enemy formation slots")
				_expect(unit.side == BattleUnitState.Side.ENEMY, "Enemy side")
				_expect(unit.skills.size() == 3, "Full three-skill kit")
				for skill: CharacterSkill in unit.skills:
					_expect(skill.is_valid(), "Valid authored skill")
					_expect(skill.target_profile.target_side == BattleUnitState.Side.PLAYER, "Targets opposing player side")
			var fresh: Array[BattleUnitState] = catalog.create_enemies(index + 3)
			enemies[0].current_hp = 1
			_expect(fresh[0].current_hp == fresh[0].max_hp, "Encounters return fresh state and wrap deterministically")
		_test_choices(catalog)
	for failure: String in _failures:
		push_error(failure)
	print("Encounter catalog: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)

func _test_choices(catalog: Script) -> void:
	var target := BattleUnitState.new(&"player", "Goblin", BattleUnitState.Side.PLAYER, 1, 1, 100, [], 4, 0, &"goblin")
	var history: Array[BattleActionLogEntry] = []
	var records: Array[BattleActionRecord] = []
	var humans: Array[BattleUnitState] = catalog.create_enemies(0)
	var units: Array[BattleUnitState] = [target, humans[0], humans[1]]
	var opening: Dictionary = catalog.choose_action(humans[0], units, 1, 0, history, records)
	_expect(opening.get("skill_id") == &"quick_draw", "Ranger opens with Snared setup")
	var source := BattleKeywordSource.create(humans[0].unit_id, &"quick_draw", humans[0].power)
	target.apply_snared(source, 1)
	var followup: Dictionary = catalog.choose_action(humans[1], units, 1, 0, history, records)
	_expect(followup.get("skill_id") == &"repeating_shot", "Crossbowman converts Ranger Snared")
	_expect(followup.get("target_ids") == [&"player"], "Enemy targets the player")
	var second_target := BattleUnitState.new(&"second_player", "Goblin Two", BattleUnitState.Side.PLAYER, 2, 1)
	units.append(second_target)
	humans[1].set_skill_cooldown(&"sightline_mark", 1)
	humans[1].set_skill_cooldown(&"repeating_shot", 1)
	var volley: Dictionary = catalog.choose_action(humans[1], units, 1, 0, history, records)
	_expect(volley.get("skill_id") == &"commanding_volley" and volley.get("target_ids", []).size() == 2, "Volley uses two legal player targets")
	target.current_hp = 0
	second_target.current_hp = 0
	_expect(catalog.choose_action(humans[1], units, 1, 0, history, records).is_empty(), "Defeated players cannot be targeted")
	target.current_hp = target.max_hp
	var dwarves: Array[BattleUnitState] = catalog.create_enemies(1)
	units = [target, dwarves[0], dwarves[1]]
	target.add_armor(5)
	var dwarf_opening: Dictionary = catalog.choose_action(dwarves[0], units, 1, 0, history, records)
	_expect(dwarf_opening.get("skill_id") == &"test_the_plate", "Smith opens with adjacent armor stripping")
	var deltas: Array[Dictionary] = [{&"target_id": target.unit_id, &"kind": BattleKeywordOperation.Kind.ADD_ARMOR, &"value": -3}]
	records.append(BattleActionRecord.new(BattleActionRecord.Kind.SKILL, dwarves[0].unit_id, [target.unit_id], {}, {}, {}, 1, 1, 1, BattleUnitState.Side.ENEMY, &"test_the_plate", true, {}, deltas))
	var dwarf_followup: Dictionary = catalog.choose_action(dwarves[1], units, 1, 1, history, records)
	_expect(dwarf_followup.get("skill_id") == &"cracked_foundation", "Thunderbreaker exploits ally Armor loss")
	_expect(catalog.choose_action(dwarves[1], units, 2, 1, history, records).get("skill_id") != &"cracked_foundation", "Expired Armor-loss setup cannot convert")
	records.clear()
	var elves: Array[BattleUnitState] = catalog.create_enemies(2)
	units = [target, elves[0], elves[1]]
	target.clear_round_keywords(1)
	var elf_opening: Dictionary = catalog.choose_action(elves[0], units, 1, 0, history, records)
	_expect(elf_opening.get("skill_id") == &"threaded_aim", "Star Archer opens Advantage")
	target.apply_advantage(BattleKeywordSource.create(elves[0].unit_id, &"threaded_aim", 7), 1)
	var elf_followup: Dictionary = catalog.choose_action(elves[1], units, 1, 0, history, records)
	_expect(elf_followup.get("skill_id") == &"crescent_collapse", "Moon Sage converts allied Advantage")
	for skill: CharacterSkill in elves[1].skills:
		elves[1].set_skill_cooldown(skill.skill_id, 1)
	_expect(catalog.choose_action(elves[1], units, 1, 0, history, records).is_empty(), "All cooldowns safely fall back")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
