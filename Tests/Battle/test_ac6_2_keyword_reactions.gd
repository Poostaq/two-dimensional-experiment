class_name Ac6_2KeywordReactionTests
extends SceneTree

const SOURCE_PATH: String = "res://Scripts/Battle/battle_keyword_source.gd"
const BLEED_PATH: String = "res://Scripts/Battle/battle_bleed_state.gd"
const UNIT_STATE_PATH: String = "res://Scripts/Battle/battle_unit_state.gd"
const OPERATION_PATH: String = "res://Scripts/Battle/battle_keyword_operation.gd"
const HISTORY_QUERY_PATH: String = "res://Scripts/Battle/battle_history_query.gd"
const REACTION_DEFINITION_PATH: String = "res://Scripts/Battle/battle_reaction_definition.gd"
const REACTION_DISPATCHER_PATH: String = "res://Scripts/Battle/battle_reaction_dispatcher.gd"
const ARENA_PATH: String = "res://Scenes/battle_arena.tscn"
const EXPECTED_TEST_COUNT: int = 113

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_keyword_value_objects()
	_test_battle_local_keyword_state()
	_test_armor_aware_damage_results()
	_test_keyword_operation_contract()
	_test_keyword_skill_and_plan_contract()
	_test_history_query_contract()
	_test_passive_reaction_dispatch_contract()
	await _test_arena_ordered_keyword_lifecycle()
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC6.2 keyword reactions: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_keyword_value_objects() -> void:
	_expect(ResourceLoader.exists(SOURCE_PATH), "keyword source script exists")
	_expect(ResourceLoader.exists(BLEED_PATH), "Bleed state script exists")
	if not ResourceLoader.exists(SOURCE_PATH) or not ResourceLoader.exists(BLEED_PATH):
		return
	var source_script := load(SOURCE_PATH) as Script
	var bleed_script := load(BLEED_PATH) as Script
	var source: RefCounted = source_script.call("create", &"shivrunner", &"rusted_cut", 7)
	_expect(source != null and source.call("is_valid"), "keyword source is valid")
	_expect(source_script.call("create", &"", &"rusted_cut", 7) == null, "empty source unit is rejected")
	_expect(source_script.call("create", &"shivrunner", &"", 7) == null, "empty source skill is rejected")
	_expect(source_script.call("create", &"shivrunner", &"rusted_cut", 0) == null, "Power below one is rejected")
	var bleed: RefCounted = bleed_script.call("create", source, 1, 2)
	_expect(bleed != null and bleed.call("is_valid"), "Bleed state is valid")
	_expect(bleed_script.call("create", source, 0, 2) == null, "Bleed rejects zero stacks")
	_expect(bleed_script.call("create", source, 4, 2) == null, "Bleed rejects stacks above cap")
	_expect(bleed_script.call("create", source, 1, 0) == null, "Bleed rejects zero duration")
	_expect(bleed.call("add_application", source, 2), "same source can reapply")
	_expect(bleed.get("stacks") == 2 and bleed.get("remaining_actions") == 2, "Bleed adds and refreshes")
	_expect(bleed.call("tick_damage") == 4, "Bleed uses snapshot Power per stack")


