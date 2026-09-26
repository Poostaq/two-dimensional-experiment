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
	_finish()


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
