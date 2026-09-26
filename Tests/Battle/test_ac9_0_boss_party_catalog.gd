class_name Ac9_0BossPartyCatalogTests
extends SceneTree

var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_script := load("res://Scripts/Battle/boss_party_catalog.gd") as Script
	_expect(is_instance_valid(catalog_script), "Boss party catalog script exists")
	if is_instance_valid(catalog_script):
		_expect(catalog_script.has_method("create_by_enemy_clan_id"), "Boss party catalog creates by enemy clan ID")
		var expected_commanders: Dictionary[StringName, StringName] = {&"human": &"marshal_elian_voss", &"elf": &"lady_saelith_moonfall", &"dwarf": &"thane_brokk_stonevein"}
		for clan_id: StringName in expected_commanders:
			var party: Array[RunCharacter] = catalog_script.create_by_enemy_clan_id(clan_id)
			_expect(party.size() == 4, "%s boss party has four authored members" % clan_id)
			var commander_count: int = 0
			for member: RunCharacter in party:
				commander_count += int(member.class_id == expected_commanders[clan_id])
			_expect(commander_count == 1, "%s boss party contains its commander exactly once" % clan_id)
		_expect((catalog_script.create_by_enemy_clan_id(&"unknown") as Array).is_empty(), "Boss party catalog rejects unknown clans")
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.0 boss party catalog: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
