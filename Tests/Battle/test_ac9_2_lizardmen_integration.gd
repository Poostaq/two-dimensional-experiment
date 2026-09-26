class_name TestAc92LizardmenIntegration
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
	_expect(BattleSkillEffectDefinition.Kind.has("POISON_SCALED_DAMAGE"), "Shared effects support Poison stack scaling")
	_expect(BattleSkillEffectDefinition.Kind.has("ARMOR_SPEND_DAMAGE"), "Shared effects support Armor-spend damage")
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
		var venom_pulse: CharacterSkill = saurian.get_skills()[1]
		_expect(not venom_pulse.conditions.is_empty() and venom_pulse.authored_effects.size() == 2, "Venom Pulse requires and deepens the actor's Power Poison")
		var cold_finish: CharacterSkill = saurian.get_skills()[2]
		_expect(cold_finish.authored_effects[0].power_percent == 120 and cold_finish.authored_effects[0].history_increment == 20 and cold_finish.authored_effects[0].maximum_power_percent == 180 and cold_finish.authored_effects[0].advantage_power_percent == 20, "Cold Finish scales 120 +20 per source stack, max 180, plus 20 with Advantage")
	var spitter: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lizardman_mire_spitter")
	if is_instance_valid(spitter):
		_expect(spitter.get_skills()[0].authored_effects[1].poison_axis == &"speed", "Slowing Spit uses Speed Poison")
		var bog_down: CharacterSkill = spitter.get_skills()[1]
		_expect(not bog_down.conditions.is_empty() and bog_down.authored_effects.size() == 2 and bog_down.authored_effects[1].kind == BattleSkillEffectDefinition.Kind.FORCED_TARGET_MOVE and bog_down.authored_effects[1].magnitude == 1, "Bog Down requires source Poison, adds a stack, and moves one")
		_expect(spitter.get_skills()[2].target_profile.minimum_targets == 2 and spitter.get_skills()[2].target_profile.maximum_targets == 3, "Saturate Ground targets two or three enemies")
	var alchemist: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lizardman_fang_alchemist")
	if is_instance_valid(alchemist):
		_expect(alchemist.get_skills()[0].authored_effects[1].poison_axis == &"defense", "Corrosive Dose uses Defense Poison")
		var catalyze: CharacterSkill = alchemist.get_skills()[1]
		_expect(catalyze.authored_effects[0].power_percent == 80 and catalyze.authored_effects[0].history_increment == 20 and catalyze.authored_effects[0].maximum_power_percent == 160 and catalyze.authored_effects[0].advantage_power_percent == 20, "Catalyze scales from all Poison stacks with its Advantage bonus")
	var sentinel: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lizardman_scale_sentinel")
	_expect(sentinel.get_skills()[1].authored_effects.size() == 2 and sentinel.get_skills()[1].authored_effects[1].kind == BattleSkillEffectDefinition.Kind.FORCED_TARGET_MOVE, "Tail Check deals damage and moves one")
	var ambusher: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lizardman_reed_ambusher")
	_expect(ambusher.get_skills()[1].authored_effects[1].magnitude == 3 and ambusher.get_skills()[2].authored_effects[0].magnitude == 2, "Reed Ambusher preserves Move 3 and Move 2 ranges")
	var warder: RunCharacter = RunCharacterCatalog.create_by_class_id(&"lizardman_sunscale_warder")
	_expect(warder.get_skills()[1].authored_effects[0].magnitude == 3 and warder.get_skills()[1].authored_effects[0].power_percent == 50, "Reflecting Scale spends up to three Armor for 50 percent each")
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"sszek_still_mire")
	_expect(is_instance_valid(commander), "Sszek commander constructs")
	if is_instance_valid(commander):
		var skills: Array[CharacterSkill] = commander.get_skills()
		_expect(commander.race_id == &"lizardman" and skills.size() == 4, "Sszek preserves faction and four-skill loadout")
		_expect(skills[0].skill_id == &"weakening_bite" and skills[3].skill_id == &"cartographer_of_venoms", "Sszek inherits Venom Saurian and appends signature")
	_expect(RunCharacterCatalog.create_by_class_id(&"lizardman_unknown") == null, "Lizardman catalog rejects unknown IDs")
	_test_cartographer_of_venoms(commander)
	_test_antidote_exchange_plan()
	_test_save_reload()
	_finish()


