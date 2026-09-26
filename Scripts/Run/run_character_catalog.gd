class_name RunCharacterCatalog
extends RefCounted

const COMBAT_SCOUT_REWARD_ID := &"combat_recruit_scout"
const BOSS_CHAMPION_REWARD_ID := &"boss_recruit_champion"
const ORC_CLASS_IDS: Array[StringName] = [
	&"orc_iron_tusk_vanguard",
	&"orc_bonebreaker_reaver",
	&"orc_bloodbanner_captain",
	&"orc_chainwarden",
	&"orc_war_drummer",
	&"orc_siegebreaker",
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


static func get_recruitable_class_ids(clan_id: StringName) -> Array[StringName]:
	if clan_id == &"goblin":
		return get_goblin_class_ids()
	if clan_id == &"orc":
		return ORC_CLASS_IDS.duplicate()
	if clan_id == &"lizardman":
		return LIZARDMAN_CLASS_IDS.duplicate()
	return []


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	var character: RunCharacter = _create_from_catalog("res://Scripts/Run/lizardman_wave_a_catalog.gd", class_id, false)
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


static func create_starters() -> Array[RunCharacter]:
	var starters: Array[RunCharacter] = []
	for index: int in 3:
		var character: RunCharacter = create_by_class_id(GOBLIN_CLASS_IDS[index])
		# Keep saved formation identities while replacing placeholder content.
		character.character_id = StringName("player_%d" % index)
		starters.append(character)
	return starters


static func create_for_reward(reward_id: StringName) -> RunCharacter:
	match reward_id:
		COMBAT_SCOUT_REWARD_ID:
			return RunCharacter.new(&"scout", "Scout", 7, 20, [])
		BOSS_CHAMPION_REWARD_ID:
			return RunCharacter.new(&"champion", "Champion", 9, 24, [])
		_:
			return null
