class_name AC83RewardAcknowledgementTests
extends SceneTree

var failures: int = 0
var state_script: Script = load("res://Scripts/Run/world_run_state.gd")
var settlement: Script = load("res://Scripts/Run/battle_settlement_rules.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
	var state: RefCounted = session.run_state
	var plan: WorldPlan = session.plan
	var health: Dictionary[StringName, int] = {&"hero": 20}
	state.set_character_hp_snapshot(health)
	var coords: Array[Vector2i] = []
	for coord: Vector2i in plan.get_cells():
		if plan.get_cells()[coord].get("encounter") == "combat":
			coords.append(coord)
	_expect(coords.size() >= 2, "fixture has two combat encounters")
	if coords.size() < 2:
		quit(1)
		return
	state.player_coord = coords[0]
	var receipt: Dictionary = _receipt(coords[0])
	var built: Dictionary = settlement.build_candidate(state, plan, receipt)
	_expect(built.get("ok", false), "victory builds")
	if not built.get("ok", false):
		quit(1)
		return
	var pending: RefCounted = built.value
	var pending_data: Dictionary = pending.to_dictionary()
	_expect(pending_data.get("pending_reward_battle_id") == receipt.battle_id, "victory stages pending reward atomically")
	_expect(pending.gold == 250 and pending.get_character_hp_snapshot()[&"hero"] > 0, "victory stages gold and recovery")
	if not pending_data.has("pending_reward_battle_id"):
		quit(1)
		return
	var copied: Dictionary = state_script.from_dictionary(pending_data, plan)
	_expect(copied.get("ok", false) and copied.value.to_dictionary() == pending_data, "pending copy round trips")
	copied.value.battle_settlements[0].enemy_ids.append("detached")
	_expect(pending.battle_settlements[0].enemy_ids.size() == 3, "pending receipt copies are detached")
	for invalid: Variant in [null, 3, [], {}, true, "unknown"]:
		var data: Dictionary = pending_data.duplicate(true)
		data.pending_reward_battle_id = invalid
		_expect(not state_script.from_dictionary(data, plan).get("ok", true), "invalid pending reference/type rejects")
	var prepared: Dictionary = pending_data.duplicate(true)
	prepared.cache_ready = true
	prepared.battle_preparation = load("res://Scripts/Battle/battle_preparation_record.gd").offered(&"prep", coords[1], "combat", "fixture").to_dictionary()
	_expect(not state_script.from_dictionary(prepared, plan).get("ok", true), "pending plus preparation rejects")
	var duplicate: Dictionary = settlement.build_candidate(pending, plan, receipt)
	_expect(duplicate.get("duplicate", false), "duplicate settlement while pending is no-op")
	var second_receipt: Dictionary = _receipt(coords[1])
	_expect(settlement.build_candidate(pending, plan, second_receipt).get("error") == "reward_pending", "new settlement cannot replace pending")
	var legacy: Dictionary = state.to_dictionary()
	legacy.erase("pending_reward_battle_id")
	var legacy_decoded: Dictionary = state_script.from_dictionary(legacy, plan)
	_expect(legacy_decoded.get("ok", false) and legacy_decoded.value.pending_reward_battle_id == "", "internal legacy dictionary defaults empty")
	var defeat: Dictionary = receipt.duplicate(true)
	defeat.outcome = "defeat"
	defeat.earned_gold = 0
	var lost: Dictionary = settlement.build_candidate(state, plan, defeat)
	_expect(lost.get("ok", false) and lost.value.pending_reward_battle_id == "", "defeat has no pending reward")
	var invalid_loss: Dictionary = lost.value.to_dictionary()
	invalid_loss.pending_reward_battle_id = defeat.battle_id
	_expect(not state_script.from_dictionary(invalid_loss, plan).get("ok", true), "pending defeat rejects")
	if not ResourceLoader.exists("res://Scripts/Run/battle_reward_acknowledgement_rules.gd"):
		_expect(false, "acknowledgement rules exist")
		quit(1)
		return
	var ack: Script = load("res://Scripts/Run/battle_reward_acknowledgement_rules.gd")
	_expect(not ack.build_candidate(null, plan, receipt.battle_id).get("ok", true), "null acknowledgement rejects")
	_expect(not ack.build_candidate(pending, plan, "").get("ok", true), "empty acknowledgement rejects")
	_expect(ack.build_candidate(pending, plan, "unknown").get("error") == "unknown_reward", "unknown acknowledgement rejects")
	_expect(not ack.build_candidate(lost.value, plan, receipt.battle_id).get("ok", true), "terminal acknowledgement rejects")
	var acknowledged: Dictionary = ack.build_candidate(pending, plan, receipt.battle_id)
	_expect(acknowledged.get("ok", false) and not acknowledged.get("duplicate", true), "known pending acknowledgement builds")
	if acknowledged.get("ok", false):
		var expected: Dictionary = pending_data.duplicate(true)
		expected.pending_reward_battle_id = ""
		_expect(acknowledged.value.to_dictionary() == expected, "acknowledgement only clears pending")
		_expect(pending.to_dictionary() == pending_data, "acknowledgement leaves source unchanged")
		var repeated: Dictionary = ack.build_candidate(acknowledged.value, plan, receipt.battle_id)
		_expect(repeated.get("ok", false) and repeated.get("duplicate", false) and repeated.value == null, "known duplicate acknowledgement no-op")
		var replayed: Dictionary = settlement.build_candidate(acknowledged.value, plan, receipt)
		_expect(replayed.get("duplicate", false) and acknowledged.value.pending_reward_battle_id == "", "settlement replay never restores pending")
		acknowledged.value.player_coord = coords[1]
		var second: Dictionary = settlement.build_candidate(acknowledged.value, plan, second_receipt)
		_expect(second.get("ok", false), "next settlement allowed after acknowledgement")
		if second.get("ok", false):
			_expect(ack.build_candidate(second.value, plan, receipt.battle_id).get("error") == "stale_reward", "older acknowledgement cannot clear newer reward")
			var stale: Dictionary = second.value.to_dictionary()
			stale.pending_reward_battle_id = receipt.battle_id
			_expect(not state_script.from_dictionary(stale, plan).get("ok", true), "pending must name final receipt")
	if failures == 0:
		print("PASS test_ac8_3_reward_acknowledgement")
	quit(0 if failures == 0 else 1)

func _receipt(coord: Vector2i) -> Dictionary:
	var record: Script = load("res://Scripts/Battle/battle_result_record.gd")
	return {"battle_id":record.encounter_id("combat", coord),"encounter_type":"combat","encounter_coord":[coord.x,coord.y],"outcome":"victory","enemy_ids":["a","b","c"],"defeated_enemy_ids":["a","b","c"],"terminal_player_health":[{"character_id":"hero","final_hp":0,"max_hp":20}],"earned_gold":150}

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