func _test_battle_local_keyword_state() -> void:
	_expect(ResourceLoader.exists(UNIT_STATE_PATH), "battle unit state script exists")
	if not ResourceLoader.exists(UNIT_STATE_PATH):
		return
	var skill := CharacterSkill.create(
		&"knife_work",
		"Knife Work",
		CharacterSkill.Kind.ACTIVE,
		"Deal damage.",
		"One enemy.",
		"None.",
		"Two actions.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		3,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		2
	)
	_expect(skill != null, "unit test skill is valid")
	var unit := BattleUnitState.new(
		&"scout",
		"Scout",
		BattleUnitState.Side.PLAYER,
		0,
		5,
		20,
		[skill],
		8,
		1
	)
	_expect(unit.is_active(), "unit state fixture is active")
	var required_methods: Array[StringName] = [
		&"add_armor",
		&"spend_armor",
		&"get_armor",
		&"apply_advantage",
		&"has_advantage",
		&"consume_advantage",
		&"apply_snared",
		&"is_snared",
		&"apply_bleed",
		&"resolve_bleed_after_committed_action",
		&"get_bleed_snapshot",
		&"reduce_skill_cooldown",
		&"clear_round_keywords",
		&"clear_battle_local_state",
	]
	var missing_api := false
	for method_name: StringName in required_methods:
		var has_api := unit.has_method(method_name)
		_expect(has_api, "BattleUnitState exposes %s" % method_name)
		missing_api = missing_api or not has_api
	if missing_api:
		return
	var source_script := load(SOURCE_PATH) as Script
	var source_a: RefCounted = source_script.call("create", &"raider", &"rusted_cut", 7)
	var source_b: RefCounted = source_script.call("create", &"trapper", &"barbed_hook", 9)
	_expect(unit.add_armor(7) == 7 and unit.get_armor() == 7, "Armor adds applied amount")
	_expect(unit.add_armor(8) == 3 and unit.get_armor() == 10, "Armor caps at ten")
	_expect(unit.spend_armor(4) == 4 and unit.get_armor() == 6, "Armor spends partial prevention")
	_expect(unit.spend_armor(20) == 6 and unit.get_armor() == 0, "Armor spends no more than stored")
	_expect(unit.apply_advantage(source_a, 2) and unit.has_advantage(1), "Advantage applies until expiry")
	var consumed_advantage: RefCounted = null
	unit.apply_advantage(source_b, 3)
	consumed_advantage = unit.consume_advantage(2)
	_expect(consumed_advantage != null and consumed_advantage.get("source_unit_id") == &"trapper" and not unit.has_advantage(2), "Advantage replaces and consumes")
	unit.apply_advantage(source_a, 1)
	unit.clear_round_keywords(1)
	_expect(not unit.has_advantage(2), "Advantage expires after completed round")
	_expect(unit.apply_snared(source_a, 2) and unit.is_snared(1), "Snared applies until expiry")
	unit.apply_snared(source_b, 3)
	_expect(unit.is_snared(3), "Snared refreshes to the later round")
	unit.clear_round_keywords(3)
	_expect(not unit.is_snared(4), "Snared expires after completed round")
	unit.apply_bleed(source_a, 2)
	unit.apply_bleed(source_b, 2)
	unit.apply_bleed(source_a, 2)
	var bleed_ticks: Array[RefCounted] = unit.resolve_bleed_after_committed_action()
	_expect(bleed_ticks.size() == 2, "Bleed keeps distinct source entries")
	_expect(_has_bleed_tick(bleed_ticks, &"raider", 2, 4) and _has_bleed_tick(bleed_ticks, &"trapper", 1, 2), "Bleed ticks use source stacks and Power")
	unit.resolve_bleed_after_committed_action()
	_expect(unit.resolve_bleed_after_committed_action().is_empty(), "Bleed entries expire after affected actions")
	unit.add_speed_modifier(&"mud", -50, BattleUnitState.ModifierExpiry.NEXT_ACTION, 1)
	_expect(unit.get_effective_speed() == 1, "temporary Speed cannot fall below one")
	unit.expire_speed_modifiers_after_action()
	_expect(unit.get_effective_speed() == unit.get_base_speed(), "temporary Speed expires after action")
	_expect(unit.set_skill_cooldown(&"knife_work", 3), "cooldown fixture starts")
	_expect(unit.reduce_skill_cooldown(&"knife_work", 2) == 1, "cooldown reduction subtracts actions")
	_expect(unit.reduce_skill_cooldown(&"knife_work", 10) == 0 and unit.get_skill_cooldown(&"knife_work") == 0, "cooldown reduction floors at zero")
	unit.add_armor(5)
	unit.apply_advantage(source_a, 4)
	unit.apply_snared(source_a, 4)
	unit.apply_bleed(source_a, 2)
	unit.add_speed_modifier(&"dash", 2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1, 1)
	unit.set_skill_cooldown(&"knife_work", 2)
	unit.clear_battle_local_state()
	_expect(unit.unit_id == &"scout" and unit.power == 8 and unit.get_base_speed() == 5 and unit.skills.size() == 1, "battle cleanup preserves identity, stats, and skills")
	_expect(unit.get_armor() == 0 and not unit.has_advantage(4) and not unit.is_snared(4) and unit.get_skill_cooldown(&"knife_work") == 0 and unit.get_effective_speed() == 5 and unit.get_bleed_snapshot().is_empty(), "battle cleanup removes local keyword state")


