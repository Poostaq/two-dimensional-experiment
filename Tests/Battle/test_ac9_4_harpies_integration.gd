extends SceneTree

const CLASS_IDS: Array[StringName] = [&"harpy_talon_duelist", &"harpy_storm_siren", &"harpy_gale_scout", &"harpy_skyhook_raider", &"harpy_nestguard", &"harpy_carrion_cantor"]
const EXPECTED: Dictionary[StringName, Array] = {
	&"harpy_talon_duelist": [10, 14, 8, 0, [&"raking_pass", &"exploit_opening", &"wingbeat_retreat"]],
	&"harpy_storm_siren": [8, 17, 6, 1, [&"gust_call", &"crosswind_pull", &"eye_of_the_storm"]],
	&"harpy_gale_scout": [10, 12, 6, 0, [&"spot_the_straggler", &"diving_signal", &"updraft_reposition"]],
	&"harpy_skyhook_raider": [8, 18, 7, 1, [&"hook_and_lift", &"drop_out_of_line", &"snatch_away"]],
	&"harpy_nestguard": [7, 20, 5, 1, [&"covering_wings", &"warning_screech", &"rescue_flight"]],
	&"harpy_carrion_cantor": [9, 16, 7, 0, [&"cutting_note", &"rending_chorus", &"funeral_spiral"]],
}
var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(RunCharacterCatalog.get_recruitable_class_ids(&"harpy") == CLASS_IDS, "Harpy catalog exposes six stable IDs")
	for class_id: StringName in CLASS_IDS:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "Harpy constructs: %s" % class_id)
		if not is_instance_valid(character):
			continue
		var expected: Array = EXPECTED[class_id]
		_expect(character.class_id == class_id and character.race_id == &"harpy", "Harpy identity is stable: %s" % class_id)
		_expect([character.base_speed, character.max_hp, character.power, character.defense] == expected.slice(0, 4), "Harpy stats match: %s" % class_id)
		var skill_ids: Array[StringName] = []
		for skill: CharacterSkill in character.get_skills():
			skill_ids.append(skill.skill_id)
		_expect(skill_ids == expected[4], "Harpy skills match: %s" % class_id)
	var duelist: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_talon_duelist")
	if is_instance_valid(duelist):
		var raking_pass: CharacterSkill = duelist.get_skills()[0]
		_expect(raking_pass.target_profile.allows_optional_self_move, "Raking Pass exposes a declared movement path")
		var has_move_effect: bool = false
		for effect: RefCounted in raking_pass.authored_effects:
			has_move_effect = has_move_effect or effect.kind == BattleSkillEffectDefinition.Kind.OPTIONAL_SELF_MOVE
		_expect(has_move_effect, "Raking Pass authors movement through the typed effect seam")
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"kyris_windscar")
	_expect(is_instance_valid(commander), "Kyris commander constructs")
	if is_instance_valid(commander):
		var skills: Array[CharacterSkill] = commander.get_skills()
		_expect(commander.race_id == &"harpy" and skills.size() == 4, "Kyris preserves faction and four-skill loadout")
		_expect(skills[0].skill_id == &"raking_pass" and skills[3].skill_id == &"open_sky_command", "Kyris inherits Talon Duelist and appends signature")
	_expect(RunCharacterCatalog.create_by_class_id(&"harpy_unknown") == null, "Harpy catalog rejects unknown IDs")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.4 Harpy roster: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AC9.4 Harpy roster: %d assertion(s), %d failure(s)." % [_assertions, _failures.size()])
	quit(1)
