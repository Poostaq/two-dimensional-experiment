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
	_test_stun_contract()
	await _test_poison_commit_contract()
	await _test_stun_turn_skip_contract()
	_test_leech_contract()
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
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var poison: RefCounted = effect_script.poison(effect_script.TargetRole.PRIMARY, &"power", 1, 3)
	_expect(is_instance_valid(poison), "Poison authored effect is valid")
	if is_instance_valid(poison):
		_expect(poison.keyword_kind == BattleKeywordOperation.Kind.APPLY_POISON, "Poison effect uses its keyword")
		_expect(poison.poison_axis == &"power", "Poison effect preserves its declared axis")


func _test_stun_contract() -> void:
	var source: RefCounted = BattleKeywordSource.create(&"source", &"stun", 4)
	var target := BattleUnitState.new(&"stunned", "Stunned", BattleUnitState.Side.ENEMY, 0, 5, 20)
	_expect(target.apply_stun(source), "Stun applies to an unstunned target")
	_expect(target.is_stunned(), "Stun remains active before the eligible action")
	_expect(not target.apply_stun(source), "Stun cannot stack or refresh")
	_expect(target.consume_stun(), "Stun consumes exactly one eligible action")
	_expect(not target.is_stunned(), "Stun clears after its skipped action")
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
