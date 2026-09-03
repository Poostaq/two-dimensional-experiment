class_name AC67GoblinIntegrationTests
extends SceneTree

const WORLD_SCENE := "res://Scenes/world_map_runtime.tscn"
const RUN_STATE_SCRIPT: GDScript = preload("res://Scripts/Run/world_run_state.gd")
const BRAKKA_ID := &"brakka_rustbanner"
const CLASS_IDS: Array[StringName] = [
	&"scrapshield_bruiser",
	&"wirefang_skirmisher",
	&"snarewright",
	&"scrapbroker",
	&"shivrunner",
	&"mobcaller",
]
const BATTLE_FORMATION: Array[StringName] = [
	&"scrapshield_bruiser",
	BRAKKA_ID,
	&"snarewright",
	&"scrapbroker",
	&"shivrunner",
	&"mobcaller",
]

var _failures: Array[String] = []
var _assertions: int = 0


class FakeRepository:
	extends RefCounted

	var writes: Array[PackedByteArray] = []

	func replace_atomic(bytes: PackedByteArray) -> Dictionary:
		writes.append(bytes.duplicate())
		return {"ok": true, "value": null, "error": null}


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_catalog_contract()
	var generated: Dictionary = HexWorldGeneratorV1.new().generate("ac6-7-integration")
	_expect(bool(generated.get("ok", false)), "deterministic production world generates")
	if not bool(generated.get("ok", false)):
		_finish()
		return
	var plan := generated.get("plan") as WorldPlan
	var repository := FakeRepository.new()
	var world := await _create_world(plan, repository, false)
	_expect(is_instance_valid(world), "production world accepts Goblin session")
	if not is_instance_valid(world):
		_finish()
		return
	var first_formation: Array[StringName] = (
		world.get_durable_run_state().get("formation") as Array[StringName]
	)
	await _verify_first_battle(world, plan.get_start_coord())
	var first_move_count: int = world.get_runtime_snapshot().move_count
	await _verify_reward_and_formation(world)
	var rearranged: Array[StringName] = (
		world.get_durable_run_state().get("formation") as Array[StringName]
	)
	_expect(rearranged != first_formation, "reward and party flow change persistent formation")
	_expect(
		world.get_runtime_snapshot().move_count == first_move_count,
		"reward and party management consume no world moves"
	)
	var reload_state := _state_with_ready_cache(world.get_durable_run_state(), plan)
	_expect(is_instance_valid(reload_state), "ready Cache state rebuilds for reload")
	world.free()
	await process_frame
	if not is_instance_valid(reload_state):
		_finish()
		return
	var restored_repository := FakeRepository.new()
	var restored := await _create_world_from_state(plan, restored_repository, reload_state)
	_expect(is_instance_valid(restored), "save/reload restores rearranged Goblin run")
	if is_instance_valid(restored):
		await _verify_second_battle(restored, plan.get_start_coord(), rearranged)
		restored.free()
		await process_frame
	_finish()


func _verify_catalog_contract() -> void:
	_expect(
		RunCharacterCatalog.get_goblin_class_ids() == CLASS_IDS,
		"root catalog exposes all six regular Goblin IDs in canonical order"
	)
	for class_id: StringName in CLASS_IDS:
		var character := RunCharacterCatalog.create_by_class_id(class_id)
		_expect(is_instance_valid(character), "%s resolves" % class_id)
		if not is_instance_valid(character):
			continue
		_expect(character.race_id == &"goblin", "%s retains Goblin identity" % class_id)
		_expect(character.get_skills().size() == 3, "%s has exactly three skills" % class_id)
	var brakka := RunCharacterCatalog.create_by_class_id(BRAKKA_ID)
	_expect(is_instance_valid(brakka), "Brakka resolves through root catalog")
	if is_instance_valid(brakka):
		var skills: Array[CharacterSkill] = brakka.get_skills()
		_expect(skills.size() == 4, "Brakka has the three-plus-one commander loadout")
		_expect(skills[3].skill_id == &"banner_holder", "Banner Holder is Brakka's fourth skill")


