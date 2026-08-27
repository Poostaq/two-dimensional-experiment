class_name WorldBattleEntryTests
extends SceneTree

const WORLD_SCENE := "res://Scenes/world_map_runtime.tscn"
const EXPECTED_TEST_COUNT := 4

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(WORLD_SCENE) as PackedScene
	var runtime := packed.instantiate() as WorldRuntimeController if is_instance_valid(packed) else null
	_expect(is_instance_valid(runtime), "production world scene instantiates")
	if not is_instance_valid(runtime):
		_finish()
		return
	get_root().add_child(runtime)
	await process_frame
	var generated := HexWorldGeneratorV1.new().generate("world-battle-entry")
	var configured := (
		bool(generated.get("ok", false))
		and runtime.configure_runtime(generated.get("plan") as WorldPlan)
	)
	if configured:
		runtime.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
		await process_frame
	var battle_host := runtime.get_node("BattleHost")
	var arena := (
		battle_host.get_child(0) as BattleArena
		if battle_host.get_child_count() > 0
		else null
	)
	var units: Array[BattleUnitState] = arena.get_turn_queue() if is_instance_valid(arena) else []
	var has_enemy := false
	var has_player_skill := false
	for unit: BattleUnitState in units:
		has_enemy = has_enemy or unit.side == BattleUnitState.Side.ENEMY
		has_player_skill = (
			has_player_skill
			or (unit.side == BattleUnitState.Side.PLAYER and not unit.skills.is_empty())
		)
	_expect(has_enemy, "world battle includes an enemy target")
	_expect(has_player_skill, "world battle gives the player party skills")
	_expect(
		is_instance_valid(arena)
			and not (arena.get_node("%AdvanceTurnDebugButton") as Button).disabled,
		"debug damage action starts enabled"
	)
	runtime.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("World battle entry tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
