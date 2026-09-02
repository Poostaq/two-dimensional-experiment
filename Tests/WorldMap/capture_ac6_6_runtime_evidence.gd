class_name AC66RuntimeEvidenceCapture
extends SceneTree

const WORLD_SCENE := "res://Scenes/world_map_runtime.tscn"
const EVIDENCE_ROOT := "res://Docs/Specs/AC6/Evidence/AC6.6/2026-09-02"
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")

var _summary_lines: Array[String] = []
var _failed: bool = false


class FakeRepository:
	extends RefCounted

	func replace_atomic(_bytes: PackedByteArray) -> Dictionary:
		return {"ok": true, "value": null, "error": null}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(EVIDENCE_ROOT.path_join("screenshots"))
	)
	var generated := HexWorldGeneratorV1.new().generate("ac6-6-evidence")
	if not bool(generated.get("ok", false)):
		push_error("AC6.6 evidence world generation failed")
		quit(1)
		return
	var plan := generated.get("plan") as WorldPlan
	await _capture_cache_progress(plan)
	await _capture_locked_preparation(plan)
	_write_summary()
	if _failed:
		quit(1)
		return
	print("PASS capture_ac6_6_runtime_evidence")
	quit(0)


func _capture_cache_progress(plan: WorldPlan) -> void:
	var world := await _create_world(plan, 3, false)
	var hud := world.get_node("%WorldMapHud") as WorldMapHud
	var label := hud.get_node("%CacheStatusLabel") as Label
	_summary_lines.append(
		"cache_progress: text=%s visible=%s progress=%d ready=%s"
		% [label.text, label.visible, 3, false]
	)
	await _save_viewport("cache-3-of-4.png")
	world.free()
	await process_frame


func _capture_locked_preparation(plan: WorldPlan) -> void:
	var world := await _create_world(plan, 0, true)
	world.call("_on_battle_requested", plan.get_start_coord(), WorldEncounterType.COMBAT)
	await process_frame
	await process_frame
	var arena := _get_arena(world)
	var state := world.get_durable_run_state()
	var record := state.get("battle_preparation") as RefCounted
	_summary_lines.append(
		"offered: state=%s cache_ready=%s locked=%s setup_key=%s"
		% [
			BattlePreparationRecord.STATE_NAMES[record.state],
			state.get("cache_ready"),
			arena.is_preparation_required(),
			record.setup_key,
		]
	)
	await _save_viewport("preparation-locked.png")
	var identity := arena.get_setup_identity() as RefCounted
	world.call(
		"_on_preparation_commit_requested",
		BattlePreparationRecord.Choice.SPARE_PLATING,
		&"",
		identity.canonical_key
	)
	await process_frame
	await process_frame
	var armor_rows: Array[String] = []
	for unit: BattleUnitState in arena.get_turn_queue():
		if unit.side == BattleUnitState.Side.PLAYER:
			armor_rows.append("%s:%d:%d" % [unit.unit_id, unit.slot_index, unit.get_armor()])
	var committed := world.get_durable_run_state()
	_summary_lines.append(
		"committed: state=%s cache_ready=%s locked=%s armor=%s"
		% [
			BattlePreparationRecord.STATE_NAMES[
				(committed.get("battle_preparation") as RefCounted).state
			],
			committed.get("cache_ready"),
			arena.is_preparation_required(),
			",".join(armor_rows),
		]
	)
	await _save_viewport("spare-plating-committed.png")
	world.free()
	await process_frame


func _create_world(plan: WorldPlan, progress: int, ready: bool) -> WorldRuntimeController:
	var packed: PackedScene = load(WORLD_SCENE) as PackedScene
	var world: WorldRuntimeController = packed.instantiate() as WorldRuntimeController
	root.add_child(world)
	await process_frame
	var consumed: Array[Vector2i] = []
	var formation: Array[StringName] = [&"brakka_rustbanner", &"", &"", &"", &"", &""]
	var state: RefCounted = RUN_STATE_SCRIPT.create(
		plan.get_start_coord(),
		plan.get_boss_coord(),
		0,
		false,
		false,
		consumed,
		formation,
		progress,
		ready
	)
	var session: Dictionary = {
		"plan": plan,
		"resolved_seed": "ac6-6-evidence",
		"run_state": state,
	}
	if not world.apply_session(session, FakeRepository.new()):
		push_error("AC6.6 evidence session failed")
		quit(1)
	return world


func _get_arena(world: WorldRuntimeController) -> BattleArena:
	var host := world.get_node("BattleHost")
	return host.get_child(0) as BattleArena if host.get_child_count() > 0 else null


func _save_viewport(file_name: String) -> void:
	await process_frame
	await process_frame
	var texture := root.get_viewport().get_texture()
	if not is_instance_valid(texture):
		push_error("Could not capture AC6.6 viewport: %s" % file_name)
		_failed = true
		return
	var image := texture.get_image()
	var error := image.save_png(EVIDENCE_ROOT.path_join("screenshots").path_join(file_name))
	if error != OK:
		push_error("Could not save AC6.6 screenshot: %s" % file_name)
		_failed = true


func _write_summary() -> void:
	var path := EVIDENCE_ROOT.path_join("runtime-state.txt")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not is_instance_valid(file):
		push_error("Could not write AC6.6 runtime summary")
		_failed = true
		return
	file.store_string("\n".join(_summary_lines) + "\n")
