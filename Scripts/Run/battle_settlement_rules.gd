class_name BattleSettlementRules
extends RefCounted

static var RECORD: Script = load("res://Scripts/Battle/battle_result_record.gd")
static var STATE: Script = load("res://Scripts/Run/world_run_state.gd")

static func build_candidate(state: RefCounted, plan: WorldPlan, receipt: Dictionary) -> Dictionary:
	if not is_instance_valid(state) or not state.is_valid(plan) or not RECORD.validate_receipt(receipt):
		return _failure("invalid_result")
	for existing: Dictionary in state.battle_settlements:
		if existing.battle_id == receipt.battle_id:
			if RECORD.canonical_key(existing) == RECORD.canonical_key(receipt):
				return {"ok": true, "duplicate": true, "value": null, "error": null}
			return _failure("settlement_conflict")
	if not state.pending_reward_battle_id.is_empty():
		return _failure("reward_pending")
	if not state.is_playable():
		return _failure("run_lost")
	var coord := Vector2i(int(receipt.encounter_coord[0]), int(receipt.encounter_coord[1]))
	if coord != state.player_coord or (receipt.encounter_type == "boss" and (coord != state.boss_coord or not state.boss_engaged)):
		return _failure("encounter_mismatch")
	var health: Dictionary[StringName, int] = state.get_character_hp_snapshot()
	var recovered: Dictionary = {}
	for row: Dictionary in receipt.terminal_player_health:
		var id := StringName(row.character_id)
		if not health.has(id):
			return _failure("player_membership")
		recovered[String(id)] = PostBattleRecoveryRules.calculate_next_hp(id, int(row.final_hp), int(row.max_hp))
	if recovered.size() != health.size():
		return _failure("player_membership")
	var data: Dictionary = state.to_dictionary()
	var award: int = int(receipt.earned_gold)
	if state.gold > STATE.MAX_GOLD - award:
		return _failure("gold_overflow")
	if receipt.outcome == "victory":
		data["pending_reward_battle_id"] = String(receipt.battle_id)
		data["gold"] = state.gold + award
		data["character_hp"] = recovered
		if receipt.encounter_type == "boss":
			data["boss_engaged"] = false
			data["boss_active"] = false
		if receipt.encounter_type == "combat":
			if data["consumed_encounters"].has(receipt.encounter_coord):
				return _failure("encounter_consumed")
			data["consumed_encounters"].append(receipt.encounter_coord.duplicate())
	else:
		data["run_status"] = "lost"
	data["battle_preparation"] = {"state": "none"}
	data["battle_settlements"].append(receipt.duplicate(true))
	var decoded: Dictionary = STATE.from_dictionary(data, plan)
	if not decoded.get("ok", false):
		return _failure("invalid_candidate")
	return {"ok": true, "duplicate": false, "value": decoded.value, "error": null}

static func _failure(reason: String) -> Dictionary:
	return {"ok": false, "value": null, "error": reason}