func _test_passive_reaction_dispatch_contract() -> void:
	_expect(ResourceLoader.exists(REACTION_DEFINITION_PATH), "reaction definition script exists")
	_expect(ResourceLoader.exists(REACTION_DISPATCHER_PATH), "reaction dispatcher script exists")
	if not ResourceLoader.exists(REACTION_DEFINITION_PATH) or not ResourceLoader.exists(REACTION_DISPATCHER_PATH):
		return
	var definition_script := load(REACTION_DEFINITION_PATH) as Script
	var dispatcher_script := load(REACTION_DISPATCHER_PATH) as Script
	var operation_script := load(OPERATION_PATH) as Script
	var skill_script := load("res://Scripts/Battle/character_skill.gd") as Script
	var operation: RefCounted = operation_script.call("create", 0, &"ally", 2, 1, null, &"")
	var high_priority: RefCounted = definition_script.call("create", &"guard_high", 0, 0, 5, operation, false)
	var low_priority: RefCounted = definition_script.call("create", &"guard_low", 0, 0, 1, operation, false)
	_expect(high_priority != null and low_priority != null, "reaction definitions validate synthetic Passives")
	_expect(definition_script.call("create", &"", 0, 0, 1, operation, false) == null, "reaction definitions reject empty passive skill IDs")
	var high_skill: CharacterSkill = skill_script.call("create", &"guard_high", "Guard High", CharacterSkill.Kind.PASSIVE, "React.", "Self.", "None.", "None.", -1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0, null, _ref_array([]), null, high_priority)
	var low_skill: CharacterSkill = skill_script.call("create", &"guard_low", "Guard Low", CharacterSkill.Kind.PASSIVE, "React.", "Self.", "None.", "None.", -1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0, null, _ref_array([]), null, low_priority)
	_expect(high_skill != null and low_skill != null, "Passive skills accept reaction definitions")
	var defender_a := BattleUnitState.new(&"defender_a", "Defender A", BattleUnitState.Side.PLAYER, 1, 5, 20, [high_skill])
	var defender_b := BattleUnitState.new(&"defender_b", "Defender B", BattleUnitState.Side.PLAYER, 0, 5, 20, [low_skill])
	var defeated := BattleUnitState.new(&"defeated", "Defeated", BattleUnitState.Side.PLAYER, 2, 5, 20, [low_skill])
	defeated.current_hp = 0
	var trigger := BattleActionRecord.new(BattleActionRecord.Kind.SKILL, &"enemy", _id_array([&"target"]), _int_dictionary({&"target": 3}), _int_dictionary({}), _int_dictionary({}), 1, 10, 10, BattleUnitState.Side.ENEMY, &"strike", false, _bool_dictionary({&"target": true}))
	var reactions: Array[RefCounted] = dispatcher_script.call("collect_reactions", trigger, _unit_array([defender_a, defender_b, defeated]), 1, 0)
	_expect(reactions.size() == 2, "dispatcher rejects inactive owners")
	_expect(reactions[0].get("owner_unit_id") == &"defender_b" and reactions[1].get("owner_unit_id") == &"defender_a", "dispatcher orders by priority then formation")
	var self_trigger := BattleActionRecord.new(BattleActionRecord.Kind.SKILL, &"defender_a", _id_array([&"target"]), _int_dictionary({&"target": 3}), _int_dictionary({}), _int_dictionary({}), 1, 11, 11, BattleUnitState.Side.PLAYER, &"strike", false, _bool_dictionary({&"target": true}))
	_expect(dispatcher_script.call("collect_reactions", self_trigger, _unit_array([defender_a]), 1, 0).is_empty(), "dispatcher prevents self-triggered reactions")
	_expect(dispatcher_script.call("collect_reactions", trigger, _unit_array([defender_a]), 1, 0).is_empty(), "once-per-action guard prevents duplicate dispatch")
	defender_a.clear_battle_local_state()
	_expect(dispatcher_script.call("collect_reactions", trigger, _unit_array([defender_a]), 1, 2).is_empty(), "dispatcher blocks undeclared reaction chains")


