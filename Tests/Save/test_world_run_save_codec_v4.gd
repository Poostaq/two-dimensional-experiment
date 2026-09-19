extends SceneTree

var failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var path: String = "res://Scripts/Save/world_run_save_codec_v4.gd"
	if not ResourceLoader.exists(path):
		_expect(false, "V4 codec exists")
		quit(1)
		return
	var codec: Script = load(path)
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
	var state: RefCounted = session.run_state
	var plan: WorldPlan = session.plan
	var bytes: PackedByteArray = codec.encode(plan, "golden-alpha", state)
	_expect(not bytes.is_empty(), "new active state encodes")
	var decoded: Dictionary = codec.decode_any(bytes)
	_expect(decoded.get("ok", false), "active V4 decodes")
	if not decoded.get("ok", false):
		quit(1)
		return
	_expect(decoded.value.run_state.is_playable(), "active is playable")
	var root_data: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	_expect(root_data.save_version == 4, "writer is V4")
	for field: String in ["run_status", "battle_settlements", "gold", "character_hp"]:
		var bad: Dictionary = root_data.duplicate(true)
		bad.world.run_state.erase(field)
		_reject(codec, bad, "missing " + field)
	for status: Variant in ["LOST", "", true, null, "pending"]:
		var bad: Dictionary = root_data.duplicate(true)
		bad.world.run_state.run_status = status
		_reject(codec, bad, "bad status")
	for value: Variant in [true, -1, 0.5, "3"]:
		var bad: Dictionary = root_data.duplicate(true)
		bad.world.run_state.move_count = value
		_reject(codec, bad, "bad count")
	for field: String in ["boss_active", "boss_engaged", "cache_ready"]:
		var bad: Dictionary = root_data.duplicate(true)
		bad.world.run_state[field] = 1
		_reject(codec, bad, "numeric boolean " + field)
	for field: String in ["player_coord", "boss_coord"]:
		var bad: Dictionary = root_data.duplicate(true)
		bad.world.run_state[field][0] = 0.25
		_reject(codec, bad, "fractional coord")
	for level: String in ["root", "world"]:
		var bad: Dictionary = root_data.duplicate(true)
		if level == "root":
			bad.unexpected = 1
		else:
			bad.world.unexpected = 1
		_reject(codec, bad, "extra " + level)
	var extra: Dictionary = root_data.duplicate(true)
	extra.world.run_state.unexpected = true
	_reject(codec, extra, "unknown field")
	var lost: Dictionary = root_data.duplicate(true)
	lost.world.run_state.run_status = "lost"
	_reject(codec, lost, "loss needs receipt")
	var coord: Vector2i = plan.get_boss_coord()
	var receipt: Dictionary = {"battle_id":"boss","encounter_type":"boss","encounter_coord":[coord.x,coord.y],"outcome":"defeat","enemy_ids":["enemy_1"],"defeated_enemy_ids":[],"terminal_player_health":[{"character_id":"player_1","final_hp":0,"max_hp":14}],"earned_gold":0}
	lost.world.run_state.battle_settlements = [receipt]
	var terminal: Dictionary = codec.decode_any(JSON.stringify(lost).to_utf8_buffer())
	_expect(terminal.get("ok", false), "lost is structurally valid")
	if terminal.get("ok", false):
		_expect(not terminal.value.run_state.is_playable(), "lost intentionally not playable")
	for change: Dictionary in [{"earned_gold":50},{"enemy_ids":["a","a"]},{"defeated_enemy_ids":["unknown"]},{"battle_id":"boss:0:0"},{"terminal_player_health":[{"character_id":"enemy_1","final_hp":0,"max_hp":14}]}]:
		var bad: Dictionary = lost.duplicate(true)
		bad.world.run_state.battle_settlements[0].merge(change, true)
		_reject(codec, bad, "invalid receipt " + str(change))
	var active_loss: Dictionary = lost.duplicate(true)
	active_loss.world.run_state.run_status = "active"
	_reject(codec, active_loss, "active cannot contain loss")
	var duplicated: Dictionary = lost.duplicate(true)
	duplicated.world.run_state.battle_settlements.append(receipt.duplicate(true))
	_reject(codec, duplicated, "duplicate receipt")
	var old: Script = load("res://Scripts/Save/world_run_save_codec_v3.gd")
	var old_bytes: PackedByteArray = old.encode(plan, "golden-alpha", state)
	_expect(codec.decode_any(old_bytes).get("ok", false), "legacy active migrates")
	var disguised: Dictionary = JSON.parse_string(old_bytes.get_string_from_utf8())
	disguised.world.run_state.run_status = "lost"
	_reject(codec, disguised, "legacy terminal injection rejected")
	var repo: RefCounted = load("res://Scripts/Run/world_single_slot_repository.gd").new("user://ac8-2-codec-test.json")
	repo.replace_atomic(JSON.stringify(lost).to_utf8_buffer())
	_expect(repo.inspect_slot().get("ok", false), "inspection sees valid lost state")
	var playable: Dictionary = repo.load_validated()
	_expect(not playable.get("ok", true) and playable.get("value") == null, "domain load rejects lost")
	_expect(playable.error.code == "RUN_LOST", "dedicated loss error")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://ac8-2-codec-test.json"))
	if failures == 0:
		print("PASS test_world_run_save_codec_v4")
	quit(0 if failures == 0 else 1)

func _reject(codec: Script, value: Dictionary, message: String) -> void:
	var result: Dictionary = codec.decode_any(JSON.stringify(value).to_utf8_buffer())
	_expect(not result.get("ok", true) and result.get("value") == null, message)

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
