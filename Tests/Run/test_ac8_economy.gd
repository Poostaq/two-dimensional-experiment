class_name AC8EconomyTests
extends SceneTree

var _failures: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var service_script: GDScript = load("res://Scripts/Run/world_run_start_service.gd")
	var state_script: GDScript = load("res://Scripts/Run/world_run_state.gd")
	var service: RefCounted = service_script.new(func(_plan: RefCounted) -> void: pass)
	var session: Dictionary = service.start("golden-alpha")
	_expect(session.get("ok", false), "new run succeeds")
	if not session.get("ok", false):
		_finish()
		return
	var state: RefCounted = session["run_state"]
	_expect(state.get("gold") == 100, "new run starts with exactly 100g")
	var data: Dictionary = state.to_dictionary()
	_expect(data.has("gold"), "wallet is serialized")
	if not data.has("gold"):
		_finish()
		return
	var initial_key: String = state.canonical_key()
	for amount: int in [0, 100, 375, 9007199254740991]:
		data["gold"] = amount
		var decoded: Dictionary = state_script.from_dictionary(data, session["plan"])
		_expect(decoded.get("ok", false), "valid balance %d accepted" % amount)
		if decoded.get("ok", false):
			_expect(decoded["value"].gold == amount, "balance round trips exactly")
	data["gold"] = 375
	var changed: Dictionary = state_script.from_dictionary(data, session["plan"])
	_expect(changed["value"].canonical_key() != initial_key, "wallet affects canonical identity")
	for invalid: Variant in [-1, 1.5, "100", true, null, INF, NAN, 9007199254740992]:
		data["gold"] = invalid
		_expect(not state_script.from_dictionary(data, session["plan"]).get("ok", true), "invalid gold rejected: %s" % str(invalid))
	data.erase("gold")
	_expect(not state_script.from_dictionary(data, session["plan"]).get("ok", true), "current state requires gold")
	state.set("gold", -1)
	_expect(not state.is_valid(session["plan"]), "negative live gold invalid")
	state.set("gold", 375)
	var next_session: Dictionary = service.start("golden-beta")
	_expect(next_session.get("ok", false), "second run succeeds")
	if next_session.get("ok", false):
		_expect(next_session["run_state"].gold == 100, "second run gets fresh 100g")
		_expect(state.gold == 375, "second run does not mutate first wallet")
	for commander_id: StringName in GoblinCommanderCatalog.get_commander_ids():
		var commander_session: Dictionary = service.start("golden-alpha", {}, service_script.RETURN_RESULT, commander_id)
		_expect(commander_session.get("ok", false) and commander_session["run_state"].gold == 100, "every supported commander starts with 100g")
	var formation: Array[StringName] = state.formation
	var consumed: Array[Vector2i] = []
	var zero_state: RefCounted = state_script.create(session["plan"].get_start_coord(), session["plan"].get_boss_coord(), 0, false, false, consumed, formation)
	_expect(zero_state.get("gold") == 0, "ordinary construction grants no allowance")
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _finish() -> void:
	if _failures == 0:
		print("PASS test_ac8_economy")
	quit(0 if _failures == 0 else 1)