func _test_arena_ordered_keyword_lifecycle() -> void:
	var arena := await _instantiate_arena()
	_expect(arena != null, "arena fixture instantiates for AC6.2 transaction coverage")
	if arena == null:
		return
	var source_script := load(SOURCE_PATH) as Script
	var operation_script := load(OPERATION_PATH) as Script
	var definition_script := load(REACTION_DEFINITION_PATH) as Script
	var pre_source: RefCounted = source_script.call("create", &"marker", &"marked_target", 10)
	var actor_source: RefCounted = source_script.call("create", &"actor", &"goblin_combo", 8)
	var advantage_rider: RefCounted = operation_script.call("create", 0, &"actor", 2, 0, null, &"")
	var post_advantage: RefCounted = operation_script.call("create", 1, &"target", 0, 1, actor_source, &"")
	var post_snare: RefCounted = operation_script.call("create", 2, &"target", 0, 1, actor_source, &"")
	var post_bleed: RefCounted = operation_script.call("create", 3, &"target", 0, 2, actor_source, &"")
	var cooldown_cut: RefCounted = operation_script.call("create", 4, &"actor", 2, 0, null, &"backup")
	var passive_armor: RefCounted = operation_script.call("create", 0, &"guard", 2, 0, null, &"")
	var reaction: RefCounted = definition_script.call("create", &"watcher", 0, 0, 1, passive_armor, false)
	var combo := CharacterSkill.create(
		&"goblin_combo", "Goblin Combo", CharacterSkill.Kind.ACTIVE,
		"Deal damage and apply keywords.", "One enemy.", "None.", "Two actions.",
		CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE, 8, 0, CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS, 2, 0, null,
		_ref_array([post_advantage, post_snare, post_bleed, cooldown_cut]), advantage_rider
	)
	var backup := CharacterSkill.create(
		&"backup", "Backup", CharacterSkill.Kind.ACTIVE,
		"Fallback.", "One enemy.", "None.", "None.",
		CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE, 1, 0, CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE, 0
	)
	var watcher := CharacterSkill.create(
		&"watcher", "Watcher", CharacterSkill.Kind.PASSIVE,
		"React.", "Self.", "None.", "None.",
		-1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0,
		CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0,
		null, _ref_array([]), null, reaction
	)
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 8, 20, [combo, backup], 8, 0)
	var guard := BattleUnitState.new(&"guard", "Guard", BattleUnitState.Side.PLAYER, 1, 4, 20, [watcher], 5, 0)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 4, 0)
	var enemy_late := BattleUnitState.new(&"enemy_late", "Enemy Late", BattleUnitState.Side.ENEMY, 1, 1, 20, [], 1, 0)
	target.add_armor(3)
	target.apply_advantage(pre_source, 1)
	target.apply_bleed(pre_source, 2)
	actor.set_skill_cooldown(&"backup", 3)
	arena.configure_units([actor, guard, target, enemy_late])
	arena.begin_skill_action(&"actor", &"goblin_combo")
	arena.select_skill_target(&"target")
	var committed: bool = arena.confirm_skill_action()
	var records: Array[BattleActionRecord] = arena.get_action_records()
	_expect(committed, "arena commits a valid AC6.2 keyword transaction")
	_expect(target.get_armor() == 0 and target.current_hp == 11, "arena resolves Armor direct damage before Bleed ticks")
	_expect(actor.get_armor() == 2, "arena consumes pre-existing Advantage and applies its rider")
	_expect(target.has_advantage(1), "post-hit Advantage remains for later actions")
	_expect(target.is_snared(1), "post-hit Snared applies after damage")
	_expect(target.get_bleed_snapshot().size() == 2, "distinct Bleed sources remain after their first affected action tick")
	_expect(actor.get_skill_cooldown(&"backup") == 0, "keyword cooldown reduction combines with the committed-action cooldown tick")
	_expect(guard.get_armor() == 2, "Passive reaction operation applies deterministically")
	_expect(records.size() == 1, "arena appends one authoritative record for the transaction")
	if not records.is_empty():
		var record := records[0]
		_expect(record.source_skill_id == &"goblin_combo" and record.direct_hit_by_target.get(&"target", false), "arena record includes source skill and direct-hit metadata")
		_expect(record.advantage_consumed != null and record.advantage_consumed.get("source_unit_id") == &"marker", "arena record captures consumed Advantage source")
		_expect(record.keyword_deltas.size() >= 5, "arena record captures keyword and reaction deltas")
		_expect(record.bleed_ticks.size() == 2, "arena record captures affected-unit Bleed ticks")
	var stale_hp: int = target.current_hp
	var stale_armor: int = target.get_armor()
	var stale_revision: int = arena.get_battle_revision()
	arena.begin_skill_action(&"guard", &"watcher")
	arena.notify_authoritative_battle_change()
	var stale_committed: bool = arena.confirm_skill_action()
	_expect(not stale_committed, "stale or rejected actions do not commit")
	_expect(target.current_hp == stale_hp and target.get_armor() == stale_armor and arena.get_battle_revision() == stale_revision + 1, "stale rejection changes no combat state beyond the explicit revision bump")
	arena.advance_turn()
	arena.advance_turn()
	arena.advance_turn()
	_expect(not target.has_advantage(2) and not target.is_snared(2), "round cleanup expires Advantage and Snared")
	arena.queue_free()
	await process_frame
	var cleanup_arena := await _instantiate_arena()
	var finisher := CharacterSkill.create(
		&"finish", "Finish", CharacterSkill.Kind.ACTIVE,
		"Finish.", "One enemy.", "None.", "None.",
		CharacterSkill.TargetingMode.FREE, CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE, CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE, 8, 0, CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE, 0
	)
	var cleanup_actor := BattleUnitState.new(&"cleanup_actor", "Cleanup Actor", BattleUnitState.Side.PLAYER, 0, 8, 20, [finisher], 8, 0)
	var cleanup_enemy := BattleUnitState.new(&"cleanup_enemy", "Cleanup Enemy", BattleUnitState.Side.ENEMY, 0, 1, 3, [], 1, 0)
	cleanup_enemy.add_armor(1)
	cleanup_enemy.apply_bleed(pre_source, 2)
	cleanup_arena.configure_units([cleanup_actor, cleanup_enemy])
	cleanup_arena.begin_skill_action(&"cleanup_actor", &"finish")
	cleanup_arena.select_skill_target(&"cleanup_enemy")
	var killed: bool = cleanup_arena.confirm_skill_action()
	_expect(killed and cleanup_arena.is_battle_complete(), "battle completion resolves immediately after defeat")
	_expect(cleanup_actor.get_armor() == 0 and cleanup_enemy.get_armor() == 0 and cleanup_enemy.get_bleed_snapshot().is_empty(), "battle teardown clears local keyword state")
	cleanup_arena.queue_free()
	await process_frame


