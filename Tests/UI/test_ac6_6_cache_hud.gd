class_name AC66CacheHudTests
extends SceneTree

const HUD_SCENE := "res://Scenes/world_map_hud.tscn"
const EXPECTED_TEST_COUNT := 5

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(HUD_SCENE) as PackedScene
	var hud := packed.instantiate() as WorldMapHud if is_instance_valid(packed) else null
	_expect(is_instance_valid(hud), "world HUD instantiates")
	if not is_instance_valid(hud):
		_finish()
		return
	get_root().add_child(hud)
	await process_frame
	var cache_label := hud.get_node_or_null("%CacheStatusLabel") as Label
	_expect(is_instance_valid(cache_label), "Cache status label is scene-authored")
	if is_instance_valid(cache_label) and hud.has_method("set_cache_state"):
		hud.call("set_cache_state", true, 3, false)
		_expect(cache_label.visible and cache_label.text == "Cache 3/4", "Brakka sees Cache progress")
		hud.call("set_cache_state", true, 0, true)
		_expect(cache_label.text == "Cache Ready", "full Cache has explicit ready state")
		hud.call("set_cache_state", false, 0, false)
		_expect(not cache_label.visible, "non-Brakka run hides Cache")
	hud.queue_free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("PASS test_ac6_6_cache_hud (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
