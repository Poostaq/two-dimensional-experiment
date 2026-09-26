class_name TestAc95HumansIntegration
extends SceneTree

const CLASS_IDS: Array[StringName] = [&"human_vanguard", &"human_ranger", &"human_iron_sentinel", &"human_field_medic", &"human_crosbowman", &"human_duelist"]
const EXPECTED: Dictionary[StringName, Array] = {
	&"human_vanguard": [5, 22, 5, 3, [&"commanding_step", &"shielded_advance", &"lineholders_verdict"]],
	&"human_ranger": [7, 18, 7, 1, [&"quick_draw", &"pinning_volley", &"break_the_angle"]],
	&"human_iron_sentinel": [4, 25, 4, 4, [&"brace_the_line", &"field_fortification", &"wall_of_steel"]],
	&"human_field_medic": [6, 19, 4, 2, [&"combat_patch", &"guarded_recovery", &"hold_the_wound"]],
	&"human_crosbowman": [6, 20, 6, 2, [&"sightline_mark", &"repeating_shot", &"commanding_volley"]],
	&"human_duelist": [7, 21, 8, 1, [&"cut_the_distance", &"counterstep", &"final_verdict"]],
}
var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(RunCharacterCatalog.get_recruitable_class_ids(&"human") == CLASS_IDS, "Human catalog exposes six stable IDs")
	for class_id: StringName in CLASS_IDS:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "Human constructs: %s" % class_id)
		if not is_instance_valid(character):
			continue
		var expected: Array = EXPECTED[class_id]
		_expect(character.class_id == class_id and character.race_id == &"human", "Human identity is stable: %s" % class_id)
		_expect([character.base_speed, character.max_hp, character.power, character.defense] == expected.slice(0, 4), "Human stats match: %s" % class_id)
		var ids: Array[StringName] = []
		for skill: CharacterSkill in character.get_skills():
			ids.append(skill.skill_id)
		_expect(ids == expected[4], "Human skills match: %s" % class_id)
	_test_authored_human_skill_contracts()
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"marshal_elian_voss")
	_expect(is_instance_valid(commander), "Elian commander constructs")
	if is_instance_valid(commander):
		var skills: Array[CharacterSkill] = commander.get_skills()
		_expect(skills.size() == 4 and skills[0].skill_id == &"commanding_step" and skills[3].skill_id == &"marshal_the_line", "Elian inherits Vanguard and appends signature")
	var party: Array[RunCharacter] = BossPartyCatalog.create_by_enemy_clan_id(&"human")
	_expect(party.size() >= 3, "Human boss party is authored")
	var commander_count: int = 0
	for member: RunCharacter in party:
		if member.class_id == &"marshal_elian_voss":
			commander_count += 1
	_expect(commander_count == 1, "Human boss party contains Elian exactly once")
	_test_marshal_the_line(commander)
	_test_save_reload()
	_finish()