func _test_history_query_contract() -> void:
	_expect(ResourceLoader.exists(HISTORY_QUERY_PATH), "history query script exists")
	if not ResourceLoader.exists(HISTORY_QUERY_PATH):
		return
	var query_script := load(HISTORY_QUERY_PATH) as Script
	var record_script := load("res://Scripts/Battle/battle_action_record.gd") as Script
	var forced: BattleActionRecord = record_script.call("new",
		BattleActionRecord.Kind.SKILL,
		&"mover",
		_id_array([&"target"]),
		_int_dictionary({}),
		_int_dictionary({&"target": 0}),
		_int_dictionary({&"target": 3}),
		1,
		2,
		2,
		BattleUnitState.Side.ENEMY,
		&"barbed_hook",
		false,
		_bool_dictionary({}),
		_dictionary_array([]),
		null,
		_ref_array([]),
		false
	)
	var voluntary: BattleActionRecord = record_script.call("new",
		BattleActionRecord.Kind.FORMATION_MOVE,
		&"target",
		_id_array([]),
		_int_dictionary({}),
		_int_dictionary({&"target": 3}),
		_int_dictionary({&"target": 4}),
		1,
		3,
		3,
		BattleUnitState.Side.PLAYER,
		&"formation_move",
		true
	)
	var first_hit: BattleActionRecord = _single_target_record(record_script, BattleActionRecord.Kind.SKILL, &"ally_a", &"target", 2, 4, BattleUnitState.Side.PLAYER, &"strike", true)
	var duplicate_hit: BattleActionRecord = _single_target_record(record_script, BattleActionRecord.Kind.SKILL, &"ally_a", &"target", 2, 5, BattleUnitState.Side.PLAYER, &"strike", true)
	var second_hit: BattleActionRecord = _single_target_record(record_script, BattleActionRecord.Kind.DEFAULT_ATTACK, &"ally_b", &"target", 1, 6, BattleUnitState.Side.PLAYER, &"default_attack", true)
	var status_tick: BattleActionRecord = _single_target_record(record_script, BattleActionRecord.Kind.SKILL, &"ally_c", &"target", 1, 7, BattleUnitState.Side.PLAYER, &"bleed", false)
	var enemy_hit: BattleActionRecord = _single_target_record(record_script, BattleActionRecord.Kind.SKILL, &"enemy", &"target", 1, 8, BattleUnitState.Side.ENEMY, &"strike", true)
	var records: Array[BattleActionRecord] = [forced, voluntary, first_hit, duplicate_hit, second_hit, status_tick, enemy_hit]
	_expect(query_script.call("was_forced_moved_since", records, &"target", 1), "forced movement is found")
	_expect(not query_script.call("was_forced_moved_since", records, &"target", 2), "history queries exclude records at the marker")
	_expect(not query_script.call("was_forced_moved_since", _record_array([voluntary]), &"target", 1), "voluntary movement is not forced movement")
	var attackers: Array[StringName] = query_script.call("distinct_allied_attackers", records, BattleUnitState.Side.PLAYER, &"target", 3)
	_expect(attackers.size() == 2, "distinct attackers are unique")
	_expect(attackers.has(&"ally_a") and attackers.has(&"ally_b"), "distinct attackers include direct-hit allies")
	_expect(not attackers.has(&"ally_c") and not attackers.has(&"enemy"), "distinct attackers exclude status ticks and enemies")
	var duplicate: RefCounted = forced.duplicate_record()
	_expect(duplicate.get("source_skill_id") == &"barbed_hook" and not duplicate.get("voluntary_movement"), "action record duplicates history metadata")
	_expect(forced.is_valid() and duplicate.is_valid(), "extended action records remain valid")


