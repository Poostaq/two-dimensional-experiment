class_name WorldRuntimeMigratedFlowContractTests
extends SceneTree

const EXPECTED_TEST_COUNT := 29
const SCENE_PATH := "res://Scenes/world_map_runtime_preview.tscn"

var _failures: Array[String] = []
var _assertions: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _expect(
        ProjectSettings.get_setting("application/run/main_scene") == "res://Scenes/world_run_start.tscn",
        "migrated flows retain the Stage 5 production launcher"
    )
    _expect(ResourceLoader.exists(SCENE_PATH), "migrated flows have an explicit Stage 4 entry")
    if not ResourceLoader.exists(SCENE_PATH):
        _finish()
        return
    var packed := load(SCENE_PATH) as PackedScene
    var runtime := packed.instantiate()
    _expect(runtime.has_method("request_move"), "migrated movement has one request boundary")
    _expect(runtime.has_method("has_active_encounter"), "migrated encounter state is inspectable")
    _expect(runtime.has_method("close_active_encounter"), "migrated encounter close is explicit")
    _expect(runtime.has_method("has_active_battle"), "migrated battle state is inspectable")
    _expect(runtime.has_method("open_party_management"), "migrated Party flow is explicit")
    _expect(runtime.has_method("has_active_party_management"), "migrated Party state is inspectable")
    get_root().add_child(runtime)
    await process_frame
    await process_frame
    var initial_moves := (runtime.call("get_runtime_snapshot") as WorldRuntimeSnapshot).move_count
    var destination := (runtime.call("get_valid_destinations") as Array[Vector2i])[0]
    var accepted := runtime.call("request_move", destination) as WorldMoveResult
    _expect(accepted.is_accepted(), "accepted world move enters the migrated flow")
    _expect(bool(runtime.call("has_active_encounter")), "accepted move opens one encounter overlay")
    _expect(runtime.get_node("EncounterHost").get_child_count() == 1, "encounter host owns exactly one overlay")
    var blocked_result := runtime.call("request_move", accepted.previous_player_coord) as WorldMoveResult
    _expect(not blocked_result.is_accepted(), "encounter overlay blocks repeated world input")
    var overlay := runtime.get_node("EncounterHost").get_child(0) as EncounterOverlay
    _expect(overlay.encounter_coordinate == destination, "encounter overlay receives accepted coordinate")
    overlay.battle_requested.emit(destination, "combat")
    await process_frame
    _expect(not bool(runtime.call("has_active_encounter")) and bool(runtime.call("has_active_battle")), "battle request replaces the encounter with one battle")
    _expect(runtime.get_node("BattleHost").get_child_count() == 1, "battle host owns exactly one arena")
    var battle := runtime.get_node("BattleHost").get_child(0) as BattleArena
    battle.call("_complete_battle", BattleOutcome.Type.VICTORY)
    await process_frame
    _expect(bool(runtime.call("has_active_battle")), "victory keeps battle alive for reward selection")
    var reward_options := battle.get_reward_options()
    _expect(not reward_options.is_empty(), "combat battle exposes configured reward options")
    var recruitment_option := reward_options[0] as BattleRewardOption
    battle.select_reward(recruitment_option.reward_id)
    battle.confirm_reward_selection()
    await process_frame
    _expect(bool(runtime.call("has_active_party_management")), "recruitment reward opens Party placement")
    var recruitment_party := runtime.get_node("PartyHost").get_child(0) as PartyManagement
    recruitment_party.placement_cancelled.emit()
    await process_frame
    _expect(not bool(runtime.call("has_active_party_management")), "cancelled recruitment closes only Party placement")
    _expect(bool(runtime.call("has_active_battle")), "cancelled recruitment restores the pending battle reward")
    battle.exit_requested.emit()
    await process_frame
    _expect(not bool(runtime.call("has_active_battle")), "battle exit restores the world surface")
    _expect((runtime.call("get_runtime_snapshot") as WorldRuntimeSnapshot).move_count == initial_moves + 1, "battle flow consumes no additional world moves")
    runtime.call("open_party_management")
    _expect(bool(runtime.call("has_active_party_management")), "Party opens one normal management surface")
    _expect(runtime.get_node("PartyHost").get_child_count() == 1, "Party host owns exactly one management instance")
    var party := runtime.get_node("PartyHost").get_child(0) as PartyManagement
    var source_character := (party.get("_slots") as Array)[0] as RunCharacter
    party.move_requested.emit(0, 3, source_character.character_id)
    party.close_requested.emit()
    await process_frame
    _expect(not bool(runtime.call("has_active_party_management")), "Party close restores world input")
    var hud := runtime.get_node("%WorldMapHud") as WorldMapHud
    _expect((hud.get_node("%FrontSlot0") as Label).text == "Empty", "Party move persists the emptied source slot in HUD")
    _expect((hud.get_node("%BackSlot0") as Label).text == source_character.display_name, "Party move persists destination formation in HUD after close")
    _expect((runtime.call("get_runtime_snapshot") as WorldRuntimeSnapshot).move_count == initial_moves + 1, "Party open and close consume zero world moves")
    _expect(not (runtime.call("get_runtime_snapshot") as WorldRuntimeSnapshot).input_blocked, "ordinary migrated flows clear only their owned blocker")
    runtime.free()
    _finish()


func _expect(condition: bool, message: String) -> void:
    _assertions += 1
    if not condition:
        _failures.append(message)


func _finish() -> void:
    if _assertions != EXPECTED_TEST_COUNT:
        _failures.append("expected %d assertions, ran %d" % [EXPECTED_TEST_COUNT, _assertions])
    if _failures.is_empty():
        print("World runtime migrated flow contract tests: PASS (%d/%d)" % [_assertions, EXPECTED_TEST_COUNT])
        quit(0)
        return
    for failure: String in _failures:
        push_error(failure)
    quit(1)
