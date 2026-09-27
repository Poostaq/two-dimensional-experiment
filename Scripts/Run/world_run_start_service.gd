class_name WorldRunStartService
extends RefCounted

const RETURN_RESULT := "RETURN_RESULT"

static var GENERATOR_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_generator_v1.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var ECONOMY_RULES_SCRIPT: GDScript = load("res://Scripts/Run/run_economy_rules.gd")
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")

var _commit_callback: Callable
var _generator: RefCounted


func _init(commit_callback: Callable, generator: RefCounted = null) -> void:
    _commit_callback = commit_callback
    _generator = generator if generator != null else GENERATOR_SCRIPT.new()


func start(
    seed_text: String,
    config: Dictionary = {},
    policy: String = RETURN_RESULT,
    commander_id: StringName = GoblinCommanderCatalog.BRAKKA_ID,
    faction_id: StringName = &"",
    selection: RunClanSelection = null,
    coalition: RunClanCoalition = null
) -> Dictionary:
    var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(commander_id)
    if not RunCharacterCatalog.get_player_commander_ids().has(commander_id) or not is_instance_valid(commander):
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                1,
                "run-start",
                "invalid_commander_id=%s" % String(commander_id)
            ),
        }
    if not faction_id.is_empty() and commander.race_id != faction_id:
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                1,
                "run-start",
                "invalid_commander_faction=%s:%s" % [String(commander_id), String(faction_id)]
            ),
        }
    var resolved_selection: RunClanSelection = selection
    if not is_instance_valid(resolved_selection):
        var selection_result: Dictionary = RunClanSelection.create(
            commander.race_id if faction_id.is_empty() else faction_id,
            commander_id,
            seed_text
        )
        if not bool(selection_result.get("ok", false)):
            return {
                "ok": false,
                "plan": null,
                "error": ERROR_SCRIPT.new(
                    ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                    PRIORITY_SCRIPT.seed_hex(seed_text),
                    1,
                    "run-start",
                    "invalid_clan_selection"
                ),
            }
        resolved_selection = selection_result["value"] as RunClanSelection
    var resolved_coalition: RunClanCoalition = coalition
    if not is_instance_valid(resolved_coalition):
        var coalition_result: Dictionary = RunAlliedClanSelector.select(
            resolved_selection.main_clan_id,
            seed_text
        )
        if not bool(coalition_result.get("ok", false)):
            return {
                "ok": false,
                "plan": null,
                "error": coalition_result.get("error"),
            }
        resolved_coalition = coalition_result["value"] as RunClanCoalition
    if resolved_coalition.main_clan_id != resolved_selection.main_clan_id:
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                1,
                "run-start",
                "allied_coalition_main_clan_mismatch"
            ),
        }
    if policy != RETURN_RESULT:
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                1,
                "run-start",
                "unsupported_failure_policy=%s" % policy
            ),
        }
    var generated: Dictionary = _generator.generate(seed_text, config)
    if not generated.get("ok", false):
        return {
            "ok": false,
            "plan": null,
            "error": generated["error"],
        }
    var plan: RefCounted = generated["plan"]
    if not _commit_callback.is_valid():
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                plan.get_seed_hex(),
                plan.get_version(),
                "run-start",
                "commit_callback_invalid"
            ),
        }
    var consumed_encounters: Array[Vector2i] = []
    var formation: Array[StringName] = []
    formation.resize(RunRoster.MAX_ROSTER_SIZE)
    var starters: Array[RunCharacter] = RunCharacterCatalog.create_starters_for_commander(commander_id)
    if starters.size() <= 1:
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                plan.get_seed_hex(),
                plan.get_version(),
                "run-start",
                "starter_formation_missing_middle_frontline"
            ),
        }
    starters[1] = commander
    for slot_index: int in starters.size():
        formation[slot_index] = starters[slot_index].character_id
    var run_state: RefCounted = RUN_STATE_SCRIPT.create(
        plan.get_start_coord(),
        plan.get_boss_coord(),
        0,
        false,
        false,
        consumed_encounters,
        formation
    )
    if not is_instance_valid(run_state):
        return {
            "ok": false,
            "plan": null,
            "resolved_seed": "",
            "run_state": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                plan.get_seed_hex(),
                plan.get_version(),
                "run-start",
                "initial_run_state_invalid"
            ),
        }
    var initial_health: Dictionary[StringName, int] = {}
    for character: RunCharacter in starters:
        initial_health[character.character_id] = character.max_hp
    run_state.set_character_hp_snapshot(initial_health)
    run_state.run_status = "active"
    run_state.battle_settlements = []
    run_state.set("gold", ECONOMY_RULES_SCRIPT.STARTING_GOLD)
    _commit_callback.call(plan)
    return {
        "ok": true,
        "plan": plan,
        "resolved_seed": seed_text,
        "run_state": run_state,
        "selection": resolved_selection,
        "coalition": resolved_coalition,
        "error": null,
    }
