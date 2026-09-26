extends SceneTree

const CLASS_IDS: Array[StringName] = [&"elf_star_archer", &"elf_moon_sage", &"elf_wind_dancer", &"elf_warden_of_the_grove", &"elf_crescent_duelist", &"elf_highborn_mystic"]
const EXPECTED: Dictionary[StringName, Array] = {
	&"elf_star_archer": [8, 16, 7, 1, [&"threaded_aim", &"needle_shot", &"horizon_pierce"]],
	&"elf_moon_sage": [7, 15, 7, 0, [&"silver_sigil", &"lunar_thread", &"crescent_collapse"]],
	&"elf_wind_dancer": [9, 14, 6, 0, [&"step_through_wind", &"arc_of_escape", &"spiral_opening"]],
	&"elf_warden_of_the_grove": [6, 18, 4, 2, [&"rooting_ward", &"calm_the_ring", &"dawnglass_barrier"]],
	&"elf_crescent_duelist": [8, 17, 7, 1, [&"cut_the_angle", &"short_arc", &"final_flourish"]],
	&"elf_highborn_mystic": [7, 16, 8, 0, [&"glyph_of_silence", &"echoed_star", &"final_constellation"]],
}
var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(RunCharacterCatalog.get_recruitable_class_ids(&"elf") == CLASS_IDS, "Elf catalog exposes six stable IDs")
	for class_id: StringName in CLASS_IDS:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "Elf constructs: %s" % class_id)
		if not is_instance_valid(character):
			continue
		var expected: Array = EXPECTED[class_id]
		_expect(character.class_id == class_id and character.race_id == &"elf", "Elf identity is stable: %s" % class_id)
		_expect([character.base_speed, character.max_hp, character.power, character.defense] == expected.slice(0, 4), "Elf stats match: %s" % class_id)
		var ids: Array[StringName] = []
		for skill: CharacterSkill in character.get_skills():
			ids.append(skill.skill_id)
		_expect(ids == expected[4], "Elf skills match: %s" % class_id)
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lady_saelith_moonfall")
	_expect(is_instance_valid(commander), "Saelith commander constructs")
	if is_instance_valid(commander):
		var skills: Array[CharacterSkill] = commander.get_skills()
		_expect(skills.size() == 4 and skills[0].skill_id == &"glyph_of_silence" and skills[3].skill_id == &"moonfall_edict", "Saelith inherits Highborn Mystic and appends signature")
	var party: Array[RunCharacter] = BossPartyCatalog.create_by_enemy_clan_id(&"elf")
	var count: int = 0
	for member: RunCharacter in party:
		if member.class_id == &"lady_saelith_moonfall":
			count += 1
	_expect(party.size() >= 3 and count == 1, "Elf boss party contains Saelith exactly once")
	_test_moonfall_edict(commander)
	_finish()


func _test_moonfall_edict(commander: RunCharacter) -> void:
	if not is_instance_valid(commander):
		return
	var saelith := BattleUnitState.new(commander.character_id, commander.display_name, BattleUnitState.Side.ENEMY, 1, 10, commander.max_hp, commander.get_skills(), commander.power, commander.defense, commander.race_id)
	var closest := BattleUnitState.new(&"elf_closest_enemy", "Closest", BattleUnitState.Side.PLAYER, 0, 3, 20)
	var farther := BattleUnitState.new(&"elf_farther_enemy", "Farther", BattleUnitState.Side.PLAYER, 2, 3, 20)
	var snare_source: RefCounted = BattleKeywordSource.create(&"test", &"test_snare", 1)
	closest.apply_snared(snare_source, 1)
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	arena.configure_units([saelith, closest, farther])
	_expect(closest.has_advantage(1), "Moonfall Edict marks the deterministic closest enemy")
	_expect(not farther.has_advantage(1), "Moonfall Edict does not redirect to another enemy")
	_expect(saelith.get_effective_speed() == 11, "Moonfall Edict grants round Speed when the target is Snared")
	arena.free()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.6 Elf roster: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
