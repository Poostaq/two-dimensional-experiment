class_name AC82BattleResultRecordTests
extends SceneTree

var _failures: int = 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	if not ResourceLoader.exists("res://Scripts/Battle/battle_result_record.gd"):
		_expect(false, "battle result capture exists")
		quit(1)
		return
	var record_script: Script = load("res://Scripts/Battle/battle_result_record.gd")
	var player: BattleUnitState = BattleUnitState.new(&"hero", "Hero", 0, 0, 10)
	var enemy: BattleUnitState = BattleUnitState.new(&"Enemy", "Enemy", 1, 0, 2)
	var units: Array[BattleUnitState] = [player, enemy]
	var record: RefCounted = record_script.capture("combat", Vector2i(2, 3), units)
	_expect(is_instance_valid(record), "valid setup captured")
	_expect(record.get_receipt().is_empty(), "preterminal receipt empty")
	record.observe_defeat(enemy, 20)
	enemy.current_hp = 0
	record.observe_defeat(enemy, 20)
	enemy.current_hp = 20
	enemy.current_hp = 0
	record.observe_defeat(enemy, 20)
	var receipt: Dictionary = record.freeze(BattleOutcome.Type.VICTORY)
	_expect(receipt["earned_gold"] == 50, "revived repeated defeat counted once")
	_expect(receipt["battle_id"] == "combat:2:3", "coordinate identity")
	_expect(record_script.encounter_id("boss", Vector2i(3, 4)) == "boss", "boss stable identity")
	_expect(record_script.validate_receipt(receipt), "captured receipt valid")
	var decoded: Dictionary = JSON.parse_string(JSON.stringify(receipt))
	_expect(record_script.validate_receipt(decoded), "JSON integral numbers accepted")
	_expect(record_script.canonical_key(decoded) == record_script.canonical_key(receipt), "JSON canonical equality")
	var key: String = record_script.canonical_key(receipt)
	receipt["enemy_ids"].append("mutated")
	_expect(record_script.canonical_key(record.get_receipt()) == key, "getter detached")
	_expect(record.freeze(BattleOutcome.Type.DEFEAT)["outcome"] == "victory", "terminal frozen once")
	var valid: Dictionary = record.get_receipt()
	for bad: Dictionary in [
		{"earned_gold": 51}, {"battle_id": "combat:1:1"}, {"enemy_ids": [" Enemy"]},
		{"defeated_enemy_ids": ["missing"]}, {"enemy_ids": ["Enemy", "Enemy"]},
		{"terminal_player_health": [{"character_id": "hero", "final_hp": 21, "max_hp": 20}]},
		{"outcome": "in_progress"}, {"encounter_coord": [2.5, 3]}, {"unexpected": true}
	]:
		var changed: Dictionary = valid.duplicate(true)
		changed.merge(bad, true)
		_expect(not record_script.validate_receipt(changed), "malformed receipt rejected: " + str(bad))
	var duplicate: BattleUnitState = BattleUnitState.new(&"hero", "Duplicate", 1, 1, 1)
	var invalid_units: Array[BattleUnitState] = [player, duplicate]
	_expect(not is_instance_valid(record_script.capture("combat", Vector2i.ZERO, invalid_units)), "cross-side duplicate rejected")
	var defeat: RefCounted = record_script.capture("combat", Vector2i.ZERO, units)
	_expect(defeat.freeze(BattleOutcome.Type.DEFEAT)["earned_gold"] == 0, "defeat earns zero")
	await _test_arena()
	if _failures == 0:
		print("PASS test_ac8_2_battle_result_record")
	quit(0 if _failures == 0 else 1)

func _test_arena() -> void:
	var scene: PackedScene = load("res://Scenes/battle_arena.tscn")
	var arena: Control = scene.instantiate()
	root.add_child(arena)
	await process_frame
	_expect(arena.has_method("get_terminal_result"), "arena terminal result API exists")
	if not arena.has_method("get_terminal_result"):
		arena.queue_free()
		await process_frame
		return
	arena.configure(Vector2i(4, 2), "combat")
	arena.configure_production_settlement(true)
	var player: BattleUnitState = BattleUnitState.new(&"hero", "Hero", 0, 0, 10, 20, [], 20)
	var enemy: BattleUnitState = BattleUnitState.new(&"enemy", "Enemy", 1, 0, 2, 5)
	var units: Array[BattleUnitState] = [player, enemy]
	arena.configure_units(units)
	_expect(arena.get_terminal_result().is_empty(), "arena preterminal receipt empty")
	arena.preview_default_attack(player.unit_id, enemy.unit_id)
	_expect(arena.get_terminal_result().is_empty(), "preview produces no receipt")
	_expect(arena.confirm_default_attack(player.unit_id, enemy.unit_id, arena.get_battle_revision()), "real attack commits")
	var result: Dictionary = arena.get_terminal_result()
	_expect(result.get("earned_gold", -1) == 50, "committed attack captures defeat")
	_expect(not arena.get_node("%RewardOverlay").visible, "production rewards await commit")
	arena.set_settlement_committed()
	_expect(arena.get_node("%RewardOverlay").visible, "committed settlement unlocks rewards")
	player.current_hp = 20
	enemy.current_hp = 5
	arena.configure_units(units)
	_expect(arena.get_terminal_result().is_empty(), "new setup clears terminal receipt")
	arena.remove_battle_unit(enemy.unit_id)
	arena._complete_battle(BattleOutcome.Type.VICTORY)
	_expect(arena.get_terminal_result().get("earned_gold", -1) == 0, "living removal earns no gold")
	player.current_hp = 20
	player.power = 1
	enemy.current_hp = 2
	arena.configure_units(units)
	var source_script: Script = load("res://Scripts/Battle/battle_keyword_source.gd")
	enemy.apply_bleed(source_script.create(player.unit_id, &"bleed_test", 20), 1)
	_expect(arena.confirm_default_attack(player.unit_id, enemy.unit_id, arena.get_battle_revision()), "bleed action commits")
	_expect(arena.get_terminal_result().get("earned_gold", -1) == 50, "bleed defeat earns gold")
	var signaled: Array[Dictionary] = []
	arena.battle_completed.connect(func(_outcome: int) -> void: signaled.append(arena.get_terminal_result()))
	player.current_hp = 20
	player.power = 20
	enemy.current_hp = 5
	arena.configure_units(units)
	arena.confirm_default_attack(player.unit_id, enemy.unit_id, arena.get_battle_revision())
	_expect(signaled.size() == 1 and signaled[0].get("earned_gold", -1) == 50, "receipt frozen before completion signal")
	var exits: Array[bool] = []
	arena.exit_requested.connect(func() -> void: exits.append(true))
	arena._emit_exit_requested()
	_expect(exits.is_empty(), "pending settlement blocks exit")
	arena.set_settlement_committed()
	arena._emit_exit_requested()
	_expect(exits.size() == 1, "committed settlement permits exit")
	player.current_hp = 20
	enemy.current_hp = 5
	enemy.unit_id = player.unit_id
	arena.configure_units(units)
	_expect(arena.is_battle_input_locked(), "invalid production setup blocks combat")
	arena.perform_debug_damage()
	_expect(enemy.current_hp == 5 and player.current_hp == 20, "invalid setup cannot damage")
	arena.configure_production_settlement(false)
	_expect(not arena.is_battle_input_locked(), "standalone setup behavior preserved")
	arena.queue_free()
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
