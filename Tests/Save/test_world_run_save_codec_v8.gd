extends SceneTree

const START_SERVICE_PATH := "res://Scripts/Run/world_run_start_service.gd"
const GENERATOR_V1_PATH := "res://Scripts/WorldMap/hex_world_generator_v1.gd"
const GENERATOR_V2_PATH := "res://Scripts/WorldMap/hex_world_generator_v2.gd"
const V8_CODEC_PATH := "res://Scripts/Save/world_run_save_codec_v8.gd"
const PLAN_CODEC_PATH := "res://Scripts/WorldMap/world_plan_codec.gd"
const WORLD_PLAN_PATH := "res://Scripts/WorldMap/world_plan.gd"

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var codec_script: GDScript = load(V8_CODEC_PATH)
	_expect(is_instance_valid(codec_script), "V8 codec exists")
	if not is_instance_valid(codec_script):
		_finish()
		return
	var started: Dictionary = _start_v3()
	_expect(bool(started.get("ok", false)), "fixed-identity V3 run starts")
	if not bool(started.get("ok", false)):
		_finish()
		return
	var bytes: PackedByteArray = _encode(codec_script, started)
	_test_v3_round_trip(codec_script, started, bytes)
	_test_encode_identity_rejections(codec_script, started)
	_test_invalid_plan_encode_rejection(codec_script, started)
	_test_decode_identity_rejections(codec_script, bytes)
	_test_version_and_integrity_rejections(codec_script, bytes)
	_test_v2_round_trip(codec_script)
	_test_v1_round_trip(codec_script)
	_finish()


func _test_v3_round_trip(
	codec_script: GDScript,
	started: Dictionary,
	bytes: PackedByteArray
) -> void:
	_expect(not bytes.is_empty(), "V8 encodes a V3 generated run")
	if bytes.is_empty():
		return
	var root: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	_expect(root is Dictionary, "V8 payload is JSON")
	if not root is Dictionary:
		return
	var expected_world_keys: Array[String] = [
		"generator_version",
		"run_seed_utf8_hex",
		"resolved_seed",
		"canonical_plan_utf8",
		"canonical_plan_sha256",
		"run_state",
		"main_clan_id",
		"commander_id",
		"allied_clan_ids",
		"enemy_clan_id",
		"boss_party_id",
	]
	_expect(root.size() == 4, "V8 root field count is unchanged")
	_expect(_keys_match(root.world, expected_world_keys), "V8 world field shape is unchanged")
	_expect(root.world.generator_version == 3, "V8 stores V3 generator version")
	var canonical_bytes: PackedByteArray = String(root.world.canonical_plan_utf8).to_utf8_buffer()
	_expect(not canonical_bytes.is_empty(), "V8 stores nonempty canonical plan bytes")
	_expect(
		root.world.canonical_plan_sha256 == _sha256(canonical_bytes),
        "V8 checksum covers exact canonical plan bytes"
	)

	var decoded: Dictionary = codec_script.decode_any(bytes)
	_expect(bool(decoded.get("ok", false)), "V8 V3 round trip decodes")
	if not bool(decoded.get("ok", false)):
		return
	var value: Dictionary = decoded["value"]
	_expect(value.plan.get_version() == 3, "decoded plan stays V3")
	_expect(value.plan.get_start_coord() == Vector2i(-8, 0), "decoded player remains west")
	_expect(value.plan.get_boss_coord() == Vector2i(8, 0), "decoded boss remains east")
	_expect(value.plan.get_habitats().size() == 4, "decoded habitats preserved")
	_expect(value.plan.get_towns().size() == 9, "decoded towns preserved")
	_expect(value.plan.get_roads().size() == 9, "decoded internal roads are preserved")
	_expect(value.run_state.canonical_key() == started.run_state.canonical_key(), "run state preserved")
	_expect(value.selection.main_clan_id == started.selection.main_clan_id, "main selection preserved")
	_expect(
		value.coalition.allied_clan_ids == started.coalition.allied_clan_ids,
        "ordered allies preserved"
	)
	_expect(
		value.enemy_boss_selection.enemy_clan_id
		== started.enemy_boss_selection.enemy_clan_id,
        "enemy clan preserved"
	)
	_expect(
		value.enemy_boss_selection.boss_party_id
		== started.enemy_boss_selection.boss_party_id,
        "boss party preserved"
	)
	var facade: GDScript = load(PLAN_CODEC_PATH)
	_expect(
		facade.serialize(value.plan) == canonical_bytes,
        "decode reconstructs the persisted canonical bytes without generation"
	)