func _verify_first_battle(world: WorldRuntimeController, coordinate: Vector2i) -> void:
	world.call("_on_battle_requested", coordinate, WorldEncounterType.COMBAT)
	await process_frame
	var arena: BattleArena = _get_arena(world)
	_expect(is_instance_valid(arena), "production controller opens first Combat")
	if not is_instance_valid(arena):
		return
	_expect(not arena.is_preparation_required(), "first battle starts without unearned preparation")
	var players := _player_units(arena)
	_expect(players.size() == 6, "first battle contains the full six-unit roster")
	var brakka := arena.get_unit_by_id(BRAKKA_ID)
	_expect(is_instance_valid(brakka) and brakka.slot_index == 1, "Brakka starts in middle frontline slot 1")
	_expect(is_instance_valid(brakka) and brakka.skills.size() == 4, "production Brakka retains four skills")
	_advance_until_current(arena, BRAKKA_ID)
	var banner_log_found := false
	for entry: BattleLogEntry in arena.get_battle_log_entries():
		banner_log_found = banner_log_found or "Banner Holder applied Advantage" in entry.message_text
	_expect(banner_log_found, "Banner Holder resolves through the production arena log")
	var actor := arena.get_current_unit()
	var enemy := _first_active_enemy(arena)
	_expect(is_instance_valid(actor) and actor.side == BattleUnitState.Side.PLAYER, "production turn selects a player actor")
	_expect(is_instance_valid(enemy), "production battle exposes a real enemy target")
	if is_instance_valid(actor) and is_instance_valid(enemy):
		var preview: Dictionary = arena.preview_default_attack(actor.unit_id, enemy.unit_id)
		_expect(not preview.is_empty(), "real enemy target produces an attack preview")
		_expect(
			arena.confirm_default_attack(
				actor.unit_id,
				enemy.unit_id,
				int(preview.get("revision", -1))
			),
			"real selected target commits through the production action path"
		)
	_expect(not arena.get_action_records().is_empty(), "committed action enters battle history")
	_expect(not arena.get_committed_action_history_snapshot().is_empty(), "committed action enters authored-history queries")
	var mover := arena.get_current_unit()
	var moved := false
	if is_instance_valid(mover) and mover.side == BattleUnitState.Side.PLAYER:
		for destination: int in 6:
			var move_preview: Dictionary = arena.preview_formation_move(mover.unit_id, destination, false)
			if move_preview.is_empty():
				continue
			moved = arena.confirm_formation_move(
				mover.unit_id,
				int(move_preview.get("source_slot", -1)),
				destination,
				move_preview.get("occupant_id", &"") as StringName,
				int(move_preview.get("revision", -1)),
				false
			)
			if moved:
				break
	_expect(moved, "real formation path commits in the first battle")
	_dirty_battle_state(arena)
	arena.call("_complete_battle", BattleOutcome.Type.VICTORY)
	await process_frame
	_expect(arena.get_battle_outcome() == BattleOutcome.Type.VICTORY, "first battle reaches victory")
	_expect(arena.get_reward_options().size() == 3, "victory exposes production Combat rewards")


