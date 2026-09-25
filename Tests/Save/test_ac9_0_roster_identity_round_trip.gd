class_name Ac9_0RosterIdentityRoundTripTests
extends SceneTree

var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var character: RunCharacter = RunCharacterCatalog.create_by_class_id(&"scrapshield_bruiser")
	_expect(is_instance_valid(character), "Goblin baseline character constructs")
	if is_instance_valid(character):
		_expect(character.character_id == &"scrapshield_bruiser", "Baseline character ID is stable")
		_expect(character.class_id == &"scrapshield_bruiser", "Baseline class ID is stable")
		_expect(character.race_id == &"goblin", "Baseline race ID is stable")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.0 roster identity: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
