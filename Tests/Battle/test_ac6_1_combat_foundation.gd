class_name Ac6_1CombatFoundationTests
extends SceneTree

const EXPECTED_TEST_COUNT: int = 40

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_fresh_battle_stats()
	_test_physical_damage_formula()
	_test_formation_contract()
	await _test_default_attack_transaction()
	await _test_formation_move_transactions()
	if _assertions != EXPECTED_TEST_COUNT:
		_failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
	if _failures.is_empty():
		print("AC6.1 combat foundation: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_fresh_battle_stats() -> void:
	var skills: Array[CharacterSkill] = []
	var character := RunCharacter.new(&"goblin", "Goblin", 9, 20, skills, 7, 2)
	var starters: Array[RunCharacter] = [character]
	var roster := RunRoster.new(starters)
	var first: BattleUnitState = roster.create_battle_units()[0]
	_expect(first.power == 7 and first.defense == 2, "base combat stats copy into battle")
	first.power = 1
	first.defense = 0
	var second: BattleUnitState = roster.create_battle_units()[0]
	_expect(second.power == 7 and second.defense == 2, "battle stat mutation does not leak")
	_expect(character.power == 7 and character.defense == 2, "run definition stays immutable")


func _test_physical_damage_formula() -> void:
	_expect(BattleDamageRules.physical_damage(4, 0.85, 2) == 2, "85% rounds before Defense")
	_expect(BattleDamageRules.physical_damage(6, 1.20, 2) == 6, "ordinary damage uses ceil")
	_expect(BattleDamageRules.physical_damage(1, 0.60, 99) == 1, "direct damage minimum is one")
	_expect(BattleDamageRules.physical_damage(0, 1.0, 0) == -1, "invalid Power is rejected")
	var attacker := BattleUnitState.new(&"attacker", "Attacker", BattleUnitState.Side.PLAYER, 0, 8, 20, [], 6, 0)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	var damage_result := BattleDamageResolver.apply_damage(attacker, target, 4)
	_expect(damage_result.applied_damage == 4 and damage_result.armor_prevented == 0 and damage_result.was_direct_hit and not damage_result.is_status_damage, "legacy apply_damage remains direct damage")


func _test_formation_contract() -> void:
	_expect(BattleFormationRules.is_front_slot(0), "slot 0 is front")
	_expect(BattleFormationRules.is_front_slot(2), "slot 2 is front")
	_expect(not BattleFormationRules.is_front_slot(3), "slot 3 is back")
	_expect(BattleFormationRules.is_back_slot(5), "slot 5 is back")
	_expect(BattleFormationRules.lane_of(4) == 1, "slot 4 is lane 1")
	_expect(BattleFormationRules.lane_distance(0, 5) == 2, "distance compares lanes")
	_expect(BattleFormationRules.lane_of(-1) == -1, "invalid slots are rejected")
	_expect(BattleFormationRules.is_move_one(0, 1), "adjacent front lane is Move 1")
	_expect(BattleFormationRules.is_move_one(0, 3), "same-lane row change is Move 1")
	_expect(not BattleFormationRules.is_move_one(0, 2), "two lanes is not Move 1")
	_expect(not BattleFormationRules.is_move_one(0, 4), "diagonal row-and-lane change is not Move 1")


func _test_default_attack_transaction() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var actor := BattleUnitState.new(&"actor", "Actor", BattleUnitState.Side.PLAYER, 0, 10, 20, [], 6, 0)
	var ally := BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 1, 8)
	var target := BattleUnitState.new(&"target", "Target", BattleUnitState.Side.ENEMY, 0, 5, 20, [], 1, 2)
	arena.configure_units(_typed_units([actor, ally, target]))
	var preview: Dictionary = arena.preview_default_attack(actor.unit_id, target.unit_id)
	_expect(preview.get("actor_id", &"") == actor.unit_id, "default attack preview locks actor")
	_expect(preview.get("target_id", &"") == target.unit_id, "default attack preview locks target")
	var before_revision: int = arena.get_battle_revision()
	_expect(arena.confirm_default_attack(actor.unit_id, target.unit_id, int(preview.get("revision", -1))), "default attack confirms")
	_expect(target.current_hp == target.max_hp - 4, "default attack deals 100% Power through Defense")
	_expect(arena.get_battle_revision() == before_revision + 1, "default attack commits one revision")
	var records: Array[BattleActionRecord] = arena.get_action_records()
	var record: BattleActionRecord = records.back()
	_expect(record.kind == BattleActionRecord.Kind.DEFAULT_ATTACK, "history types default attack")
	_expect(record.actor_id == actor.unit_id and record.target_ids == [target.unit_id], "history locks identities")
	_expect(record.damage_by_target[target.unit_id] == 4, "history records applied damage")
	var committed_history: Array[BattleActionLogEntry] = arena.get_committed_action_history_snapshot()
	_expect(
		committed_history.size() == 1
		and committed_history[0].skill_id == &"default_attack",
		"default attack joins authoritative committed-action history"
	)

	arena.configure_units(_typed_units([actor, ally, target]))
	var stale_preview: Dictionary = arena.preview_default_attack(actor.unit_id, target.unit_id)
	var stale_hp: int = target.current_hp
	arena.notify_authoritative_battle_change()
	_expect(
		not arena.confirm_default_attack(actor.unit_id, target.unit_id, int(stale_preview.get("revision", -1)))
		and target.current_hp == stale_hp
		and arena.get_action_records().is_empty(),
		"stale default attack rejects without mutation"
	)
	arena.queue_free()
	await process_frame


