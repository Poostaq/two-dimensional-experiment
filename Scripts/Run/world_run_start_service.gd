class_name WorldRunStartService
extends RefCounted

const RETURN_RESULT := "RETURN_RESULT"

static var GENERATOR_SCRIPT: GDScript = load("res://Scripts/WorldMap/hex_world_generator_v2.gd")
static var ERROR_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_generation_error.gd")
static var PRIORITY_SCRIPT: GDScript = load("res://Scripts/WorldMap/world_priority.gd")
static var ECONOMY_RULES_SCRIPT: GDScript = load("res://Scripts/Run/run_economy_rules.gd")
static var RUN_STATE_SCRIPT: GDScript = load("res://Scripts/Run/world_run_state.gd")
static var ENEMY_CLAN_SELECTOR_SCRIPT: GDScript = load(
    "res://Scripts/Run/run_enemy_clan_selector.gd"
)
static var ENEMY_BOSS_SELECTION_SCRIPT: GDScript = load(
    "res://Scripts/Run/run_enemy_boss_selection.gd"
)

var _commit_callback: Callable
var _generator: RefCounted
var _enemy_clan_selector: Callable


func _init(
    commit_callback: Callable,
    generator: RefCounted = null,
    enemy_clan_selector: Callable = Callable()
) -> void:
    _commit_callback = commit_callback
    _generator = generator if generator != null else GENERATOR_SCRIPT.new()
    _enemy_clan_selector = (
        enemy_clan_selector
        if enemy_clan_selector.is_valid()
        else Callable(ENEMY_CLAN_SELECTOR_SCRIPT, "select")
    )


func start(
    seed_text: String,
    config: Dictionary = {},
    policy: String = RETURN_RESULT,
    commander_id: StringName = GoblinCommanderCatalog.BRAKKA_ID,
    faction_id: StringName = &"",
    selection: RunClanSelection = null,
    coalition: RunClanCoalition = null,
    enemy_boss_selection: RefCounted = null
) -> Dictionary:
    var commander: RunCharacter = RunCharacterCatalog.create_by_class_id(commander_id)
    if not RunCharacterCatalog.get_player_commander_ids().has(commander_id) or not is_instance_valid(commander):
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                2,
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
                2,
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
                    2,
                    "run-start",
                    "invalid_clan_selection"
                ),
            }
        resolved_selection = selection_result["value"] as RunClanSelection
    var selection_validation: Dictionary = RunClanSelection.create(
        resolved_selection.main_clan_id,
        resolved_selection.commander_id,
        resolved_selection.seed_text
    )
    if (
        not bool(selection_validation.get("ok", false))
        or resolved_selection.main_clan_id != commander.race_id
        or resolved_selection.commander_id != commander_id
        or resolved_selection.seed_text != seed_text.strip_edges()
    ):
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                2,
                "run-start",
                "invalid_clan_selection"
            ),
        }
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
                2,
                "run-start",
                "allied_coalition_main_clan_mismatch"
            ),
        }
    var coalition_validation: Dictionary = RunClanCoalition.create(
        resolved_coalition.main_clan_id,
        resolved_coalition.allied_clan_ids
    )
    if not bool(coalition_validation.get("ok", false)):
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                2,
                "run-start",
                "invalid_allied_coalition"
            ),
        }
    var resolved_enemy_boss_selection: RefCounted = enemy_boss_selection
    if not is_instance_valid(resolved_enemy_boss_selection):
        var enemy_selection_result: Dictionary = _enemy_clan_selector.call(seed_text)
        if not bool(enemy_selection_result.get("ok", false)):
            return {
                "ok": false,
                "plan": null,
                "error": enemy_selection_result.get("error"),
            }
        resolved_enemy_boss_selection = enemy_selection_result.get("value") as RefCounted
    if not is_instance_valid(resolved_enemy_boss_selection):
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                2,
                "run-start",
                "enemy_boss_selection_invalid"
            ),
        }
    var enemy_selection_valid: bool = (
        resolved_enemy_boss_selection.get_script() == ENEMY_BOSS_SELECTION_SCRIPT
    )
    if enemy_selection_valid:
        var enemy_selection_validation: Dictionary = ENEMY_BOSS_SELECTION_SCRIPT.create(
            resolved_enemy_boss_selection.resolved_seed,
            resolved_enemy_boss_selection.enemy_clan_id,
            resolved_enemy_boss_selection.boss_party_id
        )
        enemy_selection_valid = (
            bool(enemy_selection_validation.get("ok", false))
            and resolved_enemy_boss_selection.resolved_seed == seed_text.strip_edges()
        )
    if not enemy_selection_valid:
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                2,
                "run-start",
                "enemy_boss_selection_invalid"
            ),
        }
    if policy != RETURN_RESULT:
        return {
            "ok": false,
            "plan": null,
            "error": ERROR_SCRIPT.new(
                ERROR_SCRIPT.WORLD_GENERATION_INTERNAL_ERROR,
                PRIORITY_SCRIPT.seed_hex(seed_text),
                2,
                "run-start",
                "unsupported_failure_policy=%s" % policy
            ),
        }
    var generation_config: Dictionary = config.duplicate(true)
    generation_config["main_clan_id"] = resolved_selection.main_clan_id
    generation_config["allied_clan_ids"] = resolved_coalition.allied_clan_ids.duplicate()
    generation_config["enemy_clan_id"] = resolved_enemy_boss_selection.enemy_clan_id
    var generated: Dictionary = _generator.generate(seed_text, generation_config)
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
        "enemy_boss_selection": resolved_enemy_boss_selection,
        "error": null,
    }
