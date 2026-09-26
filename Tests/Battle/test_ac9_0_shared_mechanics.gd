class_name Ac9_0SharedMechanicsTests
extends SceneTree

var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(BattleKeywordOperation.Kind.has("APPLY_POISON"), "Poison operation exists")
	_expect(BattleKeywordOperation.Kind.has("APPLY_STUN"), "Stun operation exists")
	_expect(BattleKeywordOperation.Kind.has("LEECH"), "Leech operation exists")
	_expect(BattleUnitState.MAX_ARMOR == 10, "Armor cap is fixed at 10")
	_test_poison_contract()
	_test_poison_source_isolation_contract()
	_test_stun_contract()
	await _test_poison_commit_contract()
	await _test_stun_turn_skip_contract()
	await _test_stun_guard_action_contract()
	_test_leech_contract()
	_test_multi_target_profile_contract()
	_test_declared_ring_path_contract()
	_test_adjacent_ally_contract()
	_test_adjacent_ally_action_end_reaction_contract()
	_test_action_end_reaction_requires_contact()
	await _test_iron_decree_default_attack_commit_contract()
	await _test_leech_commit_contract()
	_finish()


func _test_poison_contract() -> void:
	var source: RefCounted = BattleKeywordSource.create(&"source", &"poison", 4)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20)
	_expect(target.apply_poison(source, &"power", 1, 3), "Poison applies one Power stack")
	_expect(target.get_poison_stacks(&"power") == 1, "Poison records declared axis")
	_expect(target.apply_poison(source, &"power", 3, 3), "Poison reapplies through the cap")
	_expect(target.get_poison_stacks(&"power") == 3, "Poison caps at three stacks")
	_expect(not target.apply_poison(source, &"health", 1, 3), "Poison rejects an undeclared axis")
	_expect(not target.apply_poison(source, &"speed", 1, 0), "Poison rejects an invalid expiry")
	_expect(target.get_poison_stacks(&"power", 4) == 0, "Poison expires after its authored round")
	var poisoned := BattleUnitState.new(&"poisoned", "Poisoned", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 6, 3)
	_expect(poisoned.apply_poison(source, &"power", 2, 3), "Power Poison applies a stat penalty")
	_expect(poisoned.get_effective_power() == 4, "Power Poison reduces effective Power per stack")
	_expect(poisoned.apply_poison(source, &"defense", 3, 3), "Defense Poison applies a stat penalty")
	_expect(poisoned.get_effective_defense() == 0, "Defense Poison cannot reduce below zero")
	_expect(poisoned.apply_poison(source, &"speed", 2, 3), "Speed Poison applies a stat penalty")
	_expect(poisoned.get_effective_speed() == 3, "Speed Poison reduces effective Speed per stack")
	poisoned.clear_round_keywords(3)
	_expect(poisoned.get_effective_power() == 6, "Expired Power Poison no longer affects production stat reads")
	_expect(poisoned.get_effective_defense() == 3, "Expired Defense Poison no longer affects production stat reads")
	_expect(poisoned.get_effective_speed() == 5, "Expired Speed Poison no longer affects production stat reads")
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var poison: RefCounted = effect_script.poison(effect_script.TargetRole.PRIMARY, &"power", 1, 3)
	_expect(is_instance_valid(poison), "Poison authored effect is valid")
	if is_instance_valid(poison):
		_expect(poison.keyword_kind == BattleKeywordOperation.Kind.APPLY_POISON, "Poison effect uses its keyword")
		_expect(poison.poison_axis == &"power", "Poison effect preserves its declared axis")


