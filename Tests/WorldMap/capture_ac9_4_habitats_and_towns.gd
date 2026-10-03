class_name AC94HabitatsAndTownsEvidence
extends SceneTree

const SEED_TEXT: String = "golden-ac9"
const HABITAT_IDS: Array[String] = ["main", "ally_0", "ally_1", "enemy"]

var _failures: int = 0


class MemoryRepository:
    extends RefCounted

    var bytes: PackedByteArray = PackedByteArray()
    var writes: int = 0

    func replace_atomic(candidate: PackedByteArray) -> Dictionary:
        writes += 1
        bytes = candidate.duplicate()
        return {"ok": true, "error": null}

    func load_validated() -> Dictionary:
        return load("res://Scripts/Save/world_run_save_codec_v8.gd").decode_any(bytes)


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(
        func(_plan: RefCounted) -> void: pass
    )
    var session: Dictionary = service.start(SEED_TEXT)
    _expect(bool(session.get("ok", false)), "real V2 session starts")
    if not bool(session.get("ok", false)):
        _finish()
        return
    var plan: WorldPlan = session.plan
    var start_coord: Vector2i = plan.get_start_coord()
    var enemy_coord: Vector2i = plan.get_boss_coord()
    var habitats: Array = plan.get_habitats()
    var towns: Array = plan.get_towns()
    var roads: Array = plan.get_roads()
    var cells: Dictionary = plan.get_cells()
    var cell_counts: Dictionary = {}
    var town_counts: Dictionary = {}
    for habitat_id: String in HABITAT_IDS:
        cell_counts[habitat_id] = plan.get_habitat_cells(habitat_id).size()
        town_counts[habitat_id] = 0
    for town_value: Variant in towns:
        if not town_value is Dictionary:
            continue
        var town_habitat_id: String = String(town_value.get("habitat_id", ""))
        if town_counts.has(town_habitat_id):
            town_counts[town_habitat_id] = int(town_counts[town_habitat_id]) + 1
    _expect(plan.get_version() == 2, "generator version is V2")
    _expect(start_coord == Vector2i(8, 0) and enemy_coord == Vector2i(-8, 0),
        "player starts east and enemy starts west")
    _expect(start_coord.x > enemy_coord.x, "east/west ordering is explicit")
    _expect(cells.size() == 217, "radius-eight world has 217 cells")
    _expect(habitats.size() == 4, "four habitats generated")
    _expect(towns.size() == 9, "nine towns generated")
    _expect(int(cell_counts.enemy) == 9, "enemy footprint has nine cells")
    _expect(town_counts == {"main": 3, "ally_0": 3, "ally_1": 3, "enemy": 0},
        "towns are three per allied habitat")
    _expect(roads.is_empty(), "V2 roads remain empty")
    var repository: MemoryRepository = MemoryRepository.new()
    var packed: PackedScene = load("res://Scenes/world_map_runtime.tscn")
    var world: WorldRuntimeController = packed.instantiate() as WorldRuntimeController
    world.auto_initialize_runtime = false
    root.add_child(world)
    await process_frame
    _expect(world.apply_session(session, repository), "real V2 runtime session applies")
    if not world.is_session_applied():
        world.free()
        _finish()
        return
    var fresh_view: Dictionary = world.get_debug_snapshot()
    _expect(session.run_state.player_coord == start_coord
        and fresh_view.player_coord == start_coord,
        "fresh runtime player begins at generated player start")
    _expect(session.run_state.boss_coord == enemy_coord
        and fresh_view.boss_coord == enemy_coord,
        "fresh runtime boss begins at generated enemy start")
    var allied_town: Dictionary = _first_allied_town(towns)
    _expect(not allied_town.is_empty(), "an allied town exists")
    if allied_town.is_empty():
        world.free()
        _finish()
        return
    var town_coord: Vector2i = allied_town.coord
    var state_data: Dictionary = session.run_state.to_dictionary()
    state_data["player_coord"] = [town_coord.x, town_coord.y]
    state_data["boss_coord"] = [start_coord.x, start_coord.y]
    state_data["boss_active"] = true
    state_data["move_count"] = 30
    var built: Dictionary = load("res://Scripts/Run/world_run_state.gd").from_dictionary(
        state_data,
        plan
    )
    _expect(bool(built.get("ok", false)), "mutable runtime position fixture validates")
    if not bool(built.get("ok", false)):
        world.free()
        _finish()
        return
    var moved_session: Dictionary = session.duplicate()
    moved_session.run_state = built.value
    _expect(world.apply_session(moved_session, repository), "same plan reapplies with mutable positions")
    var view: Dictionary = world.get_debug_snapshot()
    var presenter: Script = load("res://Scripts/UI/world_debug_presenter.gd")
    var sections: Dictionary = presenter.call("format_sections", view)
    var minimap: WorldMinimap = world.get_node("%WorldMinimap") as WorldMinimap
    var presentation_counts: Dictionary = {
        "main_cells": world.get_main_cell_count(),
        "town_markers": world.get_town_count(),
        "roads": world.get_road_count(),
        "minimap_cells": minimap.get_cell_count() if is_instance_valid(minimap) else -1,
        "minimap_towns": minimap.get_town_count() if is_instance_valid(minimap) else -1,
    }
    _expect(presentation_counts.main_cells == 217, "main presentation has 217 cells")
    _expect(presentation_counts.town_markers == 9, "main presentation has nine town markers")
    _expect(presentation_counts.roads == 0, "main presentation has zero roads")
    _expect(presentation_counts.minimap_cells == 217, "minimap has 217 cell markers")
    _expect(presentation_counts.minimap_towns == 9, "minimap has nine town markers")
    _expect(view.generated_player_start == start_coord and view.generated_enemy_start == enemy_coord,
        "debug snapshot exposes generated starts")
    _expect(view.player_coord == town_coord and view.boss_coord == start_coord,
        "debug snapshot exposes distinct mutable positions")
    _expect(view.habitat_cell_counts == cell_counts, "debug snapshot exposes habitat cells")
    _expect(view.habitat_town_counts == town_counts, "debug snapshot exposes habitat towns")
    _expect(view.enemy_footprint_count == 9 and view.generated_town_count == 9,
        "debug snapshot exposes enemy and town totals")
    _expect(view.generated_road_count == 0, "debug snapshot exposes zero generated roads")
    _expect(view.ownership.town_id == allied_town.town_id
        and view.ownership.habitat_id == allied_town.habitat_id
        and view.ownership.clan_id == view.habitat.clan_id,
        "debug snapshot exposes allied town ownership")
    _expect(sections.map.contains("Generated player start: (8, 0)")
        and sections.map.contains("Generated enemy start: (-8, 0)")
        and sections.map.contains("Enemy footprint: 9")
        and sections.map.contains("Generated towns: 9")
        and sections.map.contains("Generated roads: 0"),
        "map presentation exposes canonical V2 topology")
    _expect(sections.habitat.contains("Town ID: " + String(allied_town.town_id))
        and sections.habitat.contains("Town habitat ID: " + String(allied_town.habitat_id))
        and sections.habitat.contains("Town clan: " + String(view.ownership.clan_id)),
        "habitat presentation exposes allied town ownership")
    _expect(repository.writes == 0, "evidence capture never writes save data")
    var canonical_bytes: PackedByteArray = load(
        "res://Scripts/WorldMap/world_plan_codec_v2.gd"
    ).serialize(plan)
    var hashing: HashingContext = HashingContext.new()
    hashing.start(HashingContext.HASH_SHA256)
    hashing.update(canonical_bytes)
    var canonical_sha: String = hashing.finish().hex_encode()
    var record: Dictionary = {
        "seed": SEED_TEXT,
        "generator_version": plan.get_version(),
        "generated_player_start": [start_coord.x, start_coord.y],
        "generated_enemy_start": [enemy_coord.x, enemy_coord.y],
        "fresh_runtime_player": [fresh_view.player_coord.x, fresh_view.player_coord.y],
        "fresh_runtime_boss": [fresh_view.boss_coord.x, fresh_view.boss_coord.y],
        "mutated_runtime_player": [view.player_coord.x, view.player_coord.y],
        "mutated_runtime_boss": [view.boss_coord.x, view.boss_coord.y],
        "cells": cells.size(),
        "habitat_cell_counts": cell_counts,
        "town_counts": town_counts,
        "enemy_footprint": view.enemy_footprint_count,
        "towns": towns.size(),
        "roads": roads.size(),
        "town_ownership": {
            "town_id": String(view.ownership.town_id),
            "local_index": view.ownership.local_index,
            "habitat_id": String(view.ownership.habitat_id),
            "role": String(view.ownership.role),
            "clan_id": String(view.ownership.clan_id),
        },
        "presentation_counts": presentation_counts,
        "canonical_sha256": canonical_sha,
    }
    print("AC9_4_EVIDENCE " + JSON.stringify(record))
    world.free()
    await process_frame
    _finish()


func _first_allied_town(towns: Array) -> Dictionary:
    for town_value: Variant in towns:
        if (
            town_value is Dictionary
            and String(town_value.get("habitat_id", "")) in ["ally_0", "ally_1"]
        ):
            return town_value.duplicate(true)
    return {}


func _expect(condition: bool, message: String) -> void:
    if condition:
        return
    _failures += 1
    push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS capture_ac9_4_habitats_and_towns")
    else:
        print("FAIL capture_ac9_4_habitats_and_towns (%d failures)" % _failures)
    quit(0 if _failures == 0 else 1)
