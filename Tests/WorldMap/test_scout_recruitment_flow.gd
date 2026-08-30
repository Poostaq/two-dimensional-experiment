class_name ScoutRecruitmentFlowTests
extends SceneTree

const RUNTIME_SCENE := "res://Scenes/world_map_runtime.tscn"
const SCOUT_REWARD_ID := &"combat_recruit_scout"
const SCOUT_ID := &"scout"
const PLACEMENT_OPEN_STATE := 3
const SAVE_FAILED_STATE := 6
const REWARD_COMPLETED_STATE := 7

var _failures: Array[String] = []
var _assertions: int = 0


class FailingOnceRepository:
	extends RefCounted

	var writes: Array[PackedByteArray] = []
	var fail_next: bool = false

	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes.append(bytes.duplicate())
		if fail_next:
			fail_next = false
			return {"ok": false, "value": null, "error": null}
		return {"ok": true, "value": null, "error": null}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var generated := HexWorldGeneratorV1.new().generate("scout-recruitment-flow")
	_expect(bool(generated.get("ok", false)), "fixture world generates")
	if not bool(generated.get("ok", false)):
		_finish()
		return
	var plan := generated.get("plan") as WorldPlan
	var repository := FailingOnceRepository.new()
	var runtime := await _create_runtime(plan, repository)
	if not is_instance_valid(runtime):
		_finish()
		return

	var battle := _open_victory_battle(runtime)
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
	_expect(
		int(runtime.call("get_recruitment_state")) == PLACEMENT_OPEN_STATE,
		"Scout confirmation enters placement_open"
	)
	var first_party := party_host.get_child(0) as PartyManagement
	var first_recruit := runtime.get("_pending_recruit") as RunCharacter
	runtime.call("_on_recruitment_placement_requested", battle.get_selected_reward())
	_expect(party_host.get_child_count() == 1, "duplicate request opens no second placement")
	_expect(party_host.get_child(0) == first_party, "duplicate request preserves placement identity")
	_expect(runtime.get("_pending_recruit") == first_recruit, "duplicate request preserves recruit identity")

	first_party.close_requested.emit()
	await process_frame
	_expect(party_host.get_child_count() == 0, "ordinary recruitment close routes through cancellation")
	_expect(runtime.has_active_battle(), "recruitment close never dismisses battle")
	_expect(
		is_instance_valid(battle.get_selected_reward())
		and battle.get_selected_reward().reward_id == SCOUT_REWARD_ID,
		"cancellation restores Scout as selected reward"
	)

	battle.confirm_reward_selection()
	await process_frame
	var retry_party := party_host.get_child(0) as PartyManagement
	var pending_recruit := runtime.get("_pending_recruit") as RunCharacter
	retry_party.placement_requested.emit(3, &"wrong_recruit")
	_expect(
		not (runtime.get("_roster") as RunRoster).has_character(SCOUT_ID),
		"stale recruit identity cannot mutate roster"
	)
	repository.fail_next = true
	retry_party.placement_requested.emit(3, pending_recruit.character_id)
	await process_frame
	_expect(runtime.is_autosave_blocked(), "failed recruitment save blocks repeated placement input")
	_expect(
		int(runtime.call("get_recruitment_state")) == SAVE_FAILED_STATE,
		"failed recruitment save enters save_failed"
	)
	_expect(
		not (runtime.get("_roster") as RunRoster).has_character(SCOUT_ID),
		"failed save does not publish Scout"
	)
	_expect(runtime.has_active_battle(), "failed save keeps battle open")
	_expect(runtime.has_active_party_management(), "failed save keeps placement alive")
	_expect(party_host.get_child(0) == retry_party, "failed save preserves placement instance")
	_expect(runtime.get("_pending_recruit") == pending_recruit, "failed save preserves recruit instance")

	var retried := runtime.retry_autosave()
	await process_frame
	_expect(bool(retried.get("ok", false)), "recruitment save retry succeeds")
	_expect(
		int(runtime.call("get_recruitment_state")) == REWARD_COMPLETED_STATE,
		"successful retry enters reward_completed"
	)
	_expect((runtime.get("_roster") as RunRoster).has_character(SCOUT_ID), "successful retry publishes Scout")
	var formation := runtime.get_durable_run_state().get("formation") as Array[StringName]
	_expect(formation.count(SCOUT_ID) == 1, "durable formation contains Scout exactly once")
	_expect(not runtime.has_active_battle(), "reward completes only after roster publication")
	_expect(not runtime.has_active_party_management(), "successful recruitment closes placement")

	var next_battle := _open_victory_battle(runtime)
	var scout_unit := next_battle.get_unit_by_id(SCOUT_ID)
	_expect(
		is_instance_valid(scout_unit) and scout_unit.side == BattleUnitState.Side.PLAYER,
		"next battle receives Scout from RunRoster.create_battle_units"
	)
	runtime.free()
	_finish()


func _create_runtime(
	plan: WorldPlan,
	repository: RefCounted
) -> WorldRuntimeController:
	var packed: PackedScene = load(RUNTIME_SCENE) as PackedScene
	var runtime: WorldRuntimeController = packed.instantiate() as WorldRuntimeController
	runtime.auto_initialize_runtime = false
	root.add_child(runtime)
	await process_frame
	var empty_consumed: Array[Vector2i] = []
	var formation: Array[StringName] = [&"player_0", &"player_1", &"player_2", &"", &"", &""]
	var run_state: WorldRunState = WorldRunState.create(
		plan.get_start_coord(),
		plan.get_boss_coord(),
		0,
		false,
		false,
		empty_consumed,
		formation
	)
	var session: Dictionary = {
		"plan": plan,
		"run_state": run_state,
		"resolved_seed": "scout-recruitment-flow",
	}
	_expect(runtime.apply_session(session, repository), "runtime applies persisted fixture session")
	return runtime


func _open_victory_battle(runtime: WorldRuntimeController) -> BattleArena:
	runtime.call("_on_battle_requested", Vector2i.ZERO, WorldEncounterType.COMBAT)
	var battle := runtime.get_node("BattleHost").get_child(0) as BattleArena
	battle.call("_complete_battle", BattleOutcome.Type.VICTORY)
	return battle


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
