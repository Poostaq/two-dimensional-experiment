class_name Ac9_0RosterIdentityRoundTripTests
extends SceneTree

const FACTION_IDS: Array[StringName] = [&"goblin", &"orc", &"lizardman", &"werewolf", &"harpy", &"human", &"elf", &"dwarf"]
const COMMANDER_IDS: Array[StringName] = [&"brakka_rustbanner", &"goruk_ironline", &"sszek_still_mire", &"veyra_moontrace", &"kyris_windscar", &"marshal_elian_voss", &"lady_saelith_moonfall", &"thane_brokk_stonevein"]

var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var regular_ids: Array[StringName] = []
	for faction_id: StringName in FACTION_IDS:
		regular_ids.append_array(RunCharacterCatalog.get_recruitable_class_ids(faction_id))
	_expect(regular_ids.size() == 48, "Exactly 48 regular roster identities are registered")
	_expect(COMMANDER_IDS.size() == 8, "Exactly eight commander identities are registered")
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(func(_plan: RefCounted) -> void: pass)
	var session: Dictionary = service.start("ac9-roster-round-trip")
	_expect(session.get("ok", false), "AC9 save fixture starts")
	if not session.get("ok", false):
		_finish()
		return
	var plan: WorldPlan = session.plan
	var source_state: RefCounted = session.run_state
	var codec := load("res://Scripts/Save/world_run_save_codec_v5.gd") as Script
	var all_ids: Array[StringName] = regular_ids.duplicate()
	all_ids.append_array(COMMANDER_IDS)
	for identity: StringName in all_ids:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(identity)
		_expect(is_instance_valid(character), "Roster identity constructs: %s" % identity)
		if not is_instance_valid(character):
			continue
		var expected_skill_count: int = 4 if COMMANDER_IDS.has(identity) else 3
		_expect(character.get_skills().size() == expected_skill_count, "Roster identity has expected skill count: %s" % identity)
		var state_data: Dictionary = source_state.to_dictionary()
		state_data.formation = [String(identity), "", "", "", "", ""]
		state_data.character_hp = {String(identity): character.max_hp}
		var rebuilt: Dictionary = WorldRunState.from_dictionary(state_data, plan)
		_expect(rebuilt.get("ok", false), "Roster identity enters a valid save state: %s" % identity)
		if not rebuilt.get("ok", false):
			continue
		var bytes: PackedByteArray = codec.encode(plan, "ac9-roster-round-trip", rebuilt.value)
		var decoded: Dictionary = codec.decode_any(bytes)
		_expect(decoded.get("ok", false), "Roster identity decodes from V5: %s" % identity)
		if not decoded.get("ok", false):
			continue
		var restored_id: StringName = decoded.value.run_state.formation[0]
		var restored: RunCharacter = RunCharacterCatalog.create_by_class_id(restored_id)
		_expect(restored_id == identity and is_instance_valid(restored), "Roster identity survives save/reload: %s" % identity)
		if is_instance_valid(restored):
			_expect(restored.class_id == character.class_id and restored.race_id == character.race_id and restored.display_name == character.display_name, "Roster metadata resolves without drift: %s" % identity)
	_finish()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.0 roster identity: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