func _verify_reward_and_formation(world: WorldRuntimeController) -> void:
	var arena: BattleArena = _get_arena(world)
	if not is_instance_valid(arena):
		_expect(false, "reward flow retains active battle")
		return
	arena.select_reward(&"combat_recruit_scout")
	arena.confirm_reward_selection()
	await process_frame
	_expect(world.has_active_party_management(), "Scout reward opens production replacement UI")
	if not world.has_active_party_management():
		return
	var party := world.get_node("PartyHost").get_child(0) as PartyManagement
	var slots := party.get("_slots") as Array[RunCharacter]
	var replaced := slots[5]
	party.request_replacement(5, replaced.character_id, &"scout")
	await process_frame
	_expect(not world.has_active_party_management(), "confirmed replacement closes placement UI")
	_expect(world.get_durable_run_state().get("formation")[5] == &"scout", "Scout persists in replaced slot")
	await process_frame
	_expect(not world.has_active_battle(), "completed reward returns to world")
	world.open_party_management()
	_expect(world.has_active_party_management(), "ordinary party management opens after reward")
	if not world.has_active_party_management():
		return
	var normal_party := world.get_node("PartyHost").get_child(0) as PartyManagement
	var normal_slots := normal_party.get("_slots") as Array[RunCharacter]
	var source := normal_slots[0]
	normal_party.move_requested.emit(0, 3, source.character_id)
	normal_party.close_requested.emit()
	await process_frame
	_expect(not world.has_active_party_management(), "party rearrangement returns to world")
	_expect(world.get_durable_run_state().get("formation")[3] == source.character_id, "rearranged slot persists authoritatively")


func _verify_second_battle(
	world: WorldRuntimeController,
	coordinate: Vector2i,
	expected_formation: Array[StringName]
) -> void:
	var state: RefCounted = world.get_durable_run_state()
	_expect(bool(state.get("cache_ready")), "Cache readiness survives save/reload")
	_expect(state.get("formation") == expected_formation, "formation survives save/reload exactly")
	world.call("_on_battle_requested", coordinate, WorldEncounterType.COMBAT)
	await process_frame
	var arena: BattleArena = _get_arena(world)
	_expect(is_instance_valid(arena) and arena.is_preparation_required(), "second Combat restores the preparation gate")
	if not is_instance_valid(arena):
		return
	var identity: RefCounted = arena.get_setup_identity() as RefCounted
	world.call(
		"_on_preparation_commit_requested",
		BattlePreparationRecord.Choice.SPARE_PLATING,
		&"",
		identity.canonical_key
	)
	await process_frame
	state = world.get_durable_run_state()
	_expect(not bool(state.get("cache_ready")), "one committed preparation consumes Cache once")
	_expect(not arena.is_preparation_required(), "durable preparation commit unlocks battle")
	_expect(arena.round_number == 1, "new battle starts at round one")
	_expect(arena.get_action_records().is_empty(), "new battle has no action records")
	_expect(arena.get_committed_action_history_snapshot().is_empty(), "new battle has no committed-action history")
	for unit: BattleUnitState in arena.get_turn_queue():
		if unit.side != BattleUnitState.Side.PLAYER:
			_expect(unit.get_armor() == 0, "%s enemy receives no preparation Armor" % unit.unit_id)
			continue
		var definition: RunCharacter = RunCharacterCatalog.create_by_class_id(unit.unit_id)
		if not is_instance_valid(definition):
			definition = RunCharacterCatalog.create_for_reward(&"combat_recruit_scout")
		_expect(is_instance_valid(definition), "%s has a persistent run definition" % unit.unit_id)
		if not is_instance_valid(definition):
			continue
		_expect(unit.current_hp == definition.max_hp, "%s starts second battle at full HP" % unit.unit_id)
		_expect(unit.get_effective_speed() == definition.base_speed, "%s has no leaked Speed modifier" % unit.unit_id)
		_expect(unit.get_skill_cooldown_snapshot().is_empty(), "%s has no leaked cooldown" % unit.unit_id)
		_expect(unit.get_bleed_snapshot().is_empty(), "%s has no leaked Bleed" % unit.unit_id)
		_expect(not unit.is_snared(1), "%s has no leaked Snared" % unit.unit_id)
		var expected_armor: int = 2 if unit.slot_index < 3 else 0
		_expect(unit.get_armor() == expected_armor, "%s receives only slot-eligible preparation Armor" % unit.unit_id)
	var second_brakka: BattleUnitState = arena.get_unit_by_id(BRAKKA_ID)
	_expect(is_instance_valid(second_brakka), "Brakka persists into the next battle")
	_advance_until_current(arena, BRAKKA_ID)
	var second_banner_log: bool = false
	for entry: BattleLogEntry in arena.get_battle_log_entries():
		second_banner_log = second_banner_log or "Banner Holder applied Advantage" in entry.message_text
	_expect(second_banner_log, "Brakka's round-one Passive guard is fresh in the next battle")


