extends SceneTree
var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists("res://Scripts/Run/battle_settlement_rules.gd"):
		_expect(false, "settlement rules exist")
		quit(1)
		return
	var rules: Script = load("res://Scripts/Run/battle_settlement_rules.gd")
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
	var state: RefCounted = session.run_state
	var plan: WorldPlan = session.plan
	var starting_health: Dictionary[StringName, int] = {}
	for unit: BattleUnitState in RunRoster.new().create_battle_units():
		starting_health[unit.unit_id] = unit.max_hp
	state.set_character_hp_snapshot(starting_health)
	var coord := Vector2i.ZERO
	for cell: Vector2i in plan.get_cells():
		if plan.get_cells()[cell].get("encounter") == "combat":
			coord = cell
			break
	state.player_coord = coord
	var health: Array = []
	for id: StringName in state.get_character_hp_snapshot():
		health.append({"character_id":String(id),"final_hp":0,"max_hp":int(state.get_character_hp_snapshot()[id])})
	health.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.character_id < b.character_id)
	var record: Script = load("res://Scripts/Battle/battle_result_record.gd")
	var receipt: Dictionary = {"battle_id":record.encounter_id("combat", coord),"encounter_type":"combat","encounter_coord":[coord.x,coord.y],"outcome":"victory","enemy_ids":["a","b","c"],"defeated_enemy_ids":["a","b","c"],"terminal_player_health":health,"earned_gold":150}
	var before: String = state.canonical_key()
	var result: Dictionary = rules.build_candidate(state, plan, receipt)
	_expect(result.get("ok", false), "valid victory builds")
	if result.get("ok", false):
		var candidate: RefCounted = result.value
		_expect(candidate.pending_reward_battle_id == receipt.battle_id, "victory stages pending presentation")
		_expect(candidate.gold == 250 and candidate.consumed_encounters.has(coord), "gold and consumption together")
		_expect(candidate.get_character_hp_snapshot().values()[0] > 0, "recovery together")
		_expect(state.canonical_key() == before, "candidate leaves live state unchanged")
		var duplicate: Dictionary = rules.build_candidate(candidate, plan, receipt)
		_expect(duplicate.get("duplicate", false), "same result no-op")
		var conflict: Dictionary = receipt.duplicate(true)
		conflict.terminal_player_health[0].final_hp = 1
		_expect(not rules.build_candidate(candidate, plan, conflict).get("ok", true), "changed HP conflicts")
	receipt.outcome = "defeat"
	receipt.earned_gold = 0
	var loss: Dictionary = rules.build_candidate(state, plan, receipt)
	_expect(loss.get("ok", false), "loss builds")
	if loss.get("ok", false):
		_expect(loss.value.pending_reward_battle_id.is_empty(), "loss never stages a reward")
		_expect(loss.value.gold == 100 and not loss.value.is_playable(), "loss no gold terminal")
		_expect(loss.value.get_character_hp_snapshot() == state.get_character_hp_snapshot(), "loss preserves durable health")
		_expect(not loss.value.consumed_encounters.has(coord), "loss no consume")
	if failures == 0:
		print("PASS test_ac8_2_battle_settlement_rules")
	quit(0 if failures == 0 else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
