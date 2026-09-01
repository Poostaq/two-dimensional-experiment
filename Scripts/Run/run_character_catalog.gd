class_name RunCharacterCatalog
extends RefCounted

const COMBAT_SCOUT_REWARD_ID := &"combat_recruit_scout"
const BOSS_CHAMPION_REWARD_ID := &"boss_recruit_champion"


static func create_by_class_id(class_id: StringName) -> RunCharacter:
	var wave_a_script := load("res://Scripts/Run/goblin_wave_a_catalog.gd") as Script
	var character: RunCharacter = wave_a_script.create_by_class_id(class_id)
	if is_instance_valid(character):
		return character
	var wave_b_script := load("res://Scripts/Run/goblin_wave_b_catalog.gd") as Script
	return wave_b_script.create_by_class_id(class_id)


static func create_starters() -> Array[RunCharacter]:
	return [
		RunCharacter.new(&"player_0", "Player Front 1", 8, 20, []),
		RunCharacter.new(&"player_1", "Player Front 2", 6, 20, []),
		RunCharacter.new(&"player_2", "Player Front 3", 6, 20, []),
	]


static func create_for_reward(reward_id: StringName) -> RunCharacter:
	match reward_id:
		COMBAT_SCOUT_REWARD_ID:
			return RunCharacter.new(&"scout", "Scout", 7, 20, [])
		BOSS_CHAMPION_REWARD_ID:
			return RunCharacter.new(&"champion", "Champion", 9, 24, [])
		_:
			return null
