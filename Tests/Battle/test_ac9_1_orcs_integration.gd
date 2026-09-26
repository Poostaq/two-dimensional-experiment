extends SceneTree

const ORC_CLASS_IDS: Array[StringName] = [
	&"orc_iron_tusk_vanguard",
	&"orc_bonebreaker_reaver",
	&"orc_bloodbanner_captain",
	&"orc_chainwarden",
	&"orc_war_drummer",
	&"orc_siegebreaker",
]

const EXPECTED_STATS: Dictionary[StringName, Array] = {
	&"orc_iron_tusk_vanguard": [2, 30, 5, 5, [&"brace_line", &"shield_ram", &"hold_the_gap"]],
	&"orc_bonebreaker_reaver": [4, 26, 8, 2, [&"crushing_entry", &"break_formation", &"execution_swing"]],
	&"orc_bloodbanner_captain": [3, 28, 5, 4, [&"plant_banner", &"rally_strike", &"last_standard"]],
	&"orc_chainwarden": [4, 27, 4, 4, [&"chain_lash", &"yank_back", &"lockdown"]],
	&"orc_war_drummer": [5, 24, 4, 3, [&"marching_beat", &"crushing_cadence", &"war_tempo"]],
	&"orc_siegebreaker": [2, 25, 8, 3, [&"test_the_plate", &"crack_armor", &"demolishing_blow"]],
}

var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var resolved_ids: Array[StringName] = RunCharacterCatalog.get_recruitable_class_ids(&"orc")
	_expect(resolved_ids == ORC_CLASS_IDS, "Orc catalog exposes all six stable class IDs")
	for class_id: StringName in ORC_CLASS_IDS:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "Orc class constructs: %s" % class_id)
		if is_instance_valid(character):
			_expect(character.class_id == class_id, "Orc class preserves identity: %s" % class_id)
			_expect(character.race_id == &"orc", "Orc class preserves race: %s" % class_id)
			var expected: Array = EXPECTED_STATS[class_id]
			_expect(character.base_speed == expected[0] and character.max_hp == expected[1] and character.power == expected[2] and character.defense == expected[3], "Orc class preserves documented stats: %s" % class_id)
			var skill_ids: Array[StringName] = []
			for skill: CharacterSkill in character.get_skills():
				skill_ids.append(skill.skill_id)
			_expect(skill_ids == expected[4], "Orc class preserves documented skills: %s" % class_id)
	_expect(RunCharacterCatalog.create_by_class_id(&"orc_unknown") == null, "Orc catalog rejects unknown IDs")
	var vanguard: RunCharacter = RunCharacterCatalog.create_by_class_id(&"orc_iron_tusk_vanguard")
	var brace: CharacterSkill = vanguard.get_skills()[0]
	_expect(brace.authored_effects.size() == 2, "Brace Line grants Armor to actor and selected ally")
	_expect(brace.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and brace.authored_effects[0].magnitude == 4, "Brace Line grants four Armor")
	var hold_the_gap: CharacterSkill = vanguard.get_skills()[2]
	_expect(hold_the_gap.authored_effects.size() == 3, "Hold the Gap grants Armor to the Vanguard and both adjacent allies")
	_expect(hold_the_gap.target_profile.require_adjacent_lane, "Hold the Gap requires adjacent allied selections")
	for effect: RefCounted in hold_the_gap.authored_effects:
		_expect(effect.keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and effect.magnitude == 5, "Hold the Gap grants five Armor per target")
	var captain: RunCharacter = RunCharacterCatalog.create_by_class_id(&"orc_bloodbanner_captain")
	var plant_banner: CharacterSkill = captain.get_skills()[0]
	_expect(plant_banner.authored_effects.size() == 1 and plant_banner.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and plant_banner.authored_effects[0].magnitude == 3, "Plant Banner grants three Armor to selected allies")
	var drummer: RunCharacter = RunCharacterCatalog.create_by_class_id(&"orc_war_drummer")
	var marching_beat: CharacterSkill = drummer.get_skills()[0]
	_expect(marching_beat.authored_effects.size() == 1 and marching_beat.authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.PRIMARY and marching_beat.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.APPLY_ADVANTAGE, "Marching Beat grants Advantage to one ally")
	var war_tempo: CharacterSkill = drummer.get_skills()[2]
	_expect(war_tempo.authored_effects.size() == 1 and war_tempo.authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.ALL_SELECTED and war_tempo.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and war_tempo.authored_effects[0].magnitude == 3, "War Tempo grants three Armor to all selected allies")
	var last_standard: CharacterSkill = captain.get_skills()[2]
	_expect(last_standard.authored_effects.size() == 1 and last_standard.authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.ALL_SELECTED and last_standard.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and last_standard.authored_effects[0].magnitude == 5, "Last Standard grants five Armor to all selected allies")
	var goruk: RunCharacter = RunCharacterCatalog.create_by_class_id(&"goruk_ironline")
	_expect(is_instance_valid(goruk), "Goruk commander constructs")
	if is_instance_valid(goruk):
		_expect(goruk.race_id == &"orc" and goruk.class_id == &"goruk_ironline", "Goruk preserves stable commander identity")
		var goruk_skills: Array[CharacterSkill] = goruk.get_skills()
		_expect(goruk_skills.size() == 4, "Goruk inherits three skills and appends one")
		if goruk_skills.size() == 4:
			_expect(goruk_skills[3].skill_id == &"iron_decree", "Goruk appends Iron Decree")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.1 Orc roster: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AC9.1 Orc roster: %d assertion(s), %d failure(s)." % [_assertions, _failures.size()])
	quit(1)
