extends SceneTree

const ORC_CLASS_IDS: Array[StringName] = [
	&"orc_iron_tusk_vanguard",
	&"orc_bonebreaker_reaver",
	&"orc_bloodbanner_captain",
	&"orc_chainwarden",
	&"orc_war_drummer",
	&"orc_siegebreaker",
]

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
	_expect(RunCharacterCatalog.create_by_class_id(&"orc_unknown") == null, "Orc catalog rejects unknown IDs")
	_finish()


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