func _dirty_battle_state(arena: BattleArena) -> void:
	var player := _player_units(arena)[0]
	var enemy := _first_active_enemy(arena)
	var source := BattleKeywordSource.create(player.unit_id, &"ac6_7_dirty", player.power)
	player.current_hp = max(1, player.current_hp - 3)
	player.add_armor(5)
	player.add_speed_modifier(&"ac6_7_dirty", 2, BattleUnitState.ModifierExpiry.CURRENT_ROUND, 1, 1)
	if not player.skills.is_empty():
		player.set_skill_cooldown(player.skills[0].skill_id, 2)
	if is_instance_valid(enemy):
		enemy.apply_advantage(source, 1)
		enemy.apply_snared(source, 1, true)
		enemy.apply_bleed(source, 2)
	var brakka := arena.get_unit_by_id(BRAKKA_ID)
	if is_instance_valid(brakka):
		brakka.mark_passive_reaction_guard(&"banner_holder", 1, 1, 1)


func _state_with_ready_cache(state: RefCounted, plan: WorldPlan) -> RefCounted:
	var data := state.call("to_dictionary") as Dictionary
	data["cache_move_progress"] = 0
	data["cache_ready"] = true
	data["battle_preparation"] = BattlePreparationRecord.none().to_dictionary()
	var decoded: Dictionary = RUN_STATE_SCRIPT.from_dictionary(data, plan)
	return decoded.get("value") as RefCounted if bool(decoded.get("ok", false)) else null


func _create_world(
	plan: WorldPlan,
	repository: FakeRepository,
	cache_ready: bool
) -> WorldRuntimeController:
	var consumed: Array[Vector2i] = []
	var state: RefCounted = RUN_STATE_SCRIPT.create(
		plan.get_start_coord(),
		plan.get_boss_coord(),
		0,
		false,
		false,
		consumed,
		BATTLE_FORMATION,
		0,
		cache_ready
	)
	return await _create_world_from_state(plan, repository, state)


func _create_world_from_state(
	plan: WorldPlan,
	repository: FakeRepository,
	state: RefCounted
) -> WorldRuntimeController:
	var packed: PackedScene = load(WORLD_SCENE) as PackedScene
	var world: WorldRuntimeController = packed.instantiate() as WorldRuntimeController if is_instance_valid(packed) else null
	if not is_instance_valid(world):
		return null
	root.add_child(world)
	await process_frame
	var session: Dictionary = {
		"plan": plan,
		"resolved_seed": "ac6-7-integration",
		"run_state": state,
	}
	if not world.apply_session(session, repository):
		world.free()
		return null
	return world


func _get_arena(world: WorldRuntimeController) -> BattleArena:
	var host := world.get_node("BattleHost")
	return host.get_child(0) as BattleArena if host.get_child_count() > 0 else null


func _player_units(arena: BattleArena) -> Array[BattleUnitState]:
	var result: Array[BattleUnitState] = []
	for unit: BattleUnitState in arena.get_turn_queue():
		if unit.side == BattleUnitState.Side.PLAYER:
			result.append(unit)
	return result


func _first_active_enemy(arena: BattleArena) -> BattleUnitState:
	for unit: BattleUnitState in arena.get_turn_queue():
		if unit.side == BattleUnitState.Side.ENEMY and unit.is_active():
			return unit
	return null


func _advance_until_current(arena: BattleArena, unit_id: StringName) -> void:
	for _step: int in arena.get_turn_queue().size():
		var current := arena.get_current_unit()
		if is_instance_valid(current) and current.unit_id == unit_id:
			return
		arena.advance_turn()


func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("PASS test_ac6_7_goblin_integration (%d/%d)" % [_assertions, _assertions])
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
