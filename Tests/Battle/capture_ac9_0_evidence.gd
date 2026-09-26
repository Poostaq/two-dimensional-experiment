class_name AC90EvidenceCapture
extends SceneTree

const OUTPUT: String = "res://Docs/Specs/AC9/Evidence/AC9.0"
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1152, 648), Vector2i(1920, 1080)]

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _capture_player_selector()
	await _capture_boss_party(0, "human")
	await _capture_boss_party(2, "elf")
	await _capture_boss_party(1, "dwarf")
	if _failures == 0:
		print("PASS capture_ac9_0_evidence: 8/8 screenshots saved.")
	quit(0 if _failures == 0 else 1)


func _capture_player_selector() -> void:
	var packed: PackedScene = load("res://Scenes/world_run_start.tscn")
	var launcher: Control = packed.instantiate()
	var repository: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new(
		"user://tests/ac9-0-visual.json"
	)
	launcher.set("_repository", repository)
	root.add_child(launcher)
	await process_frame
	launcher.call("open_new_run")
	await process_frame
	await process_frame
	_expect(
		(launcher.get_node("%NewRunScreen") as Control).visible,
		"player commander selector is visible"
	)
	for resolution: Vector2i in RESOLUTIONS:
		root.size = resolution
		await _capture(
			"player-commander-selector-%dx%d.png" % [resolution.x, resolution.y]
		)
	launcher.free()
	await process_frame


func _capture_boss_party(encounter_index: int, faction: String) -> void:
	var packed: PackedScene = load("res://Scenes/battle_arena.tscn")
	var arena: BattleArena = packed.instantiate()
	root.add_child(arena)
	await process_frame
	arena.configure(Vector2i(encounter_index, 0), WorldEncounterType.BOSS)
	var player := BattleUnitState.new(
		&"visual_player",
		"Roster Vanguard",
		BattleUnitState.Side.PLAYER,
		1,
		1,
		30
	)
	var players: Array[BattleUnitState] = [player]
	arena.configure_party_units(players)
	arena.set("_auto_enemy_turns", false)
	await process_frame
	var commander_ids: Array[StringName] = [
		&"marshal_elian_voss",
		&"thane_brokk_stonevein",
		&"lady_saelith_moonfall",
	]
	_expect(
		is_instance_valid(arena.get_unit_by_id(commander_ids[encounter_index])),
		"%s boss commander is present" % faction
	)
	for resolution: Vector2i in RESOLUTIONS:
		root.size = resolution
		await _capture("%s-boss-party-%dx%d.png" % [
			faction,
			resolution.x,
			resolution.y,
		])
	arena.free()
	await process_frame


func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_texture().get_image()
	var error: Error = screenshot.save_png(OUTPUT + "/" + filename)
	_expect(error == OK, "capture saved: " + filename)
	_expect(
		screenshot.get_width() == root.size.x and screenshot.get_height() == root.size.y,
		"capture dimensions match: " + filename
	)
	print("CAPTURE ", filename, " ", screenshot.get_width(), "x", screenshot.get_height())


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
