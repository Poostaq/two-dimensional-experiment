class_name AC66BattlePreparationTests
extends SceneTree

const SETUP_PATH := "res://Scripts/Battle/battle_setup_identity.gd"
const RECORD_PATH := "res://Scripts/Battle/battle_preparation_record.gd"
const TRANSACTION_PATH := "res://Scripts/Battle/battle_preparation_transaction.gd"
const EXPECTED_TEST_COUNT := 33

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_expect(ResourceLoader.exists(SETUP_PATH), "battle setup identity script exists")
	_expect(ResourceLoader.exists(RECORD_PATH), "battle preparation record script exists")
	if not ResourceLoader.exists(SETUP_PATH) or not ResourceLoader.exists(RECORD_PATH):
		_finish()
		return
	var setup_script := load(SETUP_PATH) as GDScript
	var record_script := load(RECORD_PATH) as GDScript
	_test_setup_identity(setup_script)
	_test_record_contract(record_script)
	_expect(ResourceLoader.exists(TRANSACTION_PATH), "battle preparation transaction exists")
	if ResourceLoader.exists(TRANSACTION_PATH):
		_test_transaction(
			setup_script,
			record_script,
			load(TRANSACTION_PATH) as GDScript
		)
	_finish()


func _test_setup_identity(setup_script: GDScript) -> void:
	var units := _make_units()
	var first := setup_script.capture(Vector2i(2, -1), WorldEncounterType.COMBAT, units) as RefCounted
	var second := setup_script.capture(Vector2i(2, -1), "COMBAT", units) as RefCounted
	_expect(is_instance_valid(first), "valid Combat setup captures")
	_expect(is_instance_valid(second), "encounter type normalizes")
	_expect(
		is_instance_valid(first) and is_instance_valid(second)
			and first.get("canonical_key") == second.get("canonical_key"),
		"equivalent setups have equal keys"
	)
	var original_key := String(first.get("canonical_key")) if is_instance_valid(first) else ""
	units[0].slot_index = 5
	_expect(
		is_instance_valid(first) and String(first.get("canonical_key")) == original_key,
		"captured identity is immutable after caller mutation"
	)
	var moved := setup_script.capture(Vector2i(2, -1), WorldEncounterType.COMBAT, units) as RefCounted
	_expect(
		is_instance_valid(moved) and String(moved.get("canonical_key")) != original_key,
		"formation change changes setup key"
	)
	units[0].slot_index = 0
	units[1].current_hp = 0
	var inactive := setup_script.capture(Vector2i(2, -1), WorldEncounterType.COMBAT, units) as RefCounted
	_expect(
		is_instance_valid(inactive) and String(inactive.get("canonical_key")) != original_key,
		"activity change changes setup key"
	)
	_expect(
		not is_instance_valid(setup_script.capture(Vector2i.ZERO, WorldEncounterType.BOSS, units)),
		"Boss setup cannot create regular Combat identity"
	)
	units[1].unit_id = units[0].unit_id
	_expect(
		not is_instance_valid(setup_script.capture(Vector2i.ZERO, WorldEncounterType.COMBAT, units)),
		"duplicate unit IDs reject"
	)


func _test_record_contract(record_script: GDScript) -> void:
	var none := record_script.none() as RefCounted
	_expect(
		is_instance_valid(none) and int(none.get("state")) == int(record_script.State.NONE),
		"default record is NONE"
	)
	var offered := record_script.offered(
		&"prep-1", Vector2i(2, -1), WorldEncounterType.COMBAT, "setup-a"
	) as RefCounted
	_expect(is_instance_valid(offered), "valid offered record constructs")
	var offered_data := offered.call("to_dictionary") as Dictionary if is_instance_valid(offered) else {}
	_expect(offered_data.get("state") == "offered", "offered state serializes canonically")
	var offered_decoded := record_script.from_dictionary(offered_data) as Dictionary
	_expect(bool(offered_decoded.get("ok", false)), "offered record round trips")
	_expect(
		not bool(record_script.from_dictionary({"state": "unknown"}).get("ok", true)),
		"unknown state rejects"
	)
	var missing_target := record_script.committed(
		&"prep-1",
		Vector2i(2, -1),
		WorldEncounterType.COMBAT,
		"setup-a",
		record_script.Choice.FRONTLINE_BRIEFING,
		&""
	) as RefCounted
	_expect(not is_instance_valid(missing_target), "briefing requires exact target")
	var spare_with_target := record_script.committed(
		&"prep-1",
		Vector2i(2, -1),
		WorldEncounterType.COMBAT,
		"setup-a",
		record_script.Choice.SPARE_PLATING,
		&"enemy_a"
	) as RefCounted
	_expect(not is_instance_valid(spare_with_target), "Spare Plating forbids target")
	var committed := record_script.committed(
		&"prep-1",
		Vector2i(2, -1),
		WorldEncounterType.COMBAT,
		"setup-a",
		record_script.Choice.FRONTLINE_BRIEFING,
		&"enemy_a"
	) as RefCounted
	_expect(is_instance_valid(committed), "valid committed briefing constructs")
	var committed_data := committed.call("to_dictionary") as Dictionary if is_instance_valid(committed) else {}
	_expect(committed_data.get("choice") == "frontline_briefing", "choice serializes canonically")
	_expect(
		bool(record_script.from_dictionary(committed_data).get("ok", false)),
		"committed record round trips"
	)
	var boss_offer := record_script.offered(
		&"prep-boss", Vector2i.ZERO, WorldEncounterType.BOSS, "setup-b"
	) as RefCounted
	_expect(not is_instance_valid(boss_offer), "Boss preparation record rejects")


