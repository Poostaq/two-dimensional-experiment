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
	_finish()


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