func _test_keyword_skill_and_plan_contract() -> void:
	if not ResourceLoader.exists(OPERATION_PATH):
		return
	var operation_script := load(OPERATION_PATH) as Script
	var source_script := load(SOURCE_PATH) as Script
	var skill_script := load("res://Scripts/Battle/character_skill.gd") as Script
	var plan_script := load("res://Scripts/Battle/skill_effect_plan.gd") as Script
	var skill_accepts_keywords := _script_method_min_arg_count(skill_script, &"create") >= 21
	var plan_accepts_keywords := _script_method_min_arg_count(plan_script, &"create") >= 11
	_expect(skill_accepts_keywords, "skills expose keyword-operation create arguments")
	_expect(plan_accepts_keywords, "plans expose keyword-operation create arguments")
	if not skill_accepts_keywords or not plan_accepts_keywords:
		return
	var source: RefCounted = source_script.call("create", &"actor", &"knife_work", 6)
	var armor: RefCounted = operation_script.call("create", 0, &"target", 3, 1, null, &"")
	var bleed: RefCounted = operation_script.call("create", 3, &"target", 0, 2, source, &"")
	var skill: CharacterSkill = skill_script.call(
		"create",
		&"knife_work",
		"Knife Work",
		CharacterSkill.Kind.ACTIVE,
		"Deal damage and keywords.",
		"One enemy.",
		"None.",
		"Two actions.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		3,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.POST_USE_ACTIONS,
		2,
		0,
		null,
		_ref_array([armor, bleed]),
		null
	)
	_expect(skill != null, "skills accept authored keyword operations")
	if skill == null:
		return
	var keyword_operations: Array = skill.get("keyword_operations")
	keyword_operations.clear()
	_expect(skill.get("keyword_operations").size() == 2, "skill keyword operations are defensive copies")
	var duplicate: CharacterSkill = skill.duplicate_skill()
	_expect(duplicate.get("keyword_operations").size() == 2, "skill duplication preserves keyword operations")
	var invalid_skill: CharacterSkill = skill_script.call(
		"create",
		&"bad_keywords",
		"Bad Keywords",
		CharacterSkill.Kind.ACTIVE,
		"Bad.",
		"One enemy.",
		"None.",
		"None.",
		CharacterSkill.TargetingMode.FREE,
		CharacterSkill.TargetSide.ENEMY,
		CharacterSkill.TargetRule.SELECT_ONE,
		CharacterSkill.Requirement.NONE,
		CharacterSkill.Effect.DAMAGE,
		1,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		null,
		_ref_array([null]),
		null
	)
	_expect(invalid_skill == null, "skills reject invalid keyword operations")
	var plan: SkillEffectPlan = plan_script.call(
		"create",
		&"actor",
		&"knife_work",
		_id_array([&"target"]),
		_dictionary_array([]),
		_dictionary_array([]),
		2,
		true,
		7,
		_ref_array([armor, bleed]),
		null,
		null
	)
	_expect(plan != null, "plans accept ordered keyword operations")
	if plan == null:
		return
	var plan_operations: Array = plan.get("keyword_operations")
	plan_operations.clear()
	_expect(plan.get("keyword_operations").size() == 2, "plan keyword operations are defensive copies")
	_expect(plan_script.call("create", &"actor", &"knife_work", _id_array([&"target"]), _dictionary_array([]), _dictionary_array([]), 2, true, 7, _ref_array([armor, armor]), null, null) == null, "plans reject duplicate keyword operations")
	var off_target: RefCounted = operation_script.call("create", 0, &"other", 3, 1, null, &"")
	_expect(plan_script.call("create", &"actor", &"knife_work", _id_array([&"target"]), _dictionary_array([]), _dictionary_array([]), 2, true, 7, _ref_array([off_target]), null, null) == null, "plans reject keyword operations outside targets")
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 8, 20, [skill], 6, 0)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	var validation := BattleSkillRules.validate_confirmation(actor, skill, [actor, target], actor.unit_id, false, 1, [&"target"], 3, 3, [])
	_expect(validation.effect_plan != null and validation.effect_plan.get("keyword_operations").size() == 2, "skill confirmation carries keyword operations into the plan")