func _test_transaction(
	setup_script: GDScript,
	record_script: GDScript,
	transaction_script: GDScript
) -> void:
	var units := _make_units()
	var identity := setup_script.capture(
		Vector2i(2, -1), WorldEncounterType.COMBAT, units
	) as RefCounted
	var offered := record_script.offered(
		&"prep-tx",
		Vector2i(2, -1),
		WorldEncounterType.COMBAT,
		String(identity.get("canonical_key"))
	) as RefCounted
	var transaction := transaction_script.begin(offered, identity) as RefCounted
	_expect(is_instance_valid(transaction), "matching offered transaction begins")
	_expect(not bool(transaction.call("cancel")), "required transaction rejects cancellation")
	_expect(
		bool(transaction.call("select_choice", record_script.Choice.FRONTLINE_BRIEFING)),
		"Frontline Briefing selects"
	)
	_expect(bool(transaction.call("select_target", &"enemy_a", units)), "active enemy target selects")
	var result := transaction.call("commit", identity, units) as Dictionary
	_expect(bool(result.get("ok", false)), "matching setup commits")
	var committed := result.get("record") as RefCounted
	_expect(
		is_instance_valid(committed)
			and int(committed.get("choice")) == int(record_script.Choice.FRONTLINE_BRIEFING)
			and committed.get("target_unit_id") == &"enemy_a",
		"commit preserves exact target"
	)
	_expect(
		not bool(transaction.call("commit", identity, units).get("ok", true)),
		"transaction cannot commit twice"
	)
	var stale_units := _make_units()
	var stale_identity := setup_script.capture(
		Vector2i(2, -1), WorldEncounterType.COMBAT, stale_units
	) as RefCounted
	var stale_offer := record_script.offered(
		&"prep-stale",
		Vector2i(2, -1),
		WorldEncounterType.COMBAT,
		String(stale_identity.get("canonical_key"))
	) as RefCounted
	var stale_tx := transaction_script.begin(stale_offer, stale_identity) as RefCounted
	stale_tx.call("select_choice", record_script.Choice.FRONTLINE_BRIEFING)
	stale_tx.call("select_target", &"enemy_a", stale_units)
	stale_units[1].current_hp = 0
	var changed_identity := setup_script.capture(
		Vector2i(2, -1), WorldEncounterType.COMBAT, stale_units
	) as RefCounted
	var stale_result := stale_tx.call("commit", changed_identity, stale_units) as Dictionary
	_expect(not bool(stale_result.get("ok", true)), "stale active state rejects commit")
	_expect(stale_result.get("reason") == &"stale_setup", "stale setup has stable reason")
	var ally_tx := transaction_script.begin(stale_offer, stale_identity) as RefCounted
	ally_tx.call("select_choice", record_script.Choice.FRONTLINE_BRIEFING)
	_expect(not bool(ally_tx.call("select_target", &"player_a", stale_units)), "allied target rejects")
	var plating_tx := transaction_script.begin(stale_offer, stale_identity) as RefCounted
	_expect(
		bool(plating_tx.call("select_choice", record_script.Choice.SPARE_PLATING)),
		"Spare Plating selects without target"
	)


func _make_units() -> Array[BattleUnitState]:
	var player := BattleUnitState.new(
		&"player_a", "Player A", BattleUnitState.Side.PLAYER, 0, 5, 10
	)
	var enemy := BattleUnitState.new(
		&"enemy_a", "Enemy A", BattleUnitState.Side.ENEMY, 1, 4, 10
	)
	return [player, enemy]


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("PASS test_ac6_6_battle_preparation (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
