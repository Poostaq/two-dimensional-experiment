class_name Ac9_1OrcsIntegrationTests
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
	var shield_ram: CharacterSkill = vanguard.get_skills()[1]
	_expect(shield_ram.authored_effects.size() == 2, "Shield Ram authors damage and forced Move 1")
	if shield_ram.authored_effects.size() == 2:
		_expect(shield_ram.authored_effects[0].power_percent == 100 and shield_ram.authored_effects[0].advantage_power_percent == 140, "Shield Ram uses the exact 100/140 damage bands")
		_expect(shield_ram.authored_effects[1].kind == BattleSkillEffectDefinition.Kind.FORCED_TARGET_MOVE and shield_ram.authored_effects[1].magnitude == 1, "Shield Ram rotates its target exactly one slot")
	var hold_the_gap: CharacterSkill = vanguard.get_skills()[2]
	_expect(hold_the_gap.authored_effects.size() == 2, "Hold the Gap grants Armor to the Vanguard and both adjacent allies")
	_expect(hold_the_gap.target_profile.require_adjacent_lane, "Hold the Gap requires adjacent allied selections")
	for effect: RefCounted in hold_the_gap.authored_effects:
		_expect(effect.keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and effect.magnitude == 5, "Hold the Gap grants five Armor per target")
	var reaver: RunCharacter = RunCharacterCatalog.create_by_class_id(&"orc_bonebreaker_reaver")
	var crushing_entry: CharacterSkill = reaver.get_skills()[0]
	_expect(crushing_entry.authored_effects.size() == 2 and crushing_entry.authored_effects[0].power_percent == 100 and crushing_entry.authored_effects[1].kind == BattleSkillEffectDefinition.Kind.FORCED_TARGET_MOVE, "Crushing Entry deals 100 percent and moves one")
	var break_formation: CharacterSkill = reaver.get_skills()[1]
	_expect(break_formation.authored_effects[0].power_percent == 150 and break_formation.authored_effects[0].advantage_power_percent == 180, "Break Formation uses exact 150/180 damage")
	_expect(not break_formation.conditions.is_empty(), "Break Formation requires moved-or-Stunned setup")
	var execution_swing: CharacterSkill = reaver.get_skills()[2]
	_expect(execution_swing.authored_effects[0].power_percent == 200 and execution_swing.authored_effects[0].ignore_armor, "Execution Swing deals 200 percent ignoring Armor")
	_expect(execution_swing.requirement == CharacterSkill.Requirement.FRONT_ROW and not execution_swing.conditions.is_empty(), "Execution Swing requires front row and wounded prey")
	var captain: RunCharacter = RunCharacterCatalog.create_by_class_id(&"orc_bloodbanner_captain")
	var plant_banner: CharacterSkill = captain.get_skills()[0]
	_expect(plant_banner.authored_effects.size() == 2 and plant_banner.authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.ACTOR and plant_banner.authored_effects[1].target_role == BattleSkillEffectDefinition.TargetRole.ALL_SELECTED, "Plant Banner grants three Armor to self and neighboring allies")
	for effect: RefCounted in plant_banner.authored_effects:
		_expect(effect.keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and effect.magnitude == 3, "Plant Banner grants exactly three Armor per recipient")
	var rally_strike: CharacterSkill = captain.get_skills()[1]
	_expect(rally_strike.authored_effects.size() == 2 and rally_strike.authored_effects[0].power_percent == 90, "Rally Strike authors its hit and allied Armor rider")
	if rally_strike.authored_effects.size() == 2:
		_expect(rally_strike.authored_effects[1].target_role == BattleSkillEffectDefinition.TargetRole.SECONDARY and rally_strike.authored_effects[1].magnitude == 3 and rally_strike.authored_effects[1].conditional_magnitude == 5, "Rally Strike grants the selected ally 3/5 Armor")
	var drummer: RunCharacter = RunCharacterCatalog.create_by_class_id(&"orc_war_drummer")
	var marching_beat: CharacterSkill = drummer.get_skills()[0]
	_expect(marching_beat.authored_effects.size() == 1 and marching_beat.authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.PRIMARY and marching_beat.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.APPLY_ADVANTAGE, "Marching Beat grants Advantage to one ally")
	var chainwarden: RunCharacter = RunCharacterCatalog.create_by_class_id(&"orc_chainwarden")
	var chain_lash: CharacterSkill = chainwarden.get_skills()[0]
	_expect(chain_lash.authored_effects.size() == 2 and chain_lash.authored_effects[0].power_percent == 70 and chain_lash.authored_effects[1].magnitude == 1, "Chain Lash deals 70 percent and moves one")
	var yank_back: CharacterSkill = chainwarden.get_skills()[1]
	_expect(yank_back.authored_effects.size() == 2 and yank_back.authored_effects[0].kind == BattleSkillEffectDefinition.Kind.FORCED_TARGET_MOVE and yank_back.authored_effects[0].magnitude == 2 and yank_back.authored_effects[1].power_percent == 100, "Yank Back moves two then deals 100 percent")
	_expect(not yank_back.conditions.is_empty(), "Yank Back requires prior movement")
	var lockdown: CharacterSkill = chainwarden.get_skills()[2]
	_expect(lockdown.authored_effects.size() == 1 and lockdown.authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.PRIMARY and lockdown.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.APPLY_STUN, "Lockdown applies canonical Stun")
	_expect(not lockdown.conditions.is_empty(), "Lockdown requires prior target movement")
	var crushing_cadence: CharacterSkill = drummer.get_skills()[1]
	_expect(crushing_cadence.authored_effects.size() == 1 and crushing_cadence.authored_effects[0].advantage_power_percent == 150, "Crushing Cadence has its 150 percent Advantage rider")
	var siegebreaker: RunCharacter = RunCharacterCatalog.create_by_class_id(&"orc_siegebreaker")
	var test_the_plate: CharacterSkill = siegebreaker.get_skills()[0]
	_expect(test_the_plate.authored_effects.size() == 1 and test_the_plate.authored_effects[0].power_percent == 110 and test_the_plate.authored_effects[0].armor_strip == 2, "Test the Plate strips two Armor then deals 110 percent Power")
	var crack_armor: CharacterSkill = siegebreaker.get_skills()[1]
	_expect(crack_armor.authored_effects.size() == 1 and crack_armor.authored_effects[0].power_percent == 140 and crack_armor.authored_effects[0].armor_strip == 3, "Crack Armor strips three Armor then deals 140 percent Power")
	_expect(crack_armor.authored_effects[0].advantage_armor_strip == 5, "Crack Armor Advantage rider strips up to five Armor")
	var demolishing_blow: CharacterSkill = siegebreaker.get_skills()[2]
	_expect(demolishing_blow.authored_effects.size() == 1 and demolishing_blow.authored_effects[0].power_percent == 210 and demolishing_blow.authored_effects[0].ignore_armor, "Demolishing Blow deals 210 percent Power ignoring Armor")
	var war_tempo: CharacterSkill = drummer.get_skills()[2]
	_expect(war_tempo.authored_effects.size() == 1 and war_tempo.authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.ALL_SELECTED and war_tempo.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and war_tempo.authored_effects[0].magnitude == 3, "War Tempo grants three Armor to all selected allies")
	var last_standard: CharacterSkill = captain.get_skills()[2]
	_expect(last_standard.authored_effects.size() == 1 and last_standard.authored_effects[0].target_role == BattleSkillEffectDefinition.TargetRole.ALL_SELECTED and last_standard.authored_effects[0].keyword_kind == BattleKeywordOperation.Kind.ADD_ARMOR and last_standard.authored_effects[0].magnitude == 5, "Last Standard grants five Armor to all selected allies")
	_test_behavioral_contracts(vanguard, reaver, captain, chainwarden, siegebreaker)
	var goruk: RunCharacter = RunCharacterCatalog.create_by_class_id(&"goruk_ironline")
	_expect(is_instance_valid(goruk), "Goruk commander constructs")
	if is_instance_valid(goruk):
		_expect(goruk.race_id == &"orc" and goruk.class_id == &"goruk_ironline", "Goruk preserves stable commander identity")
		var goruk_skills: Array[CharacterSkill] = goruk.get_skills()
		_expect(goruk_skills.size() == 4, "Goruk inherits three skills and appends one")
		if goruk_skills.size() == 4:
			_expect(goruk_skills[3].skill_id == &"iron_decree", "Goruk appends Iron Decree")
	_finish()