func _test_encode_identity_rejections(codec_script: GDScript, started: Dictionary) -> void:
	var other_selection_result: Dictionary = RunClanSelection.create(
		&"orc",
		&"goruk_ironline",
		started.resolved_seed
	)
	var other_selection: RunClanSelection = other_selection_result.get("value")
	var other_coalition_result: Dictionary = RunAlliedClanSelector.select(
		&"orc",
		started.resolved_seed
	)
	var other_coalition: RunClanCoalition = other_coalition_result.get("value")
	_expect(
		codec_script.encode(
			started.plan,
			started.resolved_seed,
			started.run_state,
			other_selection,
			other_coalition,
			started.enemy_boss_selection
		).is_empty(),
        "V3 encode rejects main clan identity mismatch"
	)

	var ally_zero_mismatch := _coalition_copy(started.coalition)
	ally_zero_mismatch.allied_clan_ids[0] = &"lizardman"
	_expect(
		codec_script.encode(
			started.plan,
			started.resolved_seed,
			started.run_state,
			started.selection,
			ally_zero_mismatch,
			started.enemy_boss_selection
		).is_empty(),
        "V3 encode rejects ally position zero mismatch"
	)
	var ally_one_mismatch := _coalition_copy(started.coalition)
	ally_one_mismatch.allied_clan_ids[1] = &"lizardman"
	_expect(
		codec_script.encode(
			started.plan,
			started.resolved_seed,
			started.run_state,
			started.selection,
			ally_one_mismatch,
			started.enemy_boss_selection
		).is_empty(),
        "V3 encode rejects ally position one mismatch"
	)

	var enemy_result: Dictionary = RunEnemyBossSelection.create(
		started.resolved_seed,
		&"elf",
		&"elf_moonfall_exposure_v1"
	)
	var other_enemy: RefCounted = enemy_result.get("value")
	_expect(
		codec_script.encode(
			started.plan,
			started.resolved_seed,
			started.run_state,
			started.selection,
			started.coalition,
			other_enemy
		).is_empty(),
        "V3 encode rejects enemy clan identity mismatch"
	)
	_expect(
		codec_script.encode(
			started.plan,
			started.resolved_seed,
			started.run_state,
			null,
			started.coalition,
			started.enemy_boss_selection
		).is_empty(),
        "V3 encode rejects missing selection"
	)
	_expect(
		codec_script.encode(
			started.plan,
			started.resolved_seed,
			started.run_state,
			started.selection,
			null,
			started.enemy_boss_selection
		).is_empty(),
        "V3 encode rejects missing coalition"
	)
	_expect(
		codec_script.encode(
			started.plan,
			started.resolved_seed,
			started.run_state,
			started.selection,
			started.coalition,
			null
		).is_empty(),
        "V3 encode rejects missing enemy selection"
	)
	_expect(
		codec_script.encode(
			null,
			started.resolved_seed,
			started.run_state,
			started.selection,
			started.coalition,
			started.enemy_boss_selection
		).is_empty(),
        "V3 encode rejects invalid plan"
	)
	var unsupported_plan: RefCounted = _copy_plan_with_version(started.plan, 4)
	_expect(
		codec_script.encode(
			unsupported_plan,
			started.resolved_seed,
			started.run_state,
			started.selection,
			started.coalition,
			started.enemy_boss_selection
		).is_empty(),
        "V3 encode rejects unsupported plan version"
	)


func _test_invalid_plan_encode_rejection(
	codec_script: GDScript,
	started: Dictionary
) -> void:
	var invalid_plan: RefCounted = _copy_plan_with_forests(started.plan, [])
	_expect(
		codec_script.encode(
			invalid_plan,
			started.resolved_seed,
			started.run_state,
			started.selection,
			started.coalition,
			started.enemy_boss_selection
		).is_empty(),
        "V8 encode rejects structurally invalid V3 plan before serialization"
	)


