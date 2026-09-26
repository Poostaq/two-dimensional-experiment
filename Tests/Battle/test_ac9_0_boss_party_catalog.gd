class_name Ac9_0BossPartyCatalogTests
extends SceneTree

var _assertions: int = 0
var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var catalog_script := load("res://Scripts/Battle/boss_party_catalog.gd") as Script
	_expect(is_instance_valid(catalog_script), "Boss party catalog script exists")
	if is_instance_valid(catalog_script):
		_expect(catalog_script.has_method("create_by_enemy_clan_id"), "Boss party catalog creates by enemy clan ID")
		var expected_commanders: Dictionary[StringName, StringName] = {&"human": &"marshal_elian_voss", &"elf": &"lady_saelith_moonfall", &"dwarf": &"thane_brokk_stonevein"}
		for clan_id: StringName in expected_commanders:
			var party: Array[RunCharacter] = catalog_script.create_by_enemy_clan_id(clan_id)
			_expect(party.size() == 4, "%s boss party has four authored members" % clan_id)
			var commander_count: int = 0
			for member: RunCharacter in party:
				commander_count += int(member.class_id == expected_commanders[clan_id])
			_expect(commander_count == 1, "%s boss party contains its commander exactly once" % clan_id)
		_expect((catalog_script.create_by_enemy_clan_id(&"unknown") as Array).is_empty(), "Boss party catalog rejects unknown clans")
	_test_battle_fixture_conversion()
	_finish()


func _test_battle_fixture_conversion() -> void:
	var debug_catalog := load("res://Scripts/Battle/debug_encounter_catalog.gd") as Script
	_expect(debug_catalog.has_method("create_boss_enemies"), "Debug encounter seam delegates authored boss parties")
	if not debug_catalog.has_method("create_boss_enemies"):
		return
	var expected_commanders: Array[StringName] = [
		&"marshal_elian_voss",
		&"thane_brokk_stonevein",
		&"lady_saelith_moonfall",
	]
	for encounter_index: int in expected_commanders.size():
		var units: Array[BattleUnitState] = debug_catalog.call("create_boss_enemies", encounter_index)
		_expect(units.size() == 4, "Boss battle fixture %d has four units" % encounter_index)
		var commander_count: int = 0
		for unit: BattleUnitState in units:
			commander_count += int(unit.unit_id == expected_commanders[encounter_index])
			_expect(unit.side == BattleUnitState.Side.ENEMY, "Boss fixture members are enemies")
		_expect(commander_count == 1, "Boss battle fixture contains its commander exactly once")
	var arena: BattleArena = load("res://Scenes/battle_arena.tscn").instantiate()
	root.add_child(arena)
	arena.configure(Vector2i.ZERO, WorldEncounterType.BOSS)
	var player := BattleUnitState.new(&"boss_route_player", "Boss Route Player", BattleUnitState.Side.PLAYER, 0, 1, 20)
	var players: Array[BattleUnitState] = [player]
	arena.configure_party_units(players)
	_expect(is_instance_valid(arena.get_unit_by_id(&"marshal_elian_voss")), "Boss encounters route through the Human authored party at index zero")
	_expect(arena.get_unit_by_id(&"enemy_0") == null, "Boss routing does not use the generic debug pair")
	arena.free()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("AC9.0 boss party catalog: %d/%d assertions passed." % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