func _test_keyword_operation_contract() -> void:
	_expect(ResourceLoader.exists(OPERATION_PATH), "keyword operation script exists")
	if not ResourceLoader.exists(OPERATION_PATH):
		return
	var operation_script := load(OPERATION_PATH) as Script
	var armor: RefCounted = operation_script.call("create", 0, &"target", 3, 1, null, &"")
	var cooldown: RefCounted = operation_script.call("create", 4, &"actor", 2, 0, null, &"knife_work")
	_expect(armor != null and armor.get("target_id") == &"target" and armor.get("magnitude") == 3, "keyword operation stores target and magnitude")
	_expect(cooldown != null and cooldown.get("affected_skill_id") == &"knife_work", "cooldown operation stores affected skill")
	_expect(operation_script.call("create", 0, &"", 3, 1, null, &"") == null, "keyword operation rejects empty target")
	_expect(operation_script.call("create", 4, &"actor", 2, 0, null, &"") == null, "cooldown operation rejects empty affected skill")


func _test_armor_aware_damage_results() -> void:
	var resolver_script := load("res://Scripts/Battle/battle_damage_resolver.gd") as Script
	var has_direct := _script_has_static_method(resolver_script, &"apply_direct_damage")
	var has_status := _script_has_static_method(resolver_script, &"apply_status_damage")
	_expect(has_direct, "damage resolver exposes direct damage")
	_expect(has_status, "damage resolver exposes status damage")
	if not has_direct or not has_status:
		return
	var attacker := BattleUnitState.new(&"attacker", "Attacker", BattleUnitState.Side.PLAYER, 0, 8, 20, [], 6, 0)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	target.add_armor(3)
	var partial: RefCounted = resolver_script.call("apply_direct_damage", attacker, target, 5)
	_expect(partial.get("requested_damage") == 5, "direct result keeps post-Defense request")
	_expect(partial.get("armor_prevented") == 3, "Armor prevents direct damage first")
	_expect(partial.get("applied_damage") == 2 and target.current_hp == 18 and target.get_armor() == 0, "direct damage applies after Armor")
	_expect(partial.get("was_direct_hit") and not partial.get("is_status_damage"), "direct hit classification survives absorption")
	target = BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	target.add_armor(10)
	var absorbed: RefCounted = resolver_script.call("apply_direct_damage", attacker, target, 4)
	_expect(absorbed.get("applied_damage") == 0 and absorbed.get("armor_prevented") == 4 and target.current_hp == 20 and target.get_armor() == 6 and absorbed.get("was_direct_hit"), "fully absorbed direct damage still counts as a hit")
	target.current_hp = 3
	var overkill: RefCounted = resolver_script.call("apply_direct_damage", attacker, target, 10)
	_expect(overkill.get("armor_prevented") == 6 and overkill.get("applied_damage") == 3 and target.current_hp == 0 and overkill.get("caused_defeat"), "overkill reports actual HP loss after Armor")
	target = BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	target.current_hp = 10
	target.add_armor(5)
	var status: RefCounted = resolver_script.call("apply_status_damage", attacker, target, 4)
	_expect(status.get("applied_damage") == 4 and target.current_hp == 6 and target.get_armor() == 5 and status.get("is_status_damage") and not status.get("was_direct_hit"), "status damage bypasses Armor")


