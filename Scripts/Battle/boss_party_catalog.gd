class_name BossPartyCatalog
extends RefCounted

static var _DEFINITIONS_BY_CLAN: Dictionary[StringName, EnemyBossPartyDefinition] = _build_definitions()


static func get_definition_by_enemy_clan_id(
    enemy_clan_id: StringName
) -> EnemyBossPartyDefinition:
    var definition: EnemyBossPartyDefinition = (
        _DEFINITIONS_BY_CLAN.get(enemy_clan_id) as EnemyBossPartyDefinition
    )
    return _copy_definition(definition) if is_instance_valid(definition) else null


static func get_definition_by_party_id(
    boss_party_id: StringName
) -> EnemyBossPartyDefinition:
    for value: EnemyBossPartyDefinition in _DEFINITIONS_BY_CLAN.values():
        if value.boss_party_id == boss_party_id:
            return _copy_definition(value)
    return null


static func create_by_party_id(boss_party_id: StringName) -> Array[RunCharacter]:
    var definition: EnemyBossPartyDefinition = get_definition_by_party_id(boss_party_id)
    if not is_instance_valid(definition) or not _is_valid_definition(definition):
        return []
    return _create_party(definition.get_member_class_ids())


static func create_by_enemy_clan_id(enemy_clan_id: StringName) -> Array[RunCharacter]:
    var definition: EnemyBossPartyDefinition = get_definition_by_enemy_clan_id(enemy_clan_id)
    return create_by_party_id(definition.boss_party_id) if is_instance_valid(definition) else []


static func _build_definitions() -> Dictionary[StringName, EnemyBossPartyDefinition]:
    var definitions: Dictionary[StringName, EnemyBossPartyDefinition] = {}
    definitions[&"human"] = _definition(
        &"human_fortified_line_v1",
        &"human",
        &"marshal_elian_voss",
        &"fortified_line",
        [
            &"marshal_elian_voss",
            &"human_iron_sentinel",
            &"human_ranger",
            &"human_field_medic",
        ]
    )
    definitions[&"elf"] = _definition(
        &"elf_moonfall_exposure_v1",
        &"elf",
        &"lady_saelith_moonfall",
        &"moonfall_exposure",
        [
            &"lady_saelith_moonfall",
            &"elf_warden_of_the_grove",
            &"elf_star_archer",
            &"elf_crescent_duelist",
        ]
    )
    definitions[&"dwarf"] = _definition(
        &"dwarf_stonevein_forge_v1",
        &"dwarf",
        &"thane_brokk_stonevein",
        &"stonevein_forge",
        [
            &"thane_brokk_stonevein",
            &"dwarf_rune_sentinel",
            &"dwarf_siege_smith",
            &"dwarf_hearthkeeper",
        ]
    )
    return definitions


static func _definition(
    boss_party_id: StringName,
    enemy_clan_id: StringName,
    commander_id: StringName,
    combo_id: StringName,
    member_class_ids: Array[StringName]
) -> EnemyBossPartyDefinition:
    var result: Dictionary = EnemyBossPartyDefinition.create(
        boss_party_id,
        enemy_clan_id,
        commander_id,
        combo_id,
        member_class_ids
    )
    return result.get("value") as EnemyBossPartyDefinition


static func _copy_definition(
    definition: EnemyBossPartyDefinition
) -> EnemyBossPartyDefinition:
    if not is_instance_valid(definition):
        return null
    return _definition(
        definition.boss_party_id,
        definition.enemy_clan_id,
        definition.commander_id,
        definition.combo_id,
        definition.get_member_class_ids()
    )


static func _is_valid_definition(definition: EnemyBossPartyDefinition) -> bool:
    if (
        not RunCharacterCatalog.get_enemy_clan_ids().has(definition.enemy_clan_id)
        or definition.get_member_class_ids().size() != 4
    ):
        return false
    var party: Array[RunCharacter] = _create_party(definition.get_member_class_ids())
    if party.size() != 4:
        return false
    var commander_count: int = 0
    for member: RunCharacter in party:
        if member.race_id != definition.enemy_clan_id:
            return false
        commander_count += int(member.class_id == definition.commander_id)
    return commander_count == 1


static func _create_party(class_ids: Array[StringName]) -> Array[RunCharacter]:
    var party: Array[RunCharacter] = []
    for class_id: StringName in class_ids:
        var member: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
        if not is_instance_valid(member):
            return []
        party.append(member)
    return party
