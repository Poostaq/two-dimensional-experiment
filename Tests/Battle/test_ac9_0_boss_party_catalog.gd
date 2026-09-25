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
