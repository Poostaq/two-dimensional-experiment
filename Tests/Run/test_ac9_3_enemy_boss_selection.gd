extends SceneTree

const EXPECTED_PARTIES := {
    &"human": {
        "party_id": &"human_fortified_line_v1",
        "combo_id": &"fortified_line",
        "commander_id": &"marshal_elian_voss",
        "member_ids": [
            &"marshal_elian_voss",
            &"human_iron_sentinel",
            &"human_ranger",
            &"human_field_medic",
        ],
    },
    &"elf": {
        "party_id": &"elf_moonfall_exposure_v1",
        "combo_id": &"moonfall_exposure",
        "commander_id": &"lady_saelith_moonfall",
        "member_ids": [
            &"lady_saelith_moonfall",
            &"elf_warden_of_the_grove",
            &"elf_star_archer",
            &"elf_crescent_duelist",
        ],
    },
    &"dwarf": {
        "party_id": &"dwarf_stonevein_forge_v1",
        "combo_id": &"stonevein_forge",
        "commander_id": &"thane_brokk_stonevein",
        "member_ids": [
            &"thane_brokk_stonevein",
            &"dwarf_rune_sentinel",
            &"dwarf_siege_smith",
            &"dwarf_hearthkeeper",
        ],
    },
}

var _failures: int = 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _expect(
        RunCharacterCatalog.get_enemy_clan_ids() == [&"human", &"elf", &"dwarf"],
        "Enemy clan order is canonical"
    )
    var selector_script: GDScript = load("res://Scripts/Run/run_enemy_clan_selector.gd")
    var golden_result: Dictionary = selector_script.select("ac9-enemy-vector-1")
    _expect(bool(golden_result.get("ok", false)), "Golden seed resolves an enemy boss selection")
    var golden: Variant = golden_result.get("value")
    _expect(is_instance_valid(golden), "Golden seed returns a selection value")
    if is_instance_valid(golden):
        _expect(golden.resolved_seed == "ac9-enemy-vector-1", "Selection preserves resolved seed")
        _expect(golden.enemy_clan_id == &"dwarf", "Golden seed resolves the dwarf clan")
        _expect(golden.boss_party_id == &"dwarf_stonevein_forge_v1", "Golden seed resolves Stonevein")
        var repeated_result: Dictionary = selector_script.select("ac9-enemy-vector-1")
        var repeated: Variant = repeated_result.get("value")
        _expect(is_instance_valid(repeated), "Repeated seed returns a selection")
        if is_instance_valid(repeated):
            _expect(repeated != golden, "Repeated selection is independent")
            _expect(
                repeated.enemy_clan_id == golden.enemy_clan_id
                and repeated.boss_party_id == golden.boss_party_id,
                "Repeated seed resolves identically"
            )
    for clan_id: StringName in EXPECTED_PARTIES:
        var expected: Dictionary = EXPECTED_PARTIES[clan_id]
        var definition: EnemyBossPartyDefinition = (
            BossPartyCatalog.get_definition_by_enemy_clan_id(clan_id)
        )
        _expect(is_instance_valid(definition), "%s definition resolves" % clan_id)
        if not is_instance_valid(definition):
            continue
        _expect(definition.boss_party_id == expected["party_id"], "%s party ID is exact" % clan_id)
        _expect(definition.combo_id == expected["combo_id"], "%s combo ID is exact" % clan_id)
        _expect(definition.commander_id == expected["commander_id"], "%s commander ID is exact" % clan_id)
        _expect(
            definition.get_member_class_ids() == expected["member_ids"],
            "%s member order is exact" % clan_id
        )
        var member_ids: Array[StringName] = definition.get_member_class_ids()
        member_ids.clear()
        _expect(
            definition.get_member_class_ids() == expected["member_ids"],
            "%s definition members are defensive" % clan_id
        )
        var by_party: EnemyBossPartyDefinition = (
            BossPartyCatalog.get_definition_by_party_id(expected["party_id"])
        )
        _expect(is_instance_valid(by_party), "%s party ID resolves" % clan_id)
        var party: Array[RunCharacter] = BossPartyCatalog.create_by_party_id(expected["party_id"])
        _expect(party.size() == 4, "%s party has four authored members" % clan_id)
        var commander_count: int = 0
        for member: RunCharacter in party:
            commander_count += int(member.class_id == expected["commander_id"])
            _expect(member.race_id == clan_id, "%s member matches enemy clan" % clan_id)
        _expect(commander_count == 1, "%s party has commander exactly once" % clan_id)
        party.clear()
        _expect(
            BossPartyCatalog.create_by_party_id(expected["party_id"]).size() == 4,
            "%s party construction is defensive" % clan_id
        )
    _expect(
        BossPartyCatalog.get_definition_by_enemy_clan_id(&"unknown") == null,
        "Unknown enemy clan has no definition"
    )
    _expect(
        BossPartyCatalog.create_by_party_id(&"unknown").is_empty(),
        "Unknown party ID creates no party"
    )
    _finish()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        _failures += 1
        push_error(message)


func _finish() -> void:
    if _failures == 0:
        print("PASS test_ac9_3_enemy_boss_selection")
    quit(1 if _failures > 0 else 0)
