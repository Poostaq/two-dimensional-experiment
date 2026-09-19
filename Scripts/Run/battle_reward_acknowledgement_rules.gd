class_name BattleRewardAcknowledgementRules
extends RefCounted

static func build_candidate(state: RefCounted, plan: WorldPlan, battle_id: String) -> Dictionary:
	if not is_instance_valid(state) or not state.is_valid(plan) or not state.is_playable() or battle_id.is_empty():
		return {"ok": false, "value": null, "error": "invalid_acknowledgement"}
	var known_victory: bool = false
	for receipt: Dictionary in state.battle_settlements:
		if receipt.battle_id == battle_id and receipt.outcome == "victory":
			known_victory = true
	if not known_victory:
		return {"ok": false, "value": null, "error": "unknown_reward"}
	if state.pending_reward_battle_id.is_empty():
		return {"ok": true, "duplicate": true, "value": null, "error": null}
	if state.pending_reward_battle_id != battle_id:
		return {"ok": false, "value": null, "error": "stale_reward"}
	var data: Dictionary = state.to_dictionary()
	data["pending_reward_battle_id"] = ""
	var decoded: Dictionary = load("res://Scripts/Run/world_run_state.gd").from_dictionary(data, plan)
	if not decoded.get("ok", false):
		return {"ok": false, "value": null, "error": "invalid_candidate"}
	return {"ok": true, "duplicate": false, "value": decoded.value, "error": null}