func _test_formation_move_transactions() -> void:
	var packed := load("res://Scenes/battle_arena.tscn") as PackedScene
	var arena := packed.instantiate() as BattleArena
	root.add_child(arena)
	await process_frame
	var actor := BattleUnitState.new(&"mover", "Mover", BattleUnitState.Side.PLAYER, 0, 10)
	var ally := BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 3, 8)
	var enemy := BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5)
	arena.configure_units(_typed_units([actor, ally, enemy]))
	var move_preview: Dictionary = arena.preview_formation_move(actor.unit_id, 1, false)
	_expect(move_preview.get("destination_slot", -1) == 1, "empty Move 1 previews destination")
	_expect(
		arena.confirm_formation_move(
			actor.unit_id,
			int(move_preview.get("source_slot", -1)),
			1,
			move_preview.get("occupant_id", &""),
			int(move_preview.get("revision", -1)),
			false
		),
		"empty Move 1 confirms"
	)
	_expect(actor.slot_index == 1 and ally.slot_index == 3, "empty Move 1 changes only actor slot")
	var move_record: BattleActionRecord = arena.get_action_records().back()
	_expect(
		move_record.kind == BattleActionRecord.Kind.FORMATION_MOVE
		and move_record.slot_before_by_unit[actor.unit_id] == 0
		and move_record.slot_after_by_unit[actor.unit_id] == 1,
		"movement history records before and after slots"
	)
	_expect(
		arena.get_committed_action_history_snapshot().size() == 1
		and arena.get_committed_action_history_snapshot()[0].skill_id == &"formation_move",
		"formation move joins authoritative committed-action history"
	)

	actor = BattleUnitState.new(&"mover", "Mover", BattleUnitState.Side.PLAYER, 0, 10)
	ally = BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 3, 8)
	enemy = BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5)
	arena.configure_units(_typed_units([actor, ally, enemy]))
	var swap_preview: Dictionary = arena.preview_formation_move(actor.unit_id, 3, true)
	_expect(
		arena.confirm_formation_move(
			actor.unit_id,
			int(swap_preview.get("source_slot", -1)),
			3,
			swap_preview.get("occupant_id", &""),
			int(swap_preview.get("revision", -1)),
			true
		),
		"Default Swap confirms with occupied ally"
	)
	_expect(actor.slot_index == 3 and ally.slot_index == 0, "Default Swap exchanges allied slots")
	_expect(arena.get_action_records().back().kind == BattleActionRecord.Kind.DEFAULT_SWAP, "history types Default Swap")
	_expect(
		arena.get_committed_action_history_snapshot().size() == 1
		and arena.get_committed_action_history_snapshot()[0].skill_id == &"default_swap",
		"Default Swap joins authoritative committed-action history"
	)

	actor = BattleUnitState.new(&"mover", "Mover", BattleUnitState.Side.PLAYER, 0, 10)
	ally = BattleUnitState.new(&"ally", "Ally", BattleUnitState.Side.PLAYER, 3, 8)
	enemy = BattleUnitState.new(&"enemy", "Enemy", BattleUnitState.Side.ENEMY, 0, 5)
	arena.configure_units(_typed_units([actor, ally, enemy]))
	var stale_preview: Dictionary = arena.preview_formation_move(actor.unit_id, 1, false)
	ally.slot_index = 1
	_expect(
		not arena.confirm_formation_move(
			actor.unit_id,
			int(stale_preview.get("source_slot", -1)),
			1,
			stale_preview.get("occupant_id", &""),
			int(stale_preview.get("revision", -1)),
			false
		)
		and actor.slot_index == 0
		and ally.slot_index == 1
		and arena.get_action_records().is_empty(),
		"stale occupancy rejects without partial movement"
	)
	_expect(arena.preview_formation_move(actor.unit_id, 2, false).is_empty(), "non-neighbor Move 1 is rejected")
	arena.queue_free()
	await process_frame


func _typed_units(values: Array) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for value: Variant in values:
		result.append(value as BattleUnitState)
	return result


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
