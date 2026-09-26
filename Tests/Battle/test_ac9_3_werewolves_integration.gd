extends SceneTree

const CLASS_IDS: Array[StringName] = [&"werewolf_moonfang_skirmisher", &"werewolf_pack_howler", &"werewolf_bloodtrail_stalker", &"werewolf_duskhide_ravager", &"werewolf_den_warden", &"werewolf_moonblood_seer"]
const EXPECTED: Dictionary[StringName, Array] = {
	&"werewolf_moonfang_skirmisher": [9, 17, 9, 0, [&"scent_blood", &"pounce", &"moonfang_finish"]],
	&"werewolf_pack_howler": [8, 20, 6, 1, [&"hunting_cry", &"drive_the_pack", &"full_moon_chorus"]],
	&"werewolf_bloodtrail_stalker": [8, 18, 8, 0, [&"rake", &"follow_the_trail", &"cornered_prey"]],
	&"werewolf_duskhide_ravager": [6, 22, 9, 1, [&"reckless_claw", &"feed_through_pain", &"frenzied_lunge"]],
	&"werewolf_den_warden": [6, 24, 6, 2, [&"armor_the_weak", &"warning_snarl", &"pack_intercept"]],
	&"werewolf_moonblood_seer": [7, 19, 6, 1, [&"foretell_the_kill", &"red_moon_strike", &"eclipse_hunt"]],
}
var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(RunCharacterCatalog.get_recruitable_class_ids(&"werewolf") == CLASS_IDS, "Werewolf catalog exposes six stable IDs")
	for class_id: StringName in CLASS_IDS:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "Werewolf constructs: %s" % class_id)
		if not is_instance_valid(character):
			continue
		var expected: Array = EXPECTED[class_id]
		_expect(character.class_id == class_id and character.race_id == &"werewolf", "Werewolf identity is stable: %s" % class_id)
		_expect([character.base_speed, character.max_hp, character.power, character.defense] == expected.slice(0, 4), "Werewolf stats match: %s" % class_id)
		var skill_ids: Array[StringName] = []
		for skill: CharacterSkill in character.get_skills():
			skill_ids.append(skill.skill_id)
		_expect(skill_ids == expected[4], "Werewolf skills match: %s" % class_id)
	var skirmisher: RunCharacter = RunCharacterCatalog.create_by_class_id(&"werewolf_moonfang_skirmisher")
	if is_instance_valid(skirmisher):
		var finish: CharacterSkill = skirmisher.get_skills()[2]
		_expect(finish.authored_effects.size() == 2 and finish.authored_effects[1].keyword_kind == BattleKeywordOperation.Kind.LEECH and finish.authored_effects[1].magnitude == 35, "Moonfang Finish authors 35 percent direct-damage Leech")
	var ravager: RunCharacter = RunCharacterCatalog.create_by_class_id(&"werewolf_duskhide_ravager")
	if is_instance_valid(ravager):
		var feed: CharacterSkill = ravager.get_skills()[1]
		_expect(feed.authored_effects.size() == 2 and feed.authored_effects[1].magnitude == 40, "Feed Through Pain authors 40 percent direct-damage Leech")
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"veyra_moontrace")
	_expect(is_instance_valid(commander), "Veyra commander constructs")
	if is_instance_valid(commander):
		var skills: Array[CharacterSkill] = commander.get_skills()
		_expect(commander.race_id == &"werewolf" and skills.size() == 4, "Veyra preserves faction and four-skill loadout")
		_expect(skills[0].skill_id == &"scent_blood" and skills[3].skill_id == &"mark_of_the_alpha", "Veyra inherits Moonfang and appends signature")
	_expect(RunCharacterCatalog.create_by_class_id(&"werewolf_unknown") == null, "Werewolf catalog rejects unknown IDs")
	_test_mark_of_the_alpha(commander)
	_finish()


func _test_mark_of_the_alpha(commander: RunCharacter) -> void:
	if not is_instance_valid(commander):
		return
	var veyra := BattleUnitState.new(commander.character_id, commander.display_name, BattleUnitState.Side.PLAYER, 1, 9, commander.max_hp, commander.get_skills(), commander.power, commander.defense, commander.race_id)
	var ally := BattleUnitState.new(&"werewolf_triggering_ally", "Triggering Ally", BattleUnitState.Side.PLAYER, 0, 10, 20)
	var target := BattleUnitState.new(&"werewolf_threshold_target", "Threshold Target", BattleUnitState.Side.ENEMY, 0, 1, 20)
	target.current_hp = 9
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	arena.configure_units([ally, veyra, target])
	var record := BattleActionRecord.new(
		BattleActionRecord.Kind.SKILL, ally.unit_id, [target.unit_id], {target.unit_id: 3},
		{}, {}, 1, 1, 1, ally.side, &"threshold_hit", false,
		{target.unit_id: true}
	)
	var deltas: Array[Dictionary] = []
	arena.call("_dispatch_passive_reactions", record, 1, deltas)
	_expect(veyra.has_advantage(1), "Mark of the Alpha grants Veyra Advantage on a half-HP crossing")
	_expect(ally.has_method("get_pending_leech_percent"), "Battle units expose pending one-hit Leech")
	if ally.has_method("get_pending_leech_percent"):
		_expect(ally.call("get_pending_leech_percent", 1) == 15, "Mark of the Alpha grants the triggering ally 15 percent Leech")
	arena.call("_dispatch_passive_reactions", record, 1, deltas)
	if ally.has_method("get_pending_leech_percent"):
		_expect(ally.call("get_pending_leech_percent", 1) == 15, "Mark of the Alpha fires once per round")
	arena.free()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.3 Werewolf roster: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AC9.3 Werewolf roster: %d assertion(s), %d failure(s)." % [_assertions, _failures.size()])
	quit(1)
