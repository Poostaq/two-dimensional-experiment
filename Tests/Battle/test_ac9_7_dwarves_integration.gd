class_name TestAc97DwarvesIntegration
extends SceneTree

const CLASS_IDS: Array[StringName] = [&"dwarf_forgewarden", &"dwarf_siege_smith", &"dwarf_rune_sentinel", &"dwarf_quarrel_engineer", &"dwarf_hearthkeeper", &"dwarf_thunderbreaker"]
const EXPECTED: Dictionary[StringName, Array] = {
	&"dwarf_forgewarden": [3, 28, 5, 5, [&"iron_brace", &"runed_guard", &"unyielding_stone"]],
	&"dwarf_siege_smith": [3, 26, 8, 3, [&"test_the_plate", &"hollow_core", &"breakers_verdict"]],
	&"dwarf_rune_sentinel": [4, 27, 4, 4, [&"warded_step", &"rune_of_hold", &"living_plate"]],
	&"dwarf_quarrel_engineer": [4, 24, 6, 3, [&"shot_lock", &"hammered_line", &"explosive_refit"]],
	&"dwarf_hearthkeeper": [4, 23, 4, 3, [&"hearth_reset", &"warm_the_line", &"shared_forge"]],
	&"dwarf_thunderbreaker": [2, 25, 8, 3, [&"weight_of_the_hammer", &"cracked_foundation", &"thunderfall_decision"]],
}
var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(RunCharacterCatalog.get_recruitable_class_ids(&"dwarf") == CLASS_IDS, "Dwarf catalog exposes six stable IDs")
	for class_id: StringName in CLASS_IDS:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "Dwarf constructs: %s" % class_id)
		if not is_instance_valid(character):
			continue
		var expected: Array = EXPECTED[class_id]
		_expect(character.class_id == class_id and character.race_id == &"dwarf", "Dwarf identity is stable: %s" % class_id)
		_expect([character.base_speed, character.max_hp, character.power, character.defense] == expected.slice(0, 4), "Dwarf stats match: %s" % class_id)
		var ids: Array[StringName] = []
		for skill: CharacterSkill in character.get_skills():
			ids.append(skill.skill_id)
		_expect(ids == expected[4], "Dwarf skills match: %s" % class_id)
	_test_authored_dwarf_skill_contracts()
	var smith: RunCharacter = RunCharacterCatalog.create_by_class_id(&"dwarf_siege_smith")
	if is_instance_valid(smith):
		_expect(smith.get_skills()[0].authored_effects[0].armor_strip == 2, "Dwarf Siege Smith uses typed Armor strip")
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"thane_brokk_stonevein")
	_expect(is_instance_valid(commander), "Brokk commander constructs")
	if is_instance_valid(commander):
		var skills: Array[CharacterSkill] = commander.get_skills()
		_expect(skills.size() == 4 and skills[0].skill_id == &"iron_brace" and skills[3].skill_id == &"stonevein_bulwark", "Brokk inherits Forgewarden and appends signature")
	var party: Array[RunCharacter] = BossPartyCatalog.create_by_enemy_clan_id(&"dwarf")
	var count: int = 0
	for member: RunCharacter in party:
		if member.class_id == &"thane_brokk_stonevein":
			count += 1
	_expect(party.size() >= 3 and count == 1, "Dwarf boss party contains Brokk exactly once")
	_test_stonevein_bulwark(commander)
	_finish()