func _test_authored_human_skill_contracts() -> void:
	var vanguard: RunCharacter = RunCharacterCatalog.create_by_class_id(&"human_vanguard")
	if is_instance_valid(vanguard):
		var skills: Array[CharacterSkill] = vanguard.get_skills()
		_expect(skills[0].authored_effects.size() == 3 and skills[0].authored_effects[0].magnitude == 1 and skills[0].authored_effects[1].magnitude == 3, "Commanding Step moves 1 and grants both units Armor 3")
		_expect(skills[1].authored_effects[0].power_percent == 115 and skills[1].authored_effects[0].upgraded_power_percent == 145, "Shielded Advance authors its protected-formation damage upgrade")
		_expect(skills[2].authored_effects[0].power_percent == 180 and skills[2].authored_effects[0].upgraded_power_percent == 210 and skills[2].authored_effects[0].bonus_condition != BattleSkillEffectDefinition.BonusCondition.NONE, "Lineholder's Verdict rewards allied sequencing")
	var sentinel: RunCharacter = RunCharacterCatalog.create_by_class_id(&"human_iron_sentinel")
	if is_instance_valid(sentinel):
		var skills: Array[CharacterSkill] = sentinel.get_skills()
		_expect(skills[0].authored_effects.size() == 2 and skills[0].authored_effects[0].magnitude == 4 and skills[0].authored_effects[1].magnitude == 4, "Brace the Line grants both units Armor 4")
		_expect(skills[1].authored_effects[0].power_percent == 100 and skills[1].authored_effects[0].armor_strip == 2 and skills[1].authored_effects[0].bonus_condition != BattleSkillEffectDefinition.BonusCondition.NONE, "Field Fortification conditionally strips Armor 2")
		_expect(skills[2].authored_effects.size() == 2 and skills[2].authored_effects[0].magnitude == 5 and skills[2].authored_effects[0].conditional_magnitude == 7, "Wall of Steel grants Armor 5, upgraded to 7 when wounded")
	var medic: RunCharacter = RunCharacterCatalog.create_by_class_id(&"human_field_medic")
	if is_instance_valid(medic):
		var skills: Array[CharacterSkill] = medic.get_skills()
		_expect(not skills[0].conditions.is_empty() and skills[0].authored_effects[0].magnitude == 4 and skills[0].authored_effects[0].conditional_magnitude == 6, "Combat Patch enforces its health gate and wounded bonus")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].conditional_magnitude == 5, "Guarded Recovery requires Armor and upgrades to Armor 5")
		_expect(skills[2].target_profile.maximum_targets == 0 and skills[2].authored_effects[0].magnitude == 4 and skills[2].authored_effects[0].conditional_magnitude == 6, "Hold the Wound automatically protects every wounded ally")
	var crossbowman: RunCharacter = RunCharacterCatalog.create_by_class_id(&"human_crosbowman")
	if is_instance_valid(crossbowman):
		var skills: Array[CharacterSkill] = crossbowman.get_skills()
		_expect(skills[1].authored_effects[0].power_percent == 140 and skills[1].authored_effects[0].upgraded_power_percent == 170 and skills[1].authored_effects[0].consume_bonus_advantage, "Repeating Shot consumes Advantage for 170 percent damage")
		_expect(skills[2].target_profile.maximum_targets == 2 and skills[2].authored_effects[0].upgraded_power_percent == 180 and skills[2].authored_effects[1].power_percent == 120, "Commanding Volley authors distinct first and second target damage")
	var duelist: RunCharacter = RunCharacterCatalog.create_by_class_id(&"human_duelist")
	if is_instance_valid(duelist):
		var skills: Array[CharacterSkill] = duelist.get_skills()
		_expect(skills[0].authored_effects[0].power_percent == 100 and skills[0].authored_effects[0].upgraded_power_percent == 130 and skills[0].authored_effects[1].magnitude == 2, "Cut the Distance moves 2 and punishes prior movement")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].power_percent == 140 and skills[1].authored_effects[0].upgraded_power_percent == 170, "Counterstep enforces retaliation and marked-target bonus")
		_expect(not skills[2].conditions.is_empty() and skills[2].authored_effects[0].power_percent == 210 and skills[2].authored_effects[0].upgraded_power_percent == 240 and skills[2].authored_effects[0].consume_bonus_advantage, "Final Verdict consumes Advantage for 240 percent damage")


func _test_marshal_the_line(commander: RunCharacter) -> void:
	if not is_instance_valid(commander):
		return
	var elian := BattleUnitState.new(commander.character_id, commander.display_name, BattleUnitState.Side.ENEMY, 1, 10, commander.max_hp, commander.get_skills(), commander.power, commander.defense, commander.race_id)
	var lower_ally := BattleUnitState.new(&"human_lower_ally", "Lower Ally", BattleUnitState.Side.ENEMY, 0, 4, 20)
	var higher_ally := BattleUnitState.new(&"human_higher_ally", "Higher Ally", BattleUnitState.Side.ENEMY, 2, 4, 20)
	var opponent := BattleUnitState.new(&"human_test_opponent", "Opponent", BattleUnitState.Side.PLAYER, 1, 3, 20)
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	arena.configure_units([elian, lower_ally, higher_ally, opponent])
	_expect(elian.get_armor() == 2, "Marshal the Line grants Elian 2 Armor")
	_expect(lower_ally.get_armor() == 2, "Marshal the Line chooses the lowest-slot adjacent ally")
	_expect(higher_ally.get_armor() == 0, "Marshal the Line affects only one adjacent ally")
	arena.free()


func _test_save_reload() -> void:
	var identities: Array[StringName] = CLASS_IDS.duplicate()
	identities.append(&"marshal_elian_voss")
	var probe: Script = load("res://Tests/Support/ac9_faction_round_trip_probe.gd") as Script
	var result: Dictionary = probe.verify(identities, "ac9-5-human-round-trip")
	_expect(
		result.get("ok", false) and result.get("checked", 0) == 7,
		"Human classes and commander survive save/reload: %s" % result.get("error", ""),
	)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.5 Human roster: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
