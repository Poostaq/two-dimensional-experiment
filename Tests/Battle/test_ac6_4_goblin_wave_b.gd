class_name Ac6_4GoblinWaveBTests
extends SceneTree

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	var goblin := RunCharacter.new(
		&"scrapbroker",
		"Scrapbroker",
		8,
		18,
		[],
		3,
		1,
		&"goblin"
	)
	var roster := RunRoster.new([goblin])
	var battle_units := roster.create_battle_units()
	_expect(goblin.race_id == &"goblin", "run character stores stable race identity")
	_expect(battle_units[0].race_id == &"goblin", "battle conversion preserves race identity")
	_expect(battle_units[0].unit_id == goblin.character_id, "race propagation preserves identity")
	var legacy := RunCharacter.new(&"legacy", "Legacy", 1, 10, [])
	_expect(legacy.race_id == &"unknown", "legacy constructors default race identity")
	if _failures.is_empty():
		print("AC6.4 Goblin wave B: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
