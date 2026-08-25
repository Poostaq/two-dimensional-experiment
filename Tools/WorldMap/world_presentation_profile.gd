class_name WorldPresentationProfile
extends RefCounted

static var GENERATOR_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_generator_v1.gd")
static var PREVIEW_SCENE: PackedScene = load("res://Scenes/world_map_preview.tscn")


func run(
	tree: SceneTree,
	seed_text: String,
	idle_samples: int = 30,
	scripted_duration_msec: int = 0
) -> Dictionary:
	var memory_before: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var generator: HexWorldGeneratorV1 = GENERATOR_SCRIPT.new()
	var generation_started: int = Time.get_ticks_usec()
	var generation_result: Dictionary = generator.generate(seed_text)
	var generation_usec: int = Time.get_ticks_usec() - generation_started
	if not generation_result.get("ok", false):
		return {"error": "generation_failed", "seed": seed_text}

	var preview: Node2D = PREVIEW_SCENE.instantiate() as Node2D
	preview.set("auto_present_fixture", false)
	tree.root.add_child(preview)
	await tree.process_frame
	var presentation_started: int = Time.get_ticks_usec()
	if not bool(preview.call("present_plan", generation_result["plan"])):
		preview.free()
		return {"error": "presentation_failed", "seed": seed_text}
	await tree.process_frame
	var presentation_build_usec: int = Time.get_ticks_usec() - presentation_started

	var minimap: WorldMinimap = preview.get_node("%WorldMinimap") as WorldMinimap
	var camera: WorldCameraController = preview.get_node("%WorldCamera") as WorldCameraController
	var minimap_started: int = Time.get_ticks_usec()
	minimap.update_camera_footprint(camera.get_visible_world_rect())
	var minimap_update_usec: int = Time.get_ticks_usec() - minimap_started
	var scripted_steps: int = await _run_scripted_route(tree, camera, scripted_duration_msec)

	var resident_node_count: int = _count_nodes(preview)
	var memory_after: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var idle_memory_start: int = memory_after
	for sample: int in maxi(idle_samples, 0):
		await tree.process_frame
	var idle_memory_end: int = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var result: Dictionary = {
		"generator_version": HexWorldGeneratorV1.VERSION,
		"seed": seed_text,
		"generation_usec": generation_usec,
		"presentation_build_usec": presentation_build_usec,
		"minimap_update_usec": minimap_update_usec,
		"resident_node_count": resident_node_count,
		"world_cell_count": int(preview.call("get_main_cell_count")),
		"memory_before_bytes": memory_before,
		"memory_after_bytes": memory_after,
		"memory_delta_bytes": memory_after - memory_before,
		"idle_memory_delta_bytes": idle_memory_end - idle_memory_start,
		"idle_sample_count": maxi(idle_samples, 0),
		"scripted_duration_msec": maxi(scripted_duration_msec, 0),
		"scripted_step_count": scripted_steps,
		"environment": {
			"godot_version": Engine.get_version_info().get("string", "unknown"),
			"os": OS.get_name(),
			"cpu": OS.get_processor_name(),
			"logical_cpu_count": OS.get_processor_count(),
			"video_adapter": RenderingServer.get_video_adapter_name(),
			"viewport": [1152, 648],
			"headless": DisplayServer.get_name() == "headless",
		},
		"reference_hardware_status": "pending_manual_reference_hardware",
	}
	preview.free()
	return result


func run_corpus(
	tree: SceneTree,
	seeds: Array[String],
	idle_samples: int = 1,
	scripted_duration_msec: int = 0
) -> Array[Dictionary]:
	var profiles: Array[Dictionary] = []
	for seed_text: String in seeds:
		profiles.append(await run(tree, seed_text, idle_samples, scripted_duration_msec))
	return profiles


func _run_scripted_route(
	tree: SceneTree,
	camera: WorldCameraController,
	duration_msec: int
) -> int:
	if duration_msec <= 0:
		return 0
	var started: int = Time.get_ticks_msec()
	var steps: int = 0
	while Time.get_ticks_msec() - started < duration_msec:
		var direction: float = -1.0 if steps % 2 == 0 else 1.0
		camera.pan_by(Vector2(12.0 * direction, 6.0))
		if steps % 30 == 0:
			var zoom_direction: int = 1 if (steps / 30) % 2 == 0 else -1
			camera.zoom_by_steps(zoom_direction, Vector2(576.0, 324.0))
		steps += 1
		await tree.process_frame
	return steps


func _count_nodes(root: Node) -> int:
	var count := 1
	for child: Node in root.get_children():
		count += _count_nodes(child)
	return count
