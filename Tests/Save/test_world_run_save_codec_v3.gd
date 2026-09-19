class_name WorldRunSaveCodecV3Tests
extends SceneTree

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var path: String = "res://Scripts/Save/world_run_save_codec_v3.gd"
	_expect(ResourceLoader.exists(path), "V3 wallet codec exists")
	if not ResourceLoader.exists(path):
		_finish()
		return
	var codec: GDScript = load(path)
	var legacy: GDScript = load("res://Scripts/Save/world_run_save_codec_v2.gd")
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
	var state: RefCounted = session["run_state"]
	var plan: RefCounted = session["plan"]
	var root: Dictionary = {}
	for amount: int in [0, 100, 375, 9007199254740991]:
		state.set("gold", amount)
		var bytes: PackedByteArray = codec.encode(plan, "golden-alpha", state)
		_expect(not bytes.is_empty(), "valid state encodes")
		_expect(bytes == codec.encode(plan, "golden-alpha", state), "V3 encoding byte stable")
		root = JSON.parse_string(bytes.get_string_from_utf8())
		_expect(root["save_version"] == 3, "writer uses V3")
		var restored: Dictionary = codec.decode_any(bytes)
		_expect(restored.get("ok", false), "V3 loads")
		if restored.get("ok", false):
			_expect(restored["value"]["run_state"].canonical_key() == state.canonical_key(), "V3 preserves all state")
	var missing: Dictionary = root.duplicate(true)
	missing["world"]["run_state"].erase("gold")
	_reject(codec, missing, "missing gold")
	for invalid: Variant in [-1, 1.5, "100", true, null, 9007199254740992]:
		var malformed: Dictionary = root.duplicate(true)
		malformed["world"]["run_state"]["gold"] = invalid
		_reject(codec, malformed, "malformed gold")
	for version: Variant in [0, 4, 2.5, "3", true, null]:
		var malformed: Dictionary = root.duplicate(true)
		malformed["save_version"] = version
		_reject(codec, malformed, "malformed or unsupported version")
	var corrupt: Dictionary = root.duplicate(true)
	corrupt["world"]["canonical_plan_sha256"] = "bad"
	_reject(codec, corrupt, "bad plan hash")
	state.set("gold", 375)
	state.set("move_count", 7)
	state.set("player_coord", Vector2i.ZERO)
	state.consumed_encounters.append(plan.get_start_coord())
	var health: Dictionary[StringName, int] = {}
	for character_id: StringName in state.formation:
		if not character_id.is_empty():
			health[character_id] = 1
	_expect(state.set_character_hp_snapshot(health), "legacy fixture has non-default HP")
	var first: StringName = state.formation[0]
	state.formation[0] = state.formation[3]
	state.formation[3] = first
	state.cache_move_progress = 2
	state.cache_ready = false
	var preparation_script: GDScript = load("res://Scripts/Battle/battle_preparation_record.gd")
	state.battle_preparation = preparation_script.committed(&"ac8-legacy", Vector2i.ZERO, "combat", "legacy-setup", preparation_script.Choice.SPARE_PLATING)
	var v2: PackedByteArray = legacy.encode(plan, "golden-alpha", state)
	var old_root: Dictionary = JSON.parse_string(v2.get_string_from_utf8())
	_expect(not old_root["world"]["run_state"].has("gold"), "V2 writer remains pre-economy")
	var migrated: Dictionary = codec.decode_any(v2)
	_expect(migrated.get("ok", false), "V2 remains readable")
	if migrated.get("ok", false):
		var old_state: RefCounted = migrated["value"]["run_state"]
		_expect(old_state.gold == 0, "old run receives no new-run allowance")
		var expected: Dictionary = state.to_dictionary()
		expected["gold"] = 0
		_expect(old_state.to_dictionary() == expected, "migration preserves non-wallet state")
		var again: Dictionary = codec.decode_any(codec.encode(plan, "golden-alpha", old_state))
		_expect(again.get("ok", false) and again["value"]["run_state"].gold == 0, "migration remains zero after V3 save")
	var v1: GDScript = load("res://Scripts/Save/world_save_codec_v1.gd")
	var v1_bytes: PackedByteArray = v1.encode(plan, {"player_coord": plan.get_start_coord(), "boss_coord": plan.get_boss_coord(), "move_count": 0, "sudden_death_active": false})
	_expect(codec.decode_any(v1_bytes).get("ok", false), "V1 dispatch retained")
	state.set("gold", -1)
	_expect(codec.encode(plan, "golden-alpha", state).is_empty(), "invalid live balance cannot be saved")
	_finish()


func _reject(codec: GDScript, root: Dictionary, message: String) -> void:
	var decoded: Dictionary = codec.decode_any(JSON.stringify(root).to_utf8_buffer())
	_expect(not decoded.get("ok", true), message + " rejected")
	if not decoded.get("ok", true):
		_expect(is_instance_valid(decoded.get("error")), message + " has typed error")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _finish() -> void:
	if _failures == 0:
		print("PASS test_world_run_save_codec_v3")
	quit(0 if _failures == 0 else 1)
