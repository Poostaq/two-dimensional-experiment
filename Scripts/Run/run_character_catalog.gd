class_name RunCharacterCatalog
extends RefCounted

const COMBAT_SCOUT_REWARD_ID := &"combat_recruit_scout"
const BOSS_CHAMPION_REWARD_ID := &"boss_recruit_champion"
const PLAYER_COMMANDER_IDS: Array[StringName] = [
	&"brakka_rustbanner",
	&"goruk_ironline",
	&"veyra_moontrace",
	&"sszek_still_mire",
	&"kyris_windscar",
]
const PLAYER_COMMANDER_PRESENTATION := {
	&"brakka_rustbanner": {"title": "Packmarshal · Goblin Commander", "root_class_name": "Scrapshield Bruiser"},
	&"goruk_ironline": {"title": "War-Khan · Orc Commander", "root_class_name": "Iron Tusk Vanguard"},
	&"veyra_moontrace": {"title": "Hunt Matriarch · Werewolf Commander", "root_class_name": "Moonfang Skirmisher"},
	&"sszek_still_mire": {"title": "Delta Strategist · Lizardman Commander", "root_class_name": "Venom Saurian"},
	&"kyris_windscar": {"title": "Sky Matron · Harpy Commander", "root_class_name": "Talon Duelist"},
}
const PLAYABLE_CLAN_IDS: Array[StringName] = [
	&"goblin", &"orc", &"werewolf", &"lizardman", &"harpy",
]
const MAIN_CLAN_SYNERGY_IDS := {
	&"goblin": [&"orc", &"werewolf", &"lizardman"],
	&"orc": [&"goblin", &"lizardman", &"harpy"],
	&"werewolf": [&"goblin", &"lizardman", &"harpy"],
	&"lizardman": [&"goblin", &"orc", &"werewolf"],
	&"harpy": [&"goblin", &"orc", &"werewolf"],
}
const ORC_CLASS_IDS: Array[StringName] = [
	&"orc_iron_tusk_vanguard",
	&"orc_bonebreaker_reaver",
	&"orc_bloodbanner_captain",
	&"orc_chainwarden",
	&"orc_war_drummer",
	&"orc_siegebreaker",
]

const DWARF_CLASS_IDS: Array[StringName] = [
	&"dwarf_forgewarden", &"dwarf_siege_smith", &"dwarf_rune_sentinel",
	&"dwarf_quarrel_engineer", &"dwarf_hearthkeeper", &"dwarf_thunderbreaker",
]

const ELF_CLASS_IDS: Array[StringName] = [
	&"elf_star_archer", &"elf_moon_sage", &"elf_wind_dancer",
	&"elf_warden_of_the_grove", &"elf_crescent_duelist", &"elf_highborn_mystic",
]

const HUMAN_CLASS_IDS: Array[StringName] = [
	&"human_vanguard", &"human_ranger", &"human_iron_sentinel",
	&"human_field_medic", &"human_crosbowman", &"human_duelist",
]

const HARPY_CLASS_IDS: Array[StringName] = [
	&"harpy_talon_duelist", &"harpy_storm_siren", &"harpy_gale_scout",
	&"harpy_skyhook_raider", &"harpy_nestguard", &"harpy_carrion_cantor",
]

const WEREWOLF_CLASS_IDS: Array[StringName] = [
	&"werewolf_moonfang_skirmisher", &"werewolf_pack_howler", &"werewolf_bloodtrail_stalker",
	&"werewolf_duskhide_ravager", &"werewolf_den_warden", &"werewolf_moonblood_seer",
]

const LIZARDMAN_CLASS_IDS: Array[StringName] = [
	&"lizardman_venom_saurian",
	&"lizardman_scale_sentinel",
	&"lizardman_mire_spitter",
	&"lizardman_fang_alchemist",
	&"lizardman_reed_ambusher",
	&"lizardman_sunscale_warder",
]

const GOBLIN_CLASS_IDS: Array[StringName] = [
	&"scrapshield_bruiser",
	&"wirefang_skirmisher",
	&"snarewright",
	&"scrapbroker",
	&"shivrunner",
	&"mobcaller",
]


static func get_goblin_class_ids() -> Array[StringName]:
	return GOBLIN_CLASS_IDS.duplicate()


static func get_player_commander_ids() -> Array[StringName]:
	return PLAYER_COMMANDER_IDS.duplicate()


static func get_playable_clan_ids() -> Array[StringName]:
	return PLAYABLE_CLAN_IDS.duplicate()


static func get_playable_clans() -> Array[StringName]:
	return get_playable_clan_ids()


static func get_synergistic_clan_ids(main_clan_id: StringName) -> Array[StringName]:
	var values: Array = MAIN_CLAN_SYNERGY_IDS.get(main_clan_id, [])
	var result: Array[StringName] = []
	for value: Variant in values:
		result.append(StringName(value))
	return result


static func has_main_clan_synergy(main_clan_id: StringName, partner_clan_id: StringName) -> bool:
	return get_synergistic_clan_ids(main_clan_id).has(partner_clan_id)


static func get_player_commander_ids_for_clan(clan_id: StringName) -> Array[StringName]:
	var commander_ids: Array[StringName] = []
	for commander_id: StringName in PLAYER_COMMANDER_IDS:
		if get_commander_faction_id(commander_id) == clan_id:
			commander_ids.append(commander_id)
	return commander_ids