func _instantiate_arena() -> BattleArena:
	var packed := load(ARENA_PATH) as PackedScene
	if packed == null:
		return null
	var arena := packed.instantiate() as BattleArena
	if is_instance_valid(arena):
		root.add_child(arena)
		await process_frame
	return arena


func _single_target_record(
	record_script: Script,
	kind: BattleActionRecord.Kind,
	actor_id: StringName,
	target_id: StringName,
	damage: int,
	revision: int,
	actor_side: BattleUnitState.Side,
	source_skill_id: StringName,
	is_direct_hit: bool
) -> BattleActionRecord:
	var damage_by_target: Dictionary[StringName, int] = {}
	damage_by_target[target_id] = damage
	var direct_hit_by_target: Dictionary[StringName, bool] = {}
	direct_hit_by_target[target_id] = is_direct_hit
	return record_script.call("new", kind, actor_id, _id_array([target_id]), damage_by_target, _int_dictionary({}), _int_dictionary({}), 1, revision, revision, actor_side, source_skill_id, false, direct_hit_by_target)


func _id_array(values: Array) -> Array[StringName]:
	var typed: Array[StringName] = []
	for value: Variant in values:
		typed.append(StringName(value))
	return typed


func _ref_array(values: Array) -> Array[RefCounted]:
	var typed: Array[RefCounted] = []
	for value: Variant in values:
		typed.append(value as RefCounted)
	return typed


func _unit_array(values: Array) -> Array[BattleUnitState]:
	var typed: Array[BattleUnitState] = []
	for value: Variant in values:
		typed.append(value as BattleUnitState)
	return typed


func _record_array(values: Array) -> Array[BattleActionRecord]:
	var typed: Array[BattleActionRecord] = []
	for value: Variant in values:
		typed.append(value as BattleActionRecord)
	return typed


func _dictionary_array(values: Array) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	for value: Variant in values:
		typed.append(value as Dictionary)
	return typed


func _int_dictionary(values: Dictionary) -> Dictionary[StringName, int]:
	var typed: Dictionary[StringName, int] = {}
	for key: Variant in values:
		typed[StringName(key)] = int(values[key])
	return typed


func _bool_dictionary(values: Dictionary) -> Dictionary[StringName, bool]:
	var typed: Dictionary[StringName, bool] = {}
	for key: Variant in values:
		typed[StringName(key)] = bool(values[key])
	return typed


func _script_method_min_arg_count(script: Script, method_name: StringName) -> int:
	if not is_instance_valid(script):
		return -1
	for method: Dictionary in script.get_script_method_list():
		if method.get("name", &"") == method_name:
			return (method.get("args", []) as Array).size()
	return -1


func _script_has_static_method(script: Script, method_name: StringName) -> bool:
	if not is_instance_valid(script):
		return false
	for method: Dictionary in script.get_script_method_list():
		if method.get("name", &"") == method_name:
			return true
	return false


func _has_bleed_tick(ticks: Array[RefCounted], source_unit_id: StringName, expected_stacks: int, expected_damage: int) -> bool:
	for tick: RefCounted in ticks:
		if not is_instance_valid(tick):
			continue
		var source: RefCounted = tick.get("source")
		if (
			is_instance_valid(source)
			and source.get("source_unit_id") == source_unit_id
			and tick.get("stacks") == expected_stacks
			and tick.call("tick_damage") == expected_damage
		):
			return true
	return false


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
