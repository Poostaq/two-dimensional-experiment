class_name TestAc94HarpiesIntegration
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
	_test_authored_harpy_skill_contracts()
	var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(&"kyris_windscar")
	_expect(is_instance_valid(commander), "Kyris commander constructs")
	if is_instance_valid(commander):
		var skills: Array[CharacterSkill] = commander.get_skills()
		_expect(commander.race_id == &"harpy" and skills.size() == 4, "Kyris preserves faction and four-skill loadout")
		_expect(skills[0].skill_id == &"raking_pass" and skills[3].skill_id == &"open_sky_command", "Kyris inherits Talon Duelist and appends signature")
		_test_open_sky_command(commander)
	_expect(RunCharacterCatalog.create_by_class_id(&"harpy_unknown") == null, "Harpy catalog rejects unknown IDs")
	_test_forced_target_movement()
	_test_save_reload()
	_finish()


func _test_authored_harpy_skill_contracts() -> void:
	var duelist: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_talon_duelist")
	if is_instance_valid(duelist):
		var skills: Array[CharacterSkill] = duelist.get_skills()
		_expect(skills[0].authored_effects[0].power_percent == 90 and skills[0].authored_effects[1].magnitude == 2, "Raking Pass authors 90 percent damage and Move 2")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].advantage_power_percent == 180, "Exploit Opening requires movement and upgrades to 180 with Advantage")
		_expect(skills[2].authored_effects[0].magnitude == 2 and skills[2].authored_effects[1].magnitude == 4, "Wingbeat Retreat authors Move 2 and Armor 4")
	var siren: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_storm_siren")
	if is_instance_valid(siren):
		var skills: Array[CharacterSkill] = siren.get_skills()
		_expect(skills[0].target_profile.target_sides == [BattleUnitState.Side.ENEMY, BattleUnitState.Side.PLAYER], "Gust Call selects enemy then ally")
		_expect(skills[0].authored_effects.size() == 2 and skills[0].authored_effects[1].target_role == BattleSkillEffectDefinition.TargetRole.SECONDARY, "Gust Call moves the enemy and grants the ally Advantage")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].magnitude == 2, "Crosswind Pull requires prior movement and moves the enemy 2")
		_expect(skills[2].authored_effects[0].magnitude == 3, "Eye of the Storm forces Move 3")
	var scout: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_gale_scout")
	if is_instance_valid(scout):
		var skills: Array[CharacterSkill] = scout.get_skills()
		_expect(skills[0].target_profile.target_sides == [BattleUnitState.Side.ENEMY, BattleUnitState.Side.PLAYER], "Spot the Straggler selects enemy then ally")
		_expect(skills[1].authored_effects[0].power_percent == 110 and skills[1].authored_effects[0].advantage_power_percent == 150, "Diving Signal authors 110 percent damage, upgraded to 150")
		_expect(skills[2].authored_effects[0].kind == BattleSkillEffectDefinition.Kind.FORCED_TARGET_MOVE and skills[2].authored_effects[0].magnitude == 2 and skills[2].authored_effects[1].magnitude == 2, "Updraft Reposition moves an ally 2 and grants Armor 2")
	var raider: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_skyhook_raider")
	if is_instance_valid(raider):
		var skills: Array[CharacterSkill] = raider.get_skills()
		_expect(skills[0].target_profile.target_sides == [BattleUnitState.Side.ENEMY, BattleUnitState.Side.PLAYER] and skills[0].authored_effects.size() == 2, "Hook and Lift moves an enemy and grants an ally Advantage")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].power_percent == 160 and skills[1].authored_effects[0].advantage_power_percent == 190, "Drop Out of Line gates on Move 2 and authors exact damage")
		_expect(skills[2].authored_effects[0].kind == BattleSkillEffectDefinition.Kind.FORCED_TARGET_MOVE and skills[2].authored_effects[0].magnitude == 3, "Snatch Away forces Move 3")
	var nestguard: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_nestguard")
	if is_instance_valid(nestguard):
		var skills: Array[CharacterSkill] = nestguard.get_skills()
		_expect(skills[0].target_profile.require_adjacent_lane and skills[0].authored_effects[0].magnitude == 4, "Covering Wings grants adjacent ally Armor 4")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].power_percent == 130 and skills[1].authored_effects[0].advantage_power_percent == 160, "Warning Screech enforces its retaliatory gate")
		_expect(skills[2].authored_effects.size() == 3 and skills[2].authored_effects[1].magnitude == 3 and skills[2].authored_effects[2].magnitude == 3, "Rescue Flight swaps and grants both units Armor 3")
	var cantor: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_carrion_cantor")
	if is_instance_valid(cantor):
		var skills: Array[CharacterSkill] = cantor.get_skills()
		_expect(skills[0].authored_effects[0].power_percent == 90 and skills[0].authored_effects[1].magnitude == 1, "Cutting Note deals 90 percent and forces Move 1")
		_expect(not skills[1].conditions.is_empty() and skills[1].authored_effects[0].power_percent == 110 and skills[1].authored_effects[1].duration == 2, "Rending Chorus requires movement and applies Bleed 2")
		_expect(skills[2].target_profile.maximum_targets == 2 and skills[2].authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.ALL_SELECTED and skills[2].authored_effects[1].magnitude == 3, "Funeral Spiral hits up to two Bleeding enemies while moving 3")


