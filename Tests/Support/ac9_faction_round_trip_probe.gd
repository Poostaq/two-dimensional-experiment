class_name AC9FactionRoundTripProbe
extends RefCounted


static func verify(identities: Array[StringName], run_id: String) -> Dictionary:
	var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(
		func(_plan: RefCounted) -> void: pass
	)
	var session: Dictionary = service.start(run_id)
	if not session.get("ok", false):
		return _failure("save fixture failed")
	var plan: WorldPlan = session.plan
	var source_state: RefCounted = session.run_state
	var codec: Script = load("res://Scripts/Save/world_run_save_codec_v5.gd") as Script
	for identity: StringName in identities:
		var character: RunCharacter = RunCharacterCatalog.create_by_class_id(identity)
		if not is_instance_valid(character):
			return _failure("identity does not construct: %s" % identity)
		var state_data: Dictionary = source_state.to_dictionary()
		state_data.formation = [String(identity), "", "", "", "", ""]
		state_data.character_hp = {String(identity): character.max_hp}
		var rebuilt: Dictionary = WorldRunState.from_dictionary(state_data, plan)
		if not rebuilt.get("ok", false):
			return _failure("identity does not enter valid save state: %s" % identity)
		var bytes: PackedByteArray = codec.encode(plan, run_id, rebuilt.value)
		var decoded: Dictionary = codec.decode_any(bytes)
		if not decoded.get("ok", false):
			return _failure("identity does not decode: %s" % identity)
		var restored_id: StringName = decoded.value.run_state.formation[0]
		var restored: RunCharacter = RunCharacterCatalog.create_by_class_id(restored_id)
		if restored_id != identity or not is_instance_valid(restored):
			return _failure("identity changed after reload: %s" % identity)
		if (
			restored.class_id != character.class_id
			or restored.root_class_id != character.root_class_id
			or restored.race_id != character.race_id
			or restored.display_name != character.display_name
		):
			return _failure("identity metadata drifted after reload: %s" % identity)
	return {
		"ok": true,
		"checked": identities.size(),
	}


static func _failure(message: String) -> Dictionary:
	return {
		"ok": false,
		"error": message,
	}