func _test_authored_dwarf_skill_contracts() -> void:
	var forgewarden: RunCharacter = RunCharacterCatalog.create_by_class_id(&"dwarf_forgewarden")
	if is_instance_valid(forgewarden):
		var skills: Array[CharacterSkill] = forgewarden.get_skills()
		_expect(skills[0].authored_effects.size() == 2 and skills[0].authored_effects[0].magnitude == 4, "Iron Brace grants both units Armor 4")
		_expect(skills[1].authored_effects.size() == 3 and skills[1].authored_effects[0].power_percent == 90, "Runed Guard deals 90 percent and conditionally protects two units")
		_expect(skills[2].authored_effects[0].conditional_magnitude == 7 and skills[2].authored_effects[1].conditional_magnitude == 7, "Unyielding Stone upgrades wounded targets to Armor 7")
	var sentinel: RunCharacter = RunCharacterCatalog.create_by_class_id(&"dwarf_rune_sentinel")
	if is_instance_valid(sentinel):
		var skills: Array[CharacterSkill] = sentinel.get_skills()
		_expect(skills[0].authored_effects[0].magnitude == 1 and skills[0].authored_effects[1].magnitude == 3, "Warded Step moves 1 and grants Armor 3")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].power_percent == 100 and skills[1].authored_effects[1].duration == 1, "Rune of Hold requires movement and applies Snared")
		_expect(skills[2].target_profile.maximum_targets == 0 and skills[2].authored_effects.size() == 2, "Living Plate protects all allies and adds an injured-ally rider")
	var engineer: RunCharacter = RunCharacterCatalog.create_by_class_id(&"dwarf_quarrel_engineer")
	if is_instance_valid(engineer):
		var skills: Array[CharacterSkill] = engineer.get_skills()
		_expect(skills[0].authored_effects[0].power_percent == 85 and skills[0].authored_effects[1].duration == 1, "Shot-Lock deals 85 percent and applies Snared")
		_expect(skills[2].target_profile.maximum_targets == 2 and skills[2].authored_effects[0].power_percent == 180 and skills[2].authored_effects[1].upgraded_power_percent == 120, "Explosive Refit authors exact primary and secondary damage")
	var keeper: RunCharacter = RunCharacterCatalog.create_by_class_id(&"dwarf_hearthkeeper")
	if is_instance_valid(keeper):
		var skills: Array[CharacterSkill] = keeper.get_skills()
		_expect(not skills[0].conditions.is_empty() and skills[0].authored_effects[0].magnitude == 4 and skills[0].authored_effects[0].conditional_magnitude == 6, "Hearth Reset enforces its health gate and wounded bonus")
		_expect(skills[1].authored_effects.size() == 2 and skills[1].authored_effects[0].conditional_magnitude == 5, "Warm the Line grants Armor 3 or 5 to self and neighbors")
		_expect(skills[2].target_profile.maximum_targets == 0 and skills[2].authored_effects[0].conditional_magnitude == 6, "Shared Forge protects all allies and upgrades during collapse")
	var breaker: RunCharacter = RunCharacterCatalog.create_by_class_id(&"dwarf_thunderbreaker")
	if is_instance_valid(breaker):
		var skills: Array[CharacterSkill] = breaker.get_skills()
		_expect(skills[0].authored_effects[0].armor_strip == 2 and skills[0].authored_effects[0].power_percent == 100, "Weight of the Hammer strips Armor 2 and deals 100 percent")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].upgraded_power_percent == 190, "Cracked Foundation requires Armor loss and upgrades at three")
		_expect(skills[2].authored_effects[0].ignore_armor and skills[2].authored_effects[0].upgraded_power_percent == 250, "Thunderfall Decision ignores Armor and upgrades after Armor loss")


func _test_stonevein_bulwark(commander: RunCharacter) -> void:
	if not is_instance_valid(commander):
		return
	var brokk := BattleUnitState.new(commander.character_id, commander.display_name, BattleUnitState.Side.ENEMY, 1, 10, commander.max_hp, commander.get_skills(), commander.power, commander.defense, commander.race_id)
	var first_ally := BattleUnitState.new(&"dwarf_first_ally", "First Ally", BattleUnitState.Side.ENEMY, 0, 4, 20)
	var second_ally := BattleUnitState.new(&"dwarf_second_ally", "Second Ally", BattleUnitState.Side.ENEMY, 2, 4, 20)
	var opponent := BattleUnitState.new(&"dwarf_test_opponent", "Opponent", BattleUnitState.Side.PLAYER, 1, 3, 20)
	brokk.add_armor(9)
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	arena.configure_units([brokk, first_ally, second_ally, opponent])
	_expect(brokk.get_armor() == 10, "Stonevein Bulwark respects Armor cap 10")
	_expect(first_ally.get_armor() == 2 and second_ally.get_armor() == 2, "Stonevein Bulwark protects every active adjacent ally")
	arena.free()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.7 Dwarf roster: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