func _test_decode_identity_rejections(codec_script: GDScript, bytes: PackedByteArray) -> void:
	var original: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())

	var main_mismatch: Dictionary = original.duplicate(true)
	var other_coalition_result: Dictionary = RunAlliedClanSelector.select(
		&"orc",
		String(main_mismatch.world.resolved_seed)
	)
	var other_coalition: RunClanCoalition = other_coalition_result.get("value")
	main_mismatch.world.main_clan_id = "orc"
	main_mismatch.world.commander_id = "goruk_ironline"
	main_mismatch.world.allied_clan_ids = other_coalition.allied_clan_ids.map(
		func(id: StringName) -> String: return String(id)
	)
	_expect_save_invalid(codec_script.decode_any(_json_bytes(main_mismatch)), "decode main mismatch")

	var ally_zero_mismatch: Dictionary = original.duplicate(true)
	ally_zero_mismatch.world.allied_clan_ids[0] = "lizardman"
	_expect_save_invalid(
		codec_script.decode_any(_json_bytes(ally_zero_mismatch)),
        "decode ally zero mismatch"
	)

	var ally_one_mismatch: Dictionary = original.duplicate(true)
	ally_one_mismatch.world.allied_clan_ids[1] = "lizardman"
	_expect_save_invalid(
		codec_script.decode_any(_json_bytes(ally_one_mismatch)),
        "decode ally one mismatch"
	)

	var enemy_mismatch: Dictionary = original.duplicate(true)
	enemy_mismatch.world.enemy_clan_id = "elf"
	enemy_mismatch.world.boss_party_id = "elf_moonfall_exposure_v1"
	_expect_save_invalid(codec_script.decode_any(_json_bytes(enemy_mismatch)), "decode enemy mismatch")


func _test_version_and_integrity_rejections(
	codec_script: GDScript,
	bytes: PackedByteArray
) -> void:
	var original: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())

	var mismatch: Dictionary = original.duplicate(true)
	mismatch.world.generator_version = 1
	_expect_save_invalid(
		codec_script.decode_any(_json_bytes(mismatch)),
        "envelope generator version must equal parsed plan version"
	)

	var unsupported: Dictionary = original.duplicate(true)
	unsupported.world.generator_version = 4
	_expect_failed(codec_script.decode_any(_json_bytes(unsupported)), "unsupported generator version")

	var changed_checksum: Dictionary = original.duplicate(true)
	changed_checksum.world.canonical_plan_sha256 = "00"
	_expect_save_invalid(
		codec_script.decode_any(_json_bytes(changed_checksum)),
        "altered checksum rejected"
	)

	var changed_plan: Dictionary = original.duplicate(true)
	changed_plan.world.canonical_plan_utf8 += "x"
	changed_plan.world.canonical_plan_sha256 = _sha256(
		String(changed_plan.world.canonical_plan_utf8).to_utf8_buffer()
	)
	_expect_save_invalid(codec_script.decode_any(_json_bytes(changed_plan)), "altered plan rejected")


func _test_v2_round_trip(codec_script: GDScript) -> void:
	var started: Dictionary = _start_v2()
	_expect(started.get("ok", false), "explicit V2 run starts through injection seam")
	if not started.get("ok", false):
		return
	var bytes: PackedByteArray = _encode(codec_script, started)
	_expect(not bytes.is_empty(), "V8 still encodes V2 plan")
	if bytes.is_empty():
		return
	var decoded: Dictionary = codec_script.decode_any(bytes)
	_expect(decoded.get("ok", false), "V8 V2 envelope remains readable")
	if decoded.get("ok", false):
		_expect(decoded.value.plan.get_version() == 2, "decoded compatibility plan remains V2")
		_expect(decoded.value.plan.get_roads().is_empty(), "decoded V2 roads remain empty")


func _test_v1_round_trip(codec_script: GDScript) -> void:
	var service_script: GDScript = load(START_SERVICE_PATH)
	var v1_generator: RefCounted = load(GENERATOR_V1_PATH).new()
	var service: RefCounted = service_script.new(
		func(_plan: RefCounted) -> void: pass,
		v1_generator
	)
	var started: Dictionary = service.start("v8-v1-compatibility")
	_expect(started.get("ok", false), "legacy V1 run starts through injection seam")
	if not started.get("ok", false):
		return
	var bytes: PackedByteArray = _encode(codec_script, started)
	_expect(not bytes.is_empty(), "V8 still encodes V1 plan")
	if bytes.is_empty():
		return
	var root: Dictionary = JSON.parse_string(bytes.get_string_from_utf8())
	_expect(root.world.generator_version == 1, "V8 V1 envelope keeps generator version 1")
	var decoded: Dictionary = codec_script.decode_any(bytes)
	_expect(decoded.get("ok", false), "V8 V1 envelope remains readable")
	if decoded.get("ok", false):
		_expect(decoded.value.plan.get_version() == 1, "decoded legacy plan remains V1")
		_expect(
			decoded.value.selection.main_clan_id == started.selection.main_clan_id,
            "legacy envelope selection preserved"
		)


