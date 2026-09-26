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
	_finish()


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