static func get_commander_presentation(commander_id: StringName) -> Dictionary:
	if not PLAYER_COMMANDER_IDS.has(commander_id):
		return {}
	var commander: RunCharacter = create_by_class_id(commander_id)
	if not is_instance_valid(commander):
		return {}
	var metadata: Dictionary = PLAYER_COMMANDER_PRESENTATION[commander_id]
	return {
		"commander_id": commander_id,
		"display_name": commander.display_name,
		"title": String(metadata["title"]),
		"root_class_name": String(metadata["root_class_name"]),
		"root_class_id": commander.root_class_id,
		"race_id": commander.race_id,
		"skills": commander.get_skills().duplicate(),
		"portrait_label": commander.display_name,
	}


static func get_commander_faction_id(commander_id: StringName) -> StringName:
	var commander: RunCharacter = create_by_class_id(commander_id)
	return commander.race_id if is_instance_valid(commander) and PLAYER_COMMANDER_IDS.has(commander_id) else &""


static func get_recruitable_class_ids(clan_id: StringName) -> Array[StringName]:
	if clan_id == &"goblin":
		return get_goblin_class_ids()
	if clan_id == &"orc":
		return ORC_CLASS_IDS.duplicate()
	if clan_id == &"lizardman":
		return LIZARDMAN_CLASS_IDS.duplicate()
	if clan_id == &"werewolf":
		return WEREWOLF_CLASS_IDS.duplicate()
	if clan_id == &"harpy":
		return HARPY_CLASS_IDS.duplicate()
	if clan_id == &"human":
		return HUMAN_CLASS_IDS.duplicate()
	if clan_id == &"elf":
		return ELF_CLASS_IDS.duplicate()
	if clan_id == &"dwarf":
		return DWARF_CLASS_IDS.duplicate()
	return []


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	var character: RunCharacter = _create_from_catalog("res://Scripts/Run/dwarf_wave_a_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/dwarf_wave_b_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/dwarf_commander_catalog.gd", class_id, true)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/elf_wave_a_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/elf_wave_b_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/elf_commander_catalog.gd", class_id, true)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/human_wave_a_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/human_wave_b_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/human_commander_catalog.gd", class_id, true)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/harpy_wave_a_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/harpy_wave_b_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/harpy_commander_catalog.gd", class_id, true)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/werewolf_wave_a_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/werewolf_wave_b_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/werewolf_commander_catalog.gd", class_id, true)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/lizardman_wave_a_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/lizardman_wave_b_catalog.gd", class_id, false)
	if is_instance_valid(character):
		return character
	character = _create_from_catalog("res://Scripts/Run/lizardman_commander_catalog.gd", class_id, true)
	if is_instance_valid(character):
		return character
	var orc_wave_a_script := load("res://Scripts/Run/orc_wave_a_catalog.gd") as Script
	character = orc_wave_a_script.create_by_class_id(class_id)
	if is_instance_valid(character):
		character.class_id = class_id
		return character
	var orc_wave_b_script := load("res://Scripts/Run/orc_wave_b_catalog.gd") as Script
	character = orc_wave_b_script.create_by_class_id(class_id)
	if is_instance_valid(character):
		character.class_id = class_id
		return character
	var orc_commander_script := load("res://Scripts/Run/orc_commander_catalog.gd") as Script
	character = orc_commander_script.create_by_commander_id(class_id)
	if is_instance_valid(character):
		return character
	var wave_a_script := load("res://Scripts/Run/goblin_wave_a_catalog.gd") as Script
	character = wave_a_script.create_by_class_id(class_id)
	if is_instance_valid(character):
		character.class_id = class_id
		return character
	var wave_b_script := load("res://Scripts/Run/goblin_wave_b_catalog.gd") as Script
	character = wave_b_script.create_by_class_id(class_id)
	if is_instance_valid(character):
		character.class_id = class_id
		return character
	var commander_script := load("res://Scripts/Run/goblin_commander_catalog.gd") as Script
	return commander_script.create_by_commander_id(class_id)


static func _create_from_catalog(path: String, identity: StringName, commander: bool) -> RunCharacter:
	var catalog := load(path) as Script
	var character: RunCharacter = catalog.create_by_commander_id(identity) if commander else catalog.create_by_class_id(identity)
	if is_instance_valid(character) and not commander:
		character.class_id = identity
	return character


static func create_starters_for_commander(commander_id: StringName) -> Array[RunCharacter]:
	if not PLAYER_COMMANDER_IDS.has(commander_id):
		return []
	var commander: RunCharacter = create_by_class_id(commander_id)
	if not is_instance_valid(commander):
		return []
	var class_ids: Array[StringName] = get_recruitable_class_ids(commander.race_id)
	if class_ids.size() < 3:
		return []
	var left_member: RunCharacter = create_by_class_id(class_ids[1])
	var right_member: RunCharacter = create_by_class_id(class_ids[2])
	if not is_instance_valid(left_member) or not is_instance_valid(right_member):
		return []
	return [left_member, commander, right_member]


static func create_starters() -> Array[RunCharacter]:
	var starters: Array[RunCharacter] = []
	for index: int in 3:
		var character: RunCharacter = create_by_class_id(GOBLIN_CLASS_IDS[index])
		# Keep saved formation identities while replacing placeholder content.
		character.character_id = StringName("player_%d" % index)
		starters.append(character)
	return starters


static func create_for_reward(reward_id: StringName) -> RunCharacter:
	var reward: RunCharacter = null
	match reward_id:
		COMBAT_SCOUT_REWARD_ID:
			reward = RunCharacter.new(&"scout", "Scout", 7, 20, [])
		BOSS_CHAMPION_REWARD_ID:
			reward = RunCharacter.new(&"champion", "Champion", 9, 24, [])
		_:
			return null
	reward.class_id = &""
	reward.root_class_id = &""
	return reward
