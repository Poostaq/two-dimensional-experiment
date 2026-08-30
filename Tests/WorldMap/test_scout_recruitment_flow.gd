class_name ScoutRecruitmentFlowTests
extends SceneTree

const RUNTIME_SCENE := "res://Scenes/world_map_runtime.tscn"
const SCOUT_REWARD_ID := &"combat_recruit_scout"

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(RUNTIME_SCENE) as PackedScene
	var runtime := packed.instantiate() as WorldRuntimeController
	runtime.auto_initialize_runtime = false
	root.add_child(runtime)
	await process_frame
	runtime.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
	var battle := runtime.get_node("BattleHost").get_child(0) as BattleArena
	battle.call("_complete_battle", BattleOutcome.Type.VICTORY)
	battle.select_reward(SCOUT_REWARD_ID)
	battle.confirm_reward_selection()
	await process_frame
	var party_host := runtime.get_node("PartyHost")
	var battle_host := runtime.get_node("BattleHost") as CanvasLayer
	_expect(party_host is CanvasLayer, "production PartyHost owns a dedicated canvas layer")
	_expect(
		party_host is CanvasLayer and (party_host as CanvasLayer).layer > battle_host.layer,
		"recruitment placement renders above the active battle"
	)
	_expect(party_host.get_child_count() == 1, "one recruitment placement screen opens")
	runtime.free()
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Scout recruitment flow tests: PASS (%d/%d)" % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