func _test_open_sky_command(commander: RunCharacter) -> void:
	var kyris := BattleUnitState.new(commander.character_id, commander.display_name, BattleUnitState.Side.PLAYER, 2, 10, commander.max_hp, commander.get_skills(), commander.power, commander.defense, commander.race_id)
	var ally_character: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_talon_duelist")
	var ally := BattleUnitState.new(&"open_sky_ally", "Open Sky Ally", BattleUnitState.Side.PLAYER, 0, 10, ally_character.max_hp, ally_character.get_skills(), ally_character.power, ally_character.defense, ally_character.race_id)
	var enemy := BattleUnitState.new(&"open_sky_enemy", "Open Sky Enemy", BattleUnitState.Side.ENEMY, 0, 1, 20)
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	arena.configure_units([kyris, ally, enemy])
	var record := BattleActionRecord.new(
		BattleActionRecord.Kind.SKILL, kyris.unit_id, [enemy.unit_id], {},
		{enemy.unit_id: 0}, {enemy.unit_id: 1}, 1, 1, 1, kyris.side,
		&"gust_command", false
	)
	var deltas: Array[Dictionary] = []
	arena.call("_dispatch_passive_reactions", record, 1, deltas)
	_expect(ally.has_method("has_pending_post_hit_move"), "Open Sky Command uses typed pending post-hit movement")
	if ally.has_method("has_pending_post_hit_move"):
		_expect(ally.call("has_pending_post_hit_move", 1), "Open Sky Command arms the deterministic lowest-slot ally")
		var damage_operation := {
			&"target_id": enemy.unit_id,
			&"base_damage": 1,
			&"combo_bonus_damage": 0,
			&"total_requested_damage": 1,
		}
		var targets: Array[StringName] = [enemy.unit_id]
		var damages: Array[Dictionary] = [damage_operation]
		var plan: SkillEffectPlan = SkillEffectPlan.create(
			ally.unit_id, ally.skills[0].skill_id, targets, damages, [], 0, true, 0
		)
		arena.set("_battle_revision", 0)
		var transaction: BattleSkillTransaction = arena.get("_skill_transaction")
		transaction.actor_id = ally.unit_id
		transaction.skill_id = ally.skills[0].skill_id
		var committed: bool = arena.call("_commit_skill_effect_plan", plan)
		_expect(committed and ally.slot_index == 1, "Armed ally moves 1 after its next direct hit")
		_expect(not ally.call("has_pending_post_hit_move", 1), "Post-hit movement is consumed by the direct hit")
	arena.free()


func _test_forced_target_movement() -> void:
	var has_effect_kind: bool = BattleSkillEffectDefinition.Kind.has("FORCED_TARGET_MOVE")
	_expect(has_effect_kind, "Harpy control skills expose typed forced target movement")
	if not has_effect_kind:
		return
	var siren: RunCharacter = RunCharacterCatalog.create_by_class_id(&"harpy_storm_siren")
	if not is_instance_valid(siren):
		return
	var gust_call: CharacterSkill = siren.get_skills()[0]
	var has_forced_move: bool = false
	for effect: RefCounted in gust_call.authored_effects:
		has_forced_move = has_forced_move or int(effect.kind) == int(BattleSkillEffectDefinition.Kind.get("FORCED_TARGET_MOVE"))
	_expect(has_forced_move, "Gust Call authors forced enemy Move 1")
	var actor := BattleUnitState.new(&"siren_actor", "Siren", BattleUnitState.Side.PLAYER, 0, 8, 17, siren.get_skills(), siren.power, siren.defense, siren.race_id)
	var target := BattleUnitState.new(&"forced_target", "Target", BattleUnitState.Side.ENEMY, 0, 1, 20)
	var ally := BattleUnitState.new(&"gust_ally", "Gust Ally", BattleUnitState.Side.PLAYER, 2, 5, 20)
	var units: Array[BattleUnitState] = [actor, ally, target]
	var validation: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(
		actor, gust_call, units, actor.unit_id, false, 1, [target.unit_id, ally.unit_id], 0, 0, [], [0, 1]
	)
	_expect(validation.accepted, "Gust Call accepts a legal declared target path")
	var stale: SkillConfirmationValidation = BattleSkillRules.validate_confirmation(
		actor, gust_call, units, actor.unit_id, false, 1, [target.unit_id, ally.unit_id], 0, 1, [], [0, 1]
	)
	_expect(not stale.accepted and target.slot_index == 0, "Stale forced movement rejects without mutation")
	if validation.accepted:
		_expect(validation.effect_plan.movement_unit_id == target.unit_id, "Forced movement plan owns the hostile target")
		var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
		root.add_child(arena)
		arena.configure_units(units)
		arena.set("_battle_revision", 0)
		var transaction: BattleSkillTransaction = arena.get("_skill_transaction")
		transaction.actor_id = actor.unit_id
		transaction.skill_id = gust_call.skill_id
		var committed: bool = arena.call("_commit_skill_effect_plan", validation.effect_plan)
		_expect(committed and target.slot_index == 1, "Forced movement commits to the enemy formation slot")
		_expect(ally.has_advantage(1), "Gust Call grants the selected ally Advantage")
		var records: Array[BattleActionRecord] = arena.call("get_action_records")
		_expect(not records.is_empty() and not records[-1].voluntary_movement, "Forced movement is recorded as hostile movement")
		arena.free()


func _test_save_reload() -> void:
	var identities: Array[StringName] = CLASS_IDS.duplicate()
	identities.append(&"kyris_windscar")
	var probe: Script = load("res://Tests/Support/ac9_faction_round_trip_probe.gd") as Script
	var result: Dictionary = probe.verify(identities, "ac9-4-harpy-round-trip")
	_expect(
		result.get("ok", false) and result.get("checked", 0) == 7,
		"Harpy classes and commander survive save/reload: %s" % result.get("error", ""),
	)


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