func _start_v3() -> Dictionary:
	return _start_fixed_identity("ac9-v8-v3-round-trip")


func _start_v2() -> Dictionary:
	var generator_v2: RefCounted = load(GENERATOR_V2_PATH).new()
	return _start_fixed_identity("ac9-v8-v2-compatibility", generator_v2)


func _start_fixed_identity(seed_text: String, generator: RefCounted = null) -> Dictionary:
	var selection_result: Dictionary = RunClanSelection.create(
		&"goblin",
		&"brakka_rustbanner",
		seed_text
	)
	var coalition_result: Dictionary = RunClanCoalition.create(
		&"goblin",
		[&"orc", &"werewolf"]
	)
	var enemy_result: Dictionary = RunEnemyBossSelection.create(
		seed_text,
		&"human",
		&"human_fortified_line_v1"
	)
	var service: RefCounted = load(START_SERVICE_PATH).new(
		func(_plan: RefCounted) -> void: pass,
		generator
	)
	return service.start(
		seed_text,
		{
			"main_clan_id": &"forged",
			"allied_clan_ids": [&"forged_0", &"forged_1"],
			"enemy_clan_id": &"forged_enemy",
		},
		"RETURN_RESULT",
		&"brakka_rustbanner",
		&"goblin",
		selection_result.get("value"),
		coalition_result.get("value"),
		enemy_result.get("value")
	)


func _encode(codec_script: GDScript, started: Dictionary) -> PackedByteArray:
	return codec_script.encode(
		started.plan,
		started.resolved_seed,
		started.run_state,
		started.selection,
		started.coalition,
		started.enemy_boss_selection
	)


func _coalition_copy(source: RunClanCoalition) -> RunClanCoalition:
	var copy := RunClanCoalition.new()
	copy.main_clan_id = source.main_clan_id
	copy.allied_clan_ids = source.allied_clan_ids.duplicate()
	return copy


func _copy_plan_with_forests(plan: RefCounted, forests: Array) -> RefCounted:
	return load(WORLD_PLAN_PATH).new(
		plan.get_version(),
		plan.get_seed_hex(),
		plan.get_start_coord(),
		plan.get_boss_coord(),
		plan.get_cells(),
		plan.get_roads(),
		forests,
		plan.get_habitats(),
		plan.get_towns()
	)


func _copy_plan_with_version(plan: RefCounted, version: int) -> RefCounted:
	return load(WORLD_PLAN_PATH).new(
		version,
		plan.get_seed_hex(),
		plan.get_start_coord(),
		plan.get_boss_coord(),
		plan.get_cells(),
		plan.get_roads(),
		plan.get_forest_clusters(),
		plan.get_habitats(),
		plan.get_towns()
	)


func _expect_save_invalid(result: Dictionary, label: String) -> void:
	_expect_failed(result, label)
	if result.get("error") != null:
		_expect(
			result["error"].code == "SAVE_ENVELOPE_INVALID",
			"%s returns SAVE_ENVELOPE_INVALID" % label
		)


func _expect_failed(result: Dictionary, label: String) -> void:
	_expect(not result.get("ok", true), "%s rejected" % label)
	_expect(result.get("value") == null, "%s returns no state" % label)
	_expect(result.get("error") != null, "%s returns typed error" % label)


func _keys_match(value: Dictionary, expected: Array[String]) -> bool:
	if value.size() != expected.size():
		return false
	for key: String in expected:
		if not value.has(key):
			return false
	return true


func _json_bytes(root: Dictionary) -> PackedByteArray:
	return (JSON.stringify(root) + "\n").to_utf8_buffer()


func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _finish() -> void:
	if _failures == 0:
		print("PASS test_world_run_save_codec_v8")
	quit(1 if _failures > 0 else 0)
