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
	var effect_script := load("res://Scripts/Battle/battle_skill_effect_definition.gd") as Script
	var poison: RefCounted = effect_script.poison(effect_script.TargetRole.PRIMARY, &"power", 1, 3)
	_expect(is_instance_valid(poison), "Poison authored effect is valid")
	if is_instance_valid(poison):
		_expect(poison.keyword_kind == BattleKeywordOperation.Kind.APPLY_POISON, "Poison effect uses its keyword")
		_expect(poison.poison_axis == &"power", "Poison effect preserves its declared axis")


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