func _test_poison_source_isolation_contract() -> void:
	var first_source: RefCounted = BattleKeywordSource.create(&"first", &"dose", 4)
	var second_source: RefCounted = BattleKeywordSource.create(&"second", &"dose", 7)
	var target: BattleUnitState = BattleUnitState.new(&"multi_poison", "Multi Poison", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 8, 4)
	_expect(target.apply_poison(first_source, &"power", 2, 3), "First Poison source applies independently")
	_expect(target.apply_poison(second_source, &"power", 2, 3), "Second Poison source coexists on the same axis")
	_expect(target.has_method("get_poison_source_stacks"), "Poison exposes source-specific stack queries")
	if target.has_method("get_poison_source_stacks"):
		_expect(target.call("get_poison_source_stacks", &"power", &"first", &"dose", 1) == 2, "First Poison source keeps its own stacks")
		_expect(target.call("get_poison_source_stacks", &"power", &"second", &"dose", 1) == 2, "Second Poison source keeps its own stacks")
	_expect(target.get_poison_stacks(&"power", 1) == 3, "Same-axis Poison penalty remains capped at three across sources")
	_expect(target.get_effective_power() == 5, "Aggregate Poison penalty applies the capped production stat reduction")

func _test_multi_target_profile_contract() -> void:
	var profile_script := load("res://Scripts/Battle/battle_skill_target_profile.gd") as Script
	var profile: RefCounted = profile_script.create(2, 3, BattleUnitState.Side.ENEMY)
	_expect(is_instance_valid(profile), "Authored skills can select up to three targets")


func _test_declared_ring_path_contract() -> void:
	_expect(BattleFormationRules.is_valid_ring_path([0, 1, 2, 5], 3), "Move 3 accepts a contiguous declared ring path")
	_expect(not BattleFormationRules.is_valid_ring_path([0, 2], 3), "Declared paths reject non-neighbor hops")
	_expect(not BattleFormationRules.is_valid_ring_path([0, 1, 0], 3), "Declared paths reject repeated slots")
	var targets: Array[StringName] = [&"target"]
	var path: Array[int] = [0, 1, 2]
	var plan: SkillEffectPlan = SkillEffectPlan.create(&"actor", &"move_two", targets, [], [], 1, true, 1, [], null, null, false, &"actor", path)
	_expect(is_instance_valid(plan), "Effect plans retain legal Move 2 paths")


func _test_stun_contract() -> void:
	var source: RefCounted = BattleKeywordSource.create(&"source", &"stun", 4)
	var target := BattleUnitState.new(&"stunned", "Stunned", BattleUnitState.Side.ENEMY, 0, 5, 20)
	_expect(target.apply_stun(source), "Stun applies to an unstunned target")
	_expect(target.is_stunned(), "Stun remains active before the eligible action")
	_expect(not target.apply_stun(source), "Stun cannot stack or refresh")
	_expect(target.consume_stun(), "Stun consumes exactly one eligible action")
	_expect(not target.is_stunned(), "Stun clears after its skipped action")
	_expect(target.has_stun_guard(), "Stun Guard begins after the skipped action")
	_expect(not target.apply_stun(source), "Stun Guard rejects immediate restun")
	_expect(target.complete_stun_guard(), "Stun Guard clears after the target completes an action")
	_expect(target.apply_stun(source), "Stun applies again after Stun Guard clears")
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var stun: RefCounted = effect_script.stun(effect_script.TargetRole.PRIMARY)
	_expect(is_instance_valid(stun), "Stun authored effect is valid")
	if is_instance_valid(stun):
		_expect(stun.keyword_kind == BattleKeywordOperation.Kind.APPLY_STUN, "Stun effect uses its keyword")


func _test_poison_commit_contract() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20)
	arena.configure_units([target])
	var source: RefCounted = BattleKeywordSource.create(&"source", &"poison", 4)
	var operation: RefCounted = BattleKeywordOperation.create(
		BattleKeywordOperation.Kind.APPLY_POISON, &"target", 1, 3, source, &"", false, &"power"
	)
	_expect(target.get_poison_stacks(&"power") == 0, "Unapplied Poison operation does not mutate state")
	var deltas: Array[Dictionary] = []
	_expect(arena._apply_keyword_operation(operation, 1, deltas, false), "Confirmed Poison operation applies")
	_expect(target.get_poison_stacks(&"power", 1) == 1, "Confirmed Poison operation mutates target")
	arena.queue_free()
	await process_frame


