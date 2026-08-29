class_name Ac6_1CombatFoundationTests
extends SceneTree

const EXPECTED_TEST_COUNT: int = 23

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_fresh_battle_stats()
	_test_physical_damage_formula()
	_test_formation_contract()
	await _test_default_attack_transaction()
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


func _test_formation_contract() -> void:
	_expect(BattleFormationRules.is_front_slot(0), "slot 0 is front")
	_expect(BattleFormationRules.is_front_slot(2), "slot 2 is front")
	_expect(not BattleFormationRules.is_front_slot(3), "slot 3 is back")
	_expect(BattleFormationRules.is_back_slot(5), "slot 5 is back")
	_expect(BattleFormationRules.lane_of(4) == 1, "slot 4 is lane 1")
	_expect(BattleFormationRules.lane_distance(0, 5) == 2, "distance compares lanes")
	_expect(BattleFormationRules.lane_of(-1) == -1, "invalid slots are rejected")


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


func _typed_units(values: Array) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for value: Variant in values:
		result.append(value as BattleUnitState)
	return result


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)
