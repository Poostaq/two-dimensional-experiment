extends SceneTree

const CLASS_IDS: Array[StringName] = [
	&"lizardman_venom_saurian", &"lizardman_scale_sentinel", &"lizardman_mire_spitter",
	&"lizardman_fang_alchemist", &"lizardman_reed_ambusher", &"lizardman_sunscale_warder",
]
const EXPECTED: Dictionary[StringName, Array] = {
	&"lizardman_venom_saurian": [5, 20, 7, 1, [&"weakening_bite", &"venom_pulse", &"cold_finish"]],
	&"lizardman_scale_sentinel": [3, 26, 4, 3, [&"brace_scales", &"tail_check", &"layered_scales"]],
	&"lizardman_mire_spitter": [6, 18, 5, 1, [&"slowing_spit", &"bog_down", &"saturate_ground"]],
	&"lizardman_fang_alchemist": [5, 21, 6, 2, [&"corrosive_dose", &"catalyze", &"antidote_exchange"]],
	&"lizardman_reed_ambusher": [6, 19, 7, 1, [&"stillwater_focus", &"sudden_lunge", &"vanish_into_reeds"]],
	&"lizardman_sunscale_warder": [4, 24, 4, 3, [&"warming_armor", &"reflecting_scale", &"solar_bulwark"]],
}
var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(RunCharacterCatalog.get_recruitable_class_ids(&"lizardman") == CLASS_IDS, "Lizardman catalog exposes six stable IDs")
	for class_id: StringName in CLASS_IDS:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "Lizardman class constructs: %s" % class_id)
		if not is_instance_valid(character):
			continue
		var expected: Array = EXPECTED[class_id]
		_expect(character.class_id == class_id and character.race_id == &"lizardman", "Lizardman identity is stable: %s" % class_id)
		_expect([character.base_speed, character.max_hp, character.power, character.defense] == expected.slice(0, 4), "Lizardman stats match: %s" % class_id)
		var skill_ids: Array[StringName] = []
		for skill: CharacterSkill in character.get_skills():
			skill_ids.append(skill.skill_id)
		_expect(skill_ids == expected[4], "Lizardman skills match: %s" % class_id)
	var saurian: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lizardman_venom_saurian")
	if is_instance_valid(saurian):
		var weakening_bite: CharacterSkill = saurian.get_skills()[0]
		_expect(weakening_bite.authored_effects.size() == 2, "Weakening Bite authors damage plus Poison")
		_expect(weakening_bite.authored_effects[1].poison_axis == &"power" and weakening_bite.authored_effects[1].magnitude == 1 and weakening_bite.authored_effects[1].duration == 3, "Weakening Bite uses canonical Power Poison")
	var spitter: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lizardman_mire_spitter")
	if is_instance_valid(spitter):
		_expect(spitter.get_skills()[0].authored_effects[1].poison_axis == &"speed", "Slowing Spit uses Speed Poison")
	var alchemist: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lizardman_fang_alchemist")
	if is_instance_valid(alchemist):
		_expect(alchemist.get_skills()[0].authored_effects[1].poison_axis == &"defense", "Corrosive Dose uses Defense Poison")
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"sszek_still_mire")
	_expect(is_instance_valid(commander), "Sszek commander constructs")
	if is_instance_valid(commander):
		var skills: Array[CharacterSkill] = commander.get_skills()
		_expect(commander.race_id == &"lizardman" and skills.size() == 4, "Sszek preserves faction and four-skill loadout")
		_expect(skills[0].skill_id == &"weakening_bite" and skills[3].skill_id == &"cartographer_of_venoms", "Sszek inherits Venom Saurian and appends signature")
	_expect(RunCharacterCatalog.create_by_class_id(&"lizardman_unknown") == null, "Lizardman catalog rejects unknown IDs")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.2 Lizardman roster: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AC9.2 Lizardman roster: %d assertion(s), %d failure(s)." % [_assertions, _failures.size()])
	quit(1)