func _test_stun_turn_skip_contract() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var first := BattleUnitState.new(&"first", "First", BattleUnitState.Side.PLAYER, 0, 10, 20)
	var stunned := BattleUnitState.new(&"stunned", "Stunned", BattleUnitState.Side.ENEMY, 0, 1, 20)
	arena.configure_units([first, stunned])
	var source: RefCounted = BattleKeywordSource.create(&"source", &"stun", 4)
	_expect(stunned.apply_stun(source), "Stun applies before an eligible turn")
	arena.advance_turn()
	_expect(arena.get_current_unit().unit_id == first.unit_id, "Stunned unit loses its next eligible turn")
	_expect(not stunned.is_stunned(), "Stun clears after the skipped turn")
	arena.queue_free()
	await process_frame


func _test_stun_guard_action_contract() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var first := BattleUnitState.new(&"first", "First", BattleUnitState.Side.PLAYER, 0, 10, 20)
	var stunned := BattleUnitState.new(&"stunned", "Stunned", BattleUnitState.Side.ENEMY, 0, 1, 20)
	arena.configure_units([first, stunned])
	var source: RefCounted = BattleKeywordSource.create(&"source", &"stun", 4)
	_expect(stunned.apply_stun(source), "Stun applies before the skipped turn")
	arena.advance_turn()
	_expect(stunned.has_stun_guard(), "Skipped unit enters Stun Guard")
	_expect(arena.confirm_default_attack(first.unit_id, stunned.unit_id, arena.get_battle_revision()), "First unit completes its action")
	arena._executing_enemy_action = true
	_expect(arena.confirm_default_attack(stunned.unit_id, first.unit_id, arena.get_battle_revision()), "Guarded unit completes its next action")
	arena._executing_enemy_action = false
	_expect(not stunned.has_stun_guard(), "Stun Guard clears after the guarded unit completes an action")
	arena.queue_free()
	await process_frame


func _test_adjacent_ally_contract() -> void:
	var owner := BattleUnitState.new(&"owner", "Owner", BattleUnitState.Side.PLAYER, 0, 5, 20)
	var slot_one := BattleUnitState.new(&"slot_one", "Slot One", BattleUnitState.Side.PLAYER, 1, 5, 20)
	var slot_three := BattleUnitState.new(&"slot_three", "Slot Three", BattleUnitState.Side.PLAYER, 3, 5, 20)
	var units: Array[BattleUnitState] = [owner, slot_three, slot_one]
	var adjacent: BattleUnitState = BattleFormationRules.closest_active_adjacent_ally(owner, units)
	_expect(is_instance_valid(adjacent) and adjacent.unit_id == slot_one.unit_id, "Adjacent ally selection uses the lowest slot tie-break")
	slot_one.current_hp = 0
	adjacent = BattleFormationRules.closest_active_adjacent_ally(owner, units)
	_expect(is_instance_valid(adjacent) and adjacent.unit_id == slot_three.unit_id, "Adjacent ally selection ignores inactive candidates")
	owner.current_hp = 0
	_expect(BattleFormationRules.closest_active_adjacent_ally(owner, units) == null, "Inactive owners cannot select adjacent allies")


func _test_adjacent_ally_action_end_reaction_contract() -> void:
	var catalog := load("res://Scripts/Run/run_character_catalog.gd") as Script
	var goruk: RunCharacter = catalog.create_by_class_id(&"goruk_ironline")
	var owner := BattleUnitState.new(&"goruk_ironline", "Goruk", BattleUnitState.Side.PLAYER, 0, 5, 20, goruk.get_skills())
	var ally := BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 1, 5, 20)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5, 20)
	var units: Array[BattleUnitState] = [owner, ally, enemy]
	var dispatcher_script := load("res://Scripts/Battle/battle_reaction_dispatcher.gd") as Script
	var reactions: Variant = dispatcher_script.call("collect_action_end_reactions", owner, units, 1)
	_expect(reactions is Array and reactions.size() == 1, "Goruk resolves one action-end passive candidate")
	if reactions is Array and reactions.size() == 1:
		_expect(reactions[0].get("target_ids") == [owner.unit_id, ally.unit_id], "Goruk resolves Iron Decree to self and the adjacent ally")


