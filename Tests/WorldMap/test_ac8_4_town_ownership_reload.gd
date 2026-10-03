extends SceneTree

var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var model_script: Script = load("res://Scripts/WorldMap/world_runtime_model.gd")
    var probe: RefCounted = model_script.new()
    if not probe.has_method("get_town_ownership"):
        _expect(false, "runtime ownership API exists")
        quit(1)
        return
    _expect(probe.get_town_ownership(Vector2i.ZERO).error == &"invalid_plan",
        "unconfigured runtime rejects")
    var plan_codec: Script = load("res://Scripts/WorldMap/world_plan_codec_v1.gd")
    var current_codec: Script = load("res://Scripts/Save/world_run_save_codec_v5.gd")
    for seed_text: String in ["golden-alpha", "ac8-town-beta", "ac8-town-gamma"]:
        var service: RefCounted = load("res://Scripts/Run/world_run_start_service.gd").new(
            func(_plan: RefCounted) -> void: pass,
            HexWorldGeneratorV1.new()
        )
        var session: Dictionary = service.start(seed_text)
        _expect(session.get("ok", false), "new run starts")
        if not session.get("ok", false):
            continue
        var plan: WorldPlan = session.plan
        var before: PackedByteArray = plan_codec.serialize(plan)
        var canonical_plan: WorldPlan = plan_codec.parse(before).plan
        var original_state: Dictionary = session.run_state.to_dictionary()
        var model: RefCounted = model_script.new()
        _expect(model.configure(plan), "runtime configures")
        _expect(model.restore_run_state(session.run_state), "runtime restores")
        var expected: Dictionary = _owners(model, plan)
        _expect(expected.size() == 7, "seven generated towns")
        _expect(_owners(model.duplicate_model(), plan) == expected, "candidate copy agrees")
        for version: int in [2, 3, 4, 5]:
            var writer: Script = load("res://Scripts/Save/world_run_save_codec_v%d.gd" % version)
            var saved: PackedByteArray = writer.encode(plan, seed_text, session.run_state)
            _expect(not saved.is_empty(), "save encodes")
            var decoded: Dictionary = current_codec.decode_any(saved)
            _expect(decoded.get("ok", false), "save decodes")
            if not decoded.get("ok", false):
                continue
            var restored_plan: WorldPlan = decoded.value.plan
            var restored: RefCounted = model_script.new()
            _expect(restored.configure(restored_plan), "restored runtime configures")
            _expect(restored.restore_run_state(decoded.value.run_state), "restored state valid")
            var restored_state: Dictionary = decoded.value.run_state.to_dictionary()
            _expect(_owners(restored, restored_plan) == expected, "all owners survive reload")
            _expect(plan_codec.serialize(restored_plan) == before, "canonical bytes unchanged")
            _expect(decoded.value.run_state.to_dictionary() == restored_state,
                "ownership queries do not mutate restored state")
            _expect(plan.get_cells() == restored_plan.get_cells() and
                canonical_plan.get_roads() == restored_plan.get_roads() and
                plan.get_start_coord() == restored_plan.get_start_coord() and
                plan.get_boss_coord() == restored_plan.get_boss_coord(),
                "towns roads and spawns preserved")
        _expect(session.run_state.to_dictionary() == original_state, "live state unchanged")
        _expect(plan_codec.serialize(plan) == before, "live map unchanged")
    _test_v2_reload(model_script)
    if failures == 0:
        print("PASS test_ac8_4_town_ownership_reload")
    quit(0 if failures == 0 else 1)

func _test_v2_reload(model_script: Script) -> void:
    var session: Dictionary = load("res://Scripts/Run/world_run_start_service.gd").new(
        func(_plan: RefCounted) -> void: pass
    ).start("ac8-town-v2-reload")
    _expect(session.get("ok", false), "v2 run starts")
    if not session.get("ok", false):
        return
    var plan: WorldPlan = session.plan
    var before: PackedByteArray = WorldPlanCodec.serialize(plan)
    var habitats_before: Array = plan.get_habitats()
    var towns_before: Array = plan.get_towns()
    var cells_before: Dictionary = plan.get_cells()
    var model: RefCounted = model_script.new()
    _expect(model.configure(plan), "v2 runtime configures")
    _expect(model.restore_run_state(session.run_state), "v2 runtime restores")
    var expected: Dictionary = _owners_v2(model, plan)
    _expect(expected.size() == 9, "nine v2 owners")
    var bytes: PackedByteArray = WorldRunSaveCodecV8.encode(
        plan, session.resolved_seed, session.run_state, session.selection,
        session.coalition, session.enemy_boss_selection
    )
    var decoded: Dictionary = WorldRunSaveCodecV8.decode_any(bytes)
    _expect(decoded.get("ok", false), "v2 save decodes")
    if decoded.get("ok", false):
        var restored_plan: WorldPlan = decoded.value.plan
        var restored: RefCounted = model_script.new()
        _expect(restored.configure(restored_plan), "v2 restored runtime configures")
        _expect(restored.restore_run_state(decoded.value.run_state), "v2 restored state valid")
        _expect(_owners_v2(restored, restored_plan) == expected, "v2 owners survive reload")
        _expect(WorldPlanCodec.serialize(restored_plan) == before, "v2 canonical bytes unchanged")
    _expect(WorldPlanCodec.serialize(plan) == before and plan.get_habitats() == habitats_before and
        plan.get_towns() == towns_before and plan.get_cells() == cells_before,
        "v2 reload ownership queries do not mutate live plan")

func _owners_v2(model: RefCounted, plan: WorldPlan) -> Dictionary:
    var result: Dictionary = {}
    for town_value: Variant in plan.get_towns():
        var town: Dictionary = town_value
        var owner: Dictionary = model.get_town_ownership(town.coord)
        _expect(owner.get("ok", false), "v2 restored owner resolves")
        _expect(owner.get("town_id", &"") == StringName(town.town_id) and
            owner.get("local_index", -1) == town.local_index and
            owner.get("habitat_id", &"") == StringName(town.habitat_id),
            "v2 restored owner identity exact")
        result[town.coord] = owner
    return result

func _owners(model: RefCounted, plan: WorldPlan) -> Dictionary:
    var result: Dictionary = {}
    var cells: Dictionary = plan.get_cells()
    for coord: Vector2i in cells:
        if cells[coord].town_index >= 0:
            var owner: Dictionary = model.get_town_ownership(coord)
            _expect(owner.ok and owner.clan_id == &"goblin", "runtime resolves Goblin")
            result[coord] = owner
        else:
            _expect(not model.get_town_ownership(coord).ok, "runtime rejects non-town")
    return result

func _expect(condition: bool, label: String) -> void:
    if not condition:
        failures += 1
        push_error(label)