func _test_antidote_exchange_plan() -> void:
	var alchemist_character: RunCharacter = RunCharacterCatalog.create_by_class_id(
		&"lizardman_fang_alchemist"
	)
	var alchemist := BattleUnitState.new(
		&"alchemist", "Alchemist", BattleUnitState.Side.PLAYER, 0, 5, 21,
		alchemist_character.get_skills(), 6, 2, &"lizardman"
	)
	var ally := BattleUnitState.new(
		&"poisoned_ally", "Ally", BattleUnitState.Side.PLAYER, 1, 4, 20
	)
	var enemy := BattleUnitState.new(
		&"transfer_enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 4, 20
	)
	var poison_source: RefCounted = BattleKeywordSource.create(&"enemy_source", &"toxin", 7)
	ally.apply_poison(poison_source, &"defense", 2, 3)
	var empty_history: Array[BattleActionLogEntry] = []
	var empty_records: Array[BattleActionRecord] = []
	var plan: SkillEffectPlan = BattleSkillAuthoringResolver.build_plan(
		alchemist, alchemist_character.get_skills()[2], [ally, enemy],
		[alchemist, ally, enemy], 1, 0, empty_history, [], empty_records
	)
	_expect(is_instance_valid(plan), "Antidote Exchange builds from an ally Poison source")
	if is_instance_valid(plan):
		_expect(
			plan.keyword_operations.size() == 1
			and plan.keyword_operations[0].kind == BattleKeywordOperation.Kind.TRANSFER_POISON
			and plan.keyword_operations[0].target_id == ally.unit_id
			and plan.keyword_operations[0].affected_skill_id == enemy.unit_id,
			"Antidote Exchange preserves the source while addressing ally and enemy"
		)


func _test_cartographer_of_venoms(commander: RunCharacter) -> void:
	if not is_instance_valid(commander):
		return
	var sszek := BattleUnitState.new(commander.character_id, commander.display_name, BattleUnitState.Side.PLAYER, 0, 9, commander.max_hp, commander.get_skills(), commander.power, commander.defense, commander.race_id)
	var primary := BattleUnitState.new(&"poison_primary", "Primary", BattleUnitState.Side.ENEMY, 0, 2, 20)
	var adjacent := BattleUnitState.new(&"poison_adjacent", "Adjacent", BattleUnitState.Side.ENEMY, 1, 1, 20)
	var source: RefCounted = BattleKeywordSource.create(sszek.unit_id, &"weakening_bite", sszek.power)
	primary.apply_poison(source, &"power", 1, 3)
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	arena.configure_units([sszek, primary, adjacent])
	var poison_delta := {
		&"kind": BattleKeywordOperation.Kind.APPLY_POISON,
		&"target_id": primary.unit_id,
		&"value": 1,
		&"from_reaction": false,
		&"poison_axis": &"power",
		&"source_unit_id": sszek.unit_id,
		&"was_reapplication": true,
	}
	var record := BattleActionRecord.new(
		BattleActionRecord.Kind.SKILL, sszek.unit_id, [primary.unit_id], {}, {}, {},
		1, 1, 1, sszek.side, &"weakening_bite", false, {}, [poison_delta]
	)
	var deltas: Array[Dictionary] = []
	arena.call("_dispatch_passive_reactions", record, 1, deltas)
	_expect(adjacent.get_poison_stacks(&"power", 1) == 1, "Cartographer spreads one same-axis Poison stack")
	arena.call("_dispatch_passive_reactions", record, 1, deltas)
	_expect(adjacent.get_poison_stacks(&"power", 1) == 1, "Cartographer cannot chain or repeat in the same round")
	arena.free()


func _test_save_reload() -> void:
	var identities: Array[StringName] = CLASS_IDS.duplicate()
	identities.append(&"sszek_still_mire")
	var probe: Script = load("res://Tests/Support/ac9_faction_round_trip_probe.gd") as Script
	var result: Dictionary = probe.verify(identities, "ac9-2-lizardman-round-trip")
	_expect(
		result.get("ok", false) and result.get("checked", 0) == 7,
		"Lizardman classes and commander survive save/reload: %s" % result.get("error", ""),
	)


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