func _test_action_end_reaction_requires_contact() -> void:
	var catalog := load("res://Scripts/Run/run_character_catalog.gd") as Script
	var goruk: RunCharacter = catalog.create_by_class_id(&"goruk_ironline")
	var owner := BattleUnitState.new(&"goruk_ironline", "Goruk", BattleUnitState.Side.PLAYER, 0, 5, 20, goruk.get_skills())
	var ally := BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 1, 5, 20)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 5, 5, 20)
	var units: Array[BattleUnitState] = [owner, ally, enemy]
	var reactions: Array[Dictionary] = BattleReactionDispatcher.collect_action_end_reactions(owner, units, 1)
	_expect(reactions.is_empty(), "Action-end reactions require the owner to finish in contact")


func _test_iron_decree_default_attack_commit_contract() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var catalog := load("res://Scripts/Run/run_character_catalog.gd") as Script
	var goruk: RunCharacter = catalog.create_by_class_id(&"goruk_ironline")
	var owner := BattleUnitState.new(&"goruk_ironline", "Goruk", BattleUnitState.Side.PLAYER, 0, 5, 20, goruk.get_skills())
	var ally := BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 1, 5, 20)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5, 20)
	arena.configure_units([owner, ally, enemy])
	_expect(ally.get_armor() == 0, "Iron Decree has no action-start effect")
	var preview := arena.preview_default_attack(owner.unit_id, enemy.unit_id)
	_expect(not preview.is_empty(), "Goruk can commit a contacted default attack")
	arena.confirm_default_attack(owner.unit_id, enemy.unit_id, int(preview.get("revision", -1)))
	_expect(ally.get_armor() == 2, "Iron Decree applies Armor after Goruk's contacted action")
	arena.queue_free()


func _test_leech_contract() -> void:
	var actor := BattleUnitState.new(&"leecher", "Leecher", BattleUnitState.Side.PLAYER, 0, 5, 20)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 6)
	actor.current_hp = 5
	var direct: BattleDamageResult = BattleDamageResolver.apply_direct_damage(actor, target, 10)
	_expect(actor.apply_leech(direct, 35) == 2, "Leech heals from actual direct HP damage")
	_expect(actor.current_hp == 7, "Leech rounds down and cannot use overkill damage")
	var status_target := BattleUnitState.new(&"status_target", "Status Target", BattleUnitState.Side.ENEMY, 1, 5, 6)
	var status: BattleDamageResult = BattleDamageResolver.apply_status_damage(actor, status_target, 4)
	_expect(actor.apply_leech(status, 35) == 0, "Leech ignores status damage")
	_expect(actor.apply_leech(null, 35) == 0, "Leech rejects missing damage results")
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var leech: RefCounted = effect_script.leech(effect_script.TargetRole.ACTOR, 35)
	_expect(is_instance_valid(leech), "Leech authored effect is valid")
	if is_instance_valid(leech):
		_expect(leech.keyword_kind == BattleKeywordOperation.Kind.LEECH, "Leech effect uses its keyword")
		_expect(leech.magnitude == 35, "Leech effect preserves its healing percentage")


func _test_leech_commit_contract() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var actor := BattleUnitState.new(&"leecher", "Leecher", BattleUnitState.Side.PLAYER, 0, 5, 20)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 6)
	actor.current_hp = 5
	arena.configure_units([actor, target])
	var direct: BattleDamageResult = BattleDamageResolver.apply_direct_damage(actor, target, 10)
	var operation: RefCounted = BattleKeywordOperation.create(BattleKeywordOperation.Kind.LEECH, actor.unit_id, 35)
	var deltas: Array[Dictionary] = []
	_expect(arena._apply_leech_operation(operation, actor, [direct], deltas), "Confirmed Leech applies after direct damage")
	_expect(actor.current_hp == 7, "Confirmed Leech heals only from committed damage")
	arena.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.0 shared mechanics: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("AC9.0 shared mechanics: %d assertion(s), %d failure(s)." % [_assertions, _failures.size()])
	quit(1)