func _test_behavioral_contracts(
	vanguard: RunCharacter,
	reaver: RunCharacter,
	captain: RunCharacter,
	chainwarden: RunCharacter,
	siegebreaker: RunCharacter
) -> void:
	var target: BattleUnitState = BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 1, 5, 40, [], 4, 0)
	var ally: BattleUnitState = BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 1, 5, 30)
	var second_ally: BattleUnitState = BattleUnitState.new(&"second_ally", "Second Ally", BattleUnitState.Side.PLAYER, 3, 5, 30)
	var actor: BattleUnitState = BattleUnitState.new(&"vanguard", "Vanguard", BattleUnitState.Side.PLAYER, 0, 2, 30, vanguard.get_skills(), 5, 5)
	var source: RefCounted = BattleKeywordSource.create(actor.unit_id, &"setup", actor.power)
	target.apply_advantage(source, 1)
	var plan: SkillEffectPlan = BattleSkillAuthoringResolver.build_plan(actor, actor.skills[1], [target], [actor, ally, second_ally, target], 1, 0, [], [1, 0], [])
	_expect(is_instance_valid(plan), "Shield Ram builds a legal executable plan")
	if is_instance_valid(plan):
		_expect(plan.damage_operations[0][&"total_requested_damage"] == 7, "Shield Ram Advantage rider resolves at 140 percent")
		_expect(plan.movement_unit_id == target.unit_id and plan.movement_path == [1, 0], "Shield Ram locks the declared hostile Move 1 path")
	var reaver_actor: BattleUnitState = BattleUnitState.new(&"reaver", "Reaver", BattleUnitState.Side.PLAYER, 0, 4, 26, reaver.get_skills(), 8, 2)
	var break_skill: CharacterSkill = reaver_actor.skills[1]
	_expect(BattleSkillAuthoringResolver.build_plan(reaver_actor, break_skill, [target], [reaver_actor, target], 1, 0, [], [], []) == null, "Break Formation rejects without moved-or-Stunned setup")
	var move_records: Array[BattleActionRecord] = [BattleActionRecord.new(BattleActionRecord.Kind.SKILL, &"controller", [target.unit_id], {}, {target.unit_id: 1}, {target.unit_id: 0}, 1, 1, 1, BattleUnitState.Side.PLAYER, &"move", false)]
	_expect(is_instance_valid(BattleSkillAuthoringResolver.build_plan(reaver_actor, break_skill, [target], [reaver_actor, target], 1, 0, [], [], move_records)), "Break Formation accepts current-round movement evidence")
	var captain_actor: BattleUnitState = BattleUnitState.new(&"captain", "Captain", BattleUnitState.Side.PLAYER, 0, 3, 28, captain.get_skills(), 5, 4)
	plan = BattleSkillAuthoringResolver.build_plan(captain_actor, captain_actor.skills[1], [target, ally], [captain_actor, ally, target], 1, 0, [])
	_expect(is_instance_valid(plan) and plan.keyword_operations.size() == 1 and plan.keyword_operations[0].magnitude == 5, "Rally Strike Advantage rider grants five Armor to its ally")
	var last_standard: CharacterSkill = captain_actor.skills[2]
	_expect(BattleSkillAuthoringResolver.build_plan(captain_actor, last_standard, [captain_actor, ally, second_ally], [captain_actor, ally, second_ally, target], 1, 0, []) == null, "Last Standard rejects before two allies are wounded")
	ally.current_hp = 10
	second_ally.current_hp = 10
	_expect(is_instance_valid(BattleSkillAuthoringResolver.build_plan(captain_actor, last_standard, [captain_actor, ally, second_ally], [captain_actor, ally, second_ally, target], 1, 0, [])), "Last Standard accepts exactly two wounded allies")
	var chain_actor: BattleUnitState = BattleUnitState.new(&"chain", "Chain", BattleUnitState.Side.PLAYER, 0, 4, 27, chainwarden.get_skills(), 4, 4)
	_expect(BattleSkillAuthoringResolver.build_plan(chain_actor, chain_actor.skills[1], [target], [chain_actor, target], 1, 0, [], [1, 0, 3], []) == null, "Yank Back rejects without prior movement")
	var siege_actor: BattleUnitState = BattleUnitState.new(&"siege", "Siege", BattleUnitState.Side.PLAYER, 0, 2, 25, siegebreaker.get_skills(), 8, 3)
	var armor_records: Array[BattleActionRecord] = [BattleActionRecord.new(BattleActionRecord.Kind.SKILL, &"breaker", [target.unit_id], {}, {}, {}, 1, 1, 1, BattleUnitState.Side.PLAYER, &"strip", true, {}, [{&"target_id": target.unit_id, &"kind": BattleKeywordOperation.Kind.ADD_ARMOR, &"value": -3}])]
	plan = BattleSkillAuthoringResolver.build_plan(siege_actor, siege_actor.skills[1], [target], [siege_actor, target], 1, 0, [], [], armor_records)
	_expect(is_instance_valid(plan) and plan.damage_operations[0][&"armor_strip"] == 5 and plan.consume_advantage, "Crack Armor consumes Advantage to strip five Armor")

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
