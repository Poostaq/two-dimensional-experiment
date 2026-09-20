class_name RunCharacterCatalog
extends RefCounted

const COMBAT_SCOUT_REWARD_ID := &"combat_recruit_scout"
const BOSS_CHAMPION_REWARD_ID := &"boss_recruit_champion"
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
	return []


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	var wave_a_script := load("res://Scripts/Run/goblin_wave_a_catalog.gd") as Script
	var character: RunCharacter = wave_a_script.create_by_class_id(class_id)
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
