class_name AC66PreparationUiTests
extends SceneTree

const ARENA_SCENE := "res://Scenes/battle_arena.tscn"
const RECORD_SCRIPT := preload("res://Scripts/Battle/battle_preparation_record.gd")
const EXPECTED_TEST_COUNT := 11

var _failures: Array[String] = []
var _assertions: int = 0
var _commit_emitted: bool = false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(ARENA_SCENE) as PackedScene
	var arena := packed.instantiate() as BattleArena if is_instance_valid(packed) else null
	_expect(is_instance_valid(arena), "battle arena instantiates")
	if not is_instance_valid(arena):
		_finish()
		return
	get_root().add_child(arena)
	await process_frame
	arena.configure(Vector2i(2, -1), WorldEncounterType.COMBAT)
	var identity := arena.get_setup_identity()
	var offered := RECORD_SCRIPT.offered(
		&"prep-ui",
		Vector2i(2, -1),
		WorldEncounterType.COMBAT,
		String(identity.get("canonical_key"))
	)
	_expect(arena.configure_preparation(offered), "offered preparation configures")
	var blocker := arena.get_node_or_null("%PreparationBlocker") as Control
	_expect(is_instance_valid(blocker) and blocker.visible, "preparation blocker is visible")
	var content := blocker.find_child("PreparationContent", true, false) as Control
	var dialog := content.get_parent() as PanelContainer if is_instance_valid(content) else null
	_expect(is_instance_valid(dialog) and dialog != blocker, "preparation content has an opaque dialog panel")
	_expect(
		is_instance_valid(dialog)
			and dialog.size_flags_horizontal == Control.SIZE_SHRINK_CENTER
			and dialog.size_flags_vertical == Control.SIZE_SHRINK_CENTER,
		"preparation dialog is centered over the battle"
	)
	_expect(
		is_instance_valid(arena.get_node_or_null("%FrontlineBriefingButton"))
			and is_instance_valid(arena.get_node_or_null("%SparePlatingButton"))
			and is_instance_valid(arena.get_node_or_null("%PreparationConfirmButton")),
		"choice and confirm controls are scene-authored"
	)
	_expect(arena.is_battle_input_locked(), "battle reports input locked")
	var current_before := arena.get_current_unit()
	arena.advance_turn()
	_expect(arena.get_current_unit() == current_before, "turn advancement is locked")
	var enemy := _first_enemy(arena.get_turn_queue())
	var hp_before := enemy.current_hp
	arena.perform_debug_damage()
	_expect(enemy.current_hp == hp_before, "debug damage is locked")
	arena.preparation_commit_requested.connect(_on_commit_requested)
	(arena.get_node("%SparePlatingButton") as Button).pressed.emit()
	(arena.get_node("%PreparationConfirmButton") as Button).pressed.emit()
	_expect(_commit_emitted, "valid choice requests controller commit")
	_expect(blocker.visible and arena.is_battle_input_locked(), "request alone does not unlock battle")
	arena.queue_free()
	_finish()


func _first_enemy(units: Array[BattleUnitState]) -> BattleUnitState:
	for unit: BattleUnitState in units:
		if unit.side == BattleUnitState.Side.ENEMY and unit.is_active():
			return unit
	return null


func _on_commit_requested(
	_choice: int,
	_target_unit_id: StringName,
	_expected_setup_key: String
) -> void:
	_commit_emitted = true


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("PASS test_ac6_6_preparation_ui (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
