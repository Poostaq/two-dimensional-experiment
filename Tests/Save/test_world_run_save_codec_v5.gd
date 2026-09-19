class_name WorldRunSaveCodecV5Tests
extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path: String = "res://Scripts/Save/world_run_save_codec_v5.gd"
	if not ResourceLoader.exists(path):
		_expect(false, "V5 codec exists")
		quit(1)
		return
	var codec: Script = load(path)
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_p: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
	var plan: WorldPlan = session.plan
	var state: RefCounted = session.run_state
	var fresh: PackedByteArray = codec.encode(plan, "golden-alpha", state)
	_expect(not fresh.is_empty(), "fresh V5 encodes")
	if fresh.is_empty():
		quit(1)
		return
	var root_data: Dictionary = JSON.parse_string(fresh.get_string_from_utf8())
	_expect(root_data.save_version == 5, "writer declares V5")
	_expect(root_data.world.run_state.pending_reward_battle_id == "", "fresh pending empty")
	for version: int in [2, 3, 4]:
		var old: Script = load("res://Scripts/Save/world_run_save_codec_v%d.gd" % version)
		var bytes: PackedByteArray = old.encode(plan, "golden-alpha", state)
		var legacy: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
		_expect(not legacy.world.run_state.has("pending_reward_battle_id"), "legacy schema unchanged")
		var migrated: Dictionary = codec.decode_any(bytes)
		_expect(migrated.get("ok", false) and migrated.value.run_state.pending_reward_battle_id == "", "legacy normalizes empty")
		legacy.world.run_state.pending_reward_battle_id = ""
		_reject(codec, legacy, "legacy new field injection rejects")
	var v4: Dictionary = JSON.parse_string(load("res://Scripts/Save/world_run_save_codec_v4.gd").encode(plan, "golden-alpha", state).get_string_from_utf8())
	var expected: Dictionary = v4.world.run_state.duplicate(true)
	expected.pending_reward_battle_id = ""
	_expect(root_data.world.run_state == expected, "V5 adds exactly one state field")
	var missing: Dictionary = root_data.duplicate(true)
	missing.world.run_state.erase("pending_reward_battle_id")
	_reject(codec, missing, "missing pending rejects")
	for invalid: Variant in [null, true, 4, [], {}, "unknown"]:
		var bad: Dictionary = root_data.duplicate(true)
		bad.world.run_state.pending_reward_battle_id = invalid
		_reject(codec, bad, "malformed pending rejects without fallback")
	var future: Dictionary = root_data.duplicate(true)
	future.save_version = 6
	_reject(codec, future, "future version rejects")
	var coords: Array[Vector2i] = []
	for coord: Vector2i in plan.get_cells():
		if plan.get_cells()[coord].get("encounter") == "combat":
			coords.append(coord)
	for kind: String in ["combat", "boss"]:
		var coord: Vector2i = coords[0] if kind == "combat" else plan.get_boss_coord()
		var original: RefCounted = load("res://Scripts/Run/world_run_state.gd").from_dictionary(state.to_dictionary(), plan).value
		original.player_coord = coord
		if kind == "boss":
			original.move_count = 30
			original.boss_active = true
			original.boss_engaged = true
		var health: Dictionary[StringName, int] = {&"hero": 20}
		original.set_character_hp_snapshot(health)
		var receipt: Dictionary = _receipt(kind, coord)
		var built: Dictionary = load("res://Scripts/Run/battle_settlement_rules.gd").build_candidate(original, plan, receipt)
		_expect(built.get("ok", false), kind + " settlement valid")
		if not built.get("ok", false):
			continue
		var pending: RefCounted = built.value
		var bytes: PackedByteArray = codec.encode(plan, "golden-alpha", pending)
		var decoded: Dictionary = codec.decode_any(bytes)
		_expect(decoded.get("ok", false) and JSON.parse_string(decoded.value.run_state.canonical_key()) == JSON.parse_string(pending.canonical_key()), kind + " pending round trip")
		for version: int in [2, 3, 4]:
			_expect(load("res://Scripts/Save/world_run_save_codec_v%d.gd" % version).encode(plan, "golden-alpha", pending).is_empty(), "pending downgrade rejects")
		var bad: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
		bad.world.run_state.battle_preparation = load("res://Scripts/Battle/battle_preparation_record.gd").offered(&"prep", coords[1], "combat", "fixture").to_dictionary()
		_reject(codec, bad, "pending plus preparation rejects")
		var acknowledged: RefCounted = load("res://Scripts/Run/battle_reward_acknowledgement_rules.gd").build_candidate(pending, plan, receipt.battle_id).value
		var old_settled: PackedByteArray = load("res://Scripts/Save/world_run_save_codec_v4.gd").encode(plan, "golden-alpha", acknowledged)
		var migrated_settled: Dictionary = codec.decode_any(old_settled)
		_expect(migrated_settled.get("ok", false) and JSON.parse_string(migrated_settled.value.run_state.canonical_key()) == JSON.parse_string(acknowledged.canonical_key()), "V4 settled receipt/wallet unchanged and no retroactive panel")
		var restored: Dictionary = codec.decode_any(codec.encode(plan, "golden-alpha", acknowledged))
		_expect(restored.get("ok", false) and JSON.parse_string(restored.value.run_state.canonical_key()) == JSON.parse_string(acknowledged.canonical_key()), "acknowledged round trip")
		receipt.outcome = "defeat"
		receipt.earned_gold = 0
		var lost: RefCounted = load("res://Scripts/Run/battle_settlement_rules.gd").build_candidate(original, plan, receipt).value
		var lost_bytes: PackedByteArray = codec.encode(plan, "golden-alpha", lost)
		_expect(codec.decode_any(lost_bytes).get("ok", false), "lost round trip")
		var invalid_loss: Dictionary = JSON.parse_string(lost_bytes.get_string_from_utf8())
		invalid_loss.world.run_state.pending_reward_battle_id = receipt.battle_id
		_reject(codec, invalid_loss, "pending defeat rejects")
		if kind == "combat":
			acknowledged.player_coord = coords[1]
			var second_receipt: Dictionary = _receipt("combat", coords[1])
			var next_pending: RefCounted = load("res://Scripts/Run/battle_settlement_rules.gd").build_candidate(acknowledged, plan, second_receipt).value
			var stale: Dictionary = JSON.parse_string(codec.encode(plan, "golden-alpha", next_pending).get_string_from_utf8())
			stale.world.run_state.pending_reward_battle_id = receipt.battle_id
			_reject(codec, stale, "pending must reference final victory")
	if failures == 0:
		print("PASS test_world_run_save_codec_v5")
	quit(0 if failures == 0 else 1)

func _receipt(kind: String, coord: Vector2i) -> Dictionary:
	return {"battle_id":load("res://Scripts/Battle/battle_result_record.gd").encounter_id(kind, coord),"encounter_type":kind,"encounter_coord":[coord.x,coord.y],"outcome":"victory","enemy_ids":["a","b","c"],"defeated_enemy_ids":["a","b","c"],"terminal_player_health":[{"character_id":"hero","final_hp":0,"max_hp":20}],"earned_gold":150}

func _reject(codec: Script, value: Dictionary, message: String) -> void:
	var result: Dictionary = codec.decode_any(JSON.stringify(value).to_utf8_buffer())
	_expect(not result.get("ok", true) and result.get("value") == null, message)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
