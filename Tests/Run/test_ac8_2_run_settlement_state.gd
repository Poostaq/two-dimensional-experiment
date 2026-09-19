class_name AC82RunSettlementStateTests
extends SceneTree
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
	var state: RefCounted = session.run_state
	var state_script: Script = load("res://Scripts/Run/world_run_state.gd")
	var plan: WorldPlan = session.plan
	var before: String = state.canonical_key()
	var data: Dictionary = state.to_dictionary()
	data.erase("run_status")
	_expect(not state_script.from_dictionary(data, plan).get("ok", true), "current dictionary requires status")
	data = state.to_dictionary()
	data.erase("battle_settlements")
	_expect(not state_script.from_dictionary(data, plan).get("ok", true), "current dictionary requires receipts")
	data = state.to_dictionary()
	data.run_status = "lost"
	_expect(not state_script.from_dictionary(data, plan).get("ok", true), "lost requires final receipt")
	var coord: Vector2i = plan.get_boss_coord()
	data.battle_settlements = [{"battle_id":"boss","encounter_type":"boss","encounter_coord":[coord.x,coord.y],"outcome":"defeat","enemy_ids":["enemy"],"defeated_enemy_ids":[],"terminal_player_health":[{"character_id":"hero","final_hp":0,"max_hp":20}],"earned_gold":0}]
	var decoded: Dictionary = state_script.from_dictionary(data, plan)
	_expect(decoded.get("ok", false), "structural terminal record is valid")
	if decoded.get("ok", false):
		var lost: RefCounted = decoded.value
		_expect(not lost.is_playable() and lost.canonical_key() != before, "lifecycle changes canonical identity")
		data.battle_settlements[0].enemy_ids.append("external_mutation")
		_expect(lost.battle_settlements[0].enemy_ids.size() == 1, "construction deep copies receipt")
		var exported: Dictionary = lost.to_dictionary()
		exported.battle_settlements[0].earned_gold = 100
		_expect(lost.battle_settlements[0].earned_gold == 0, "serialization detached")
	_expect(state.canonical_key() == before and state.gold == 100, "candidate validation never mutates original")
	if failures == 0:
		print("PASS test_ac8_2_run_settlement_state")
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
