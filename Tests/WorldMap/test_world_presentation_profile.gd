class_name WorldPresentationProfileTests
extends SceneTree

const PROFILER_PATH := "res://Tools/WorldMap/world_presentation_profile.gd"
const EXPECTED_FIELDS := [
	"generator_version", "seed", "generation_usec", "presentation_build_usec",
	"minimap_update_usec", "resident_node_count", "world_cell_count",
	"memory_before_bytes", "memory_after_bytes", "memory_delta_bytes",
	"idle_memory_delta_bytes", "idle_sample_count", "scripted_duration_msec",
	"scripted_step_count", "environment", "reference_hardware_status"
]

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(PROFILER_PATH), "presentation profiler exists")
	if not ResourceLoader.exists(PROFILER_PATH):
		_finish()
		return
	var profiler_script := load(PROFILER_PATH) as GDScript
	var profiler: RefCounted = profiler_script.new()
	var result: Dictionary = await profiler.run(self, "golden-alpha", 10, 50)
	for field: String in EXPECTED_FIELDS:
		_expect(result.has(field), "profile contains %s" % field)
	_expect(result.get("world_cell_count", 0) == 217, "profile builds all 217 cells")
	_expect(result.get("generation_usec", 0) > 0, "generation timing is measured")
	_expect(result.get("presentation_build_usec", 0) > 0, "presentation timing is measured")
	_expect(result.get("minimap_update_usec", 0) >= 0, "minimap timing is measured")
	_expect(result.get("resident_node_count", 0) > 217, "resident node count is measured")
	_expect(result.get("idle_sample_count", 0) == 10, "requested idle samples are measured")
	_expect(result.get("scripted_duration_msec", 0) == 50, "scripted route duration is recorded")
	_expect(result.get("scripted_step_count", 0) > 0, "scripted pan and zoom route executes")
	var corpus_seeds: Array[String] = ["", "golden-alpha", "golden-beta", "town-road-01", "unicode-łódź"]
	var corpus: Array[Dictionary] = await profiler.run_corpus(self, corpus_seeds, 1, 0)
	_expect(corpus.size() == corpus_seeds.size(), "approved deterministic seed corpus is profiled")
	for index: int in corpus.size():
		_expect(corpus[index].get("seed", "") == corpus_seeds[index], "corpus result preserves canonical seed order")
		_expect(corpus[index].get("world_cell_count", 0) == 217, "corpus seed builds 217 cells")
	_expect(result.get("environment", {}).has("godot_version"), "Godot build identity is recorded")
	_expect(result.get("reference_hardware_status", "") == "pending_manual_reference_hardware", "reference hardware is not fabricated")
	print("PROFILE_JSON=" + JSON.stringify(result))
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("World presentation profile tests: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
