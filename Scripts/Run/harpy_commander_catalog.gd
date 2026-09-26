extends RefCounted

const COMMANDER_ID: StringName = &"kyris_windscar"
const ROOT_CLASS_ID: StringName = &"harpy_talon_duelist"


static func create_by_commander_id(commander_id: StringName) -> RunCharacter:
	if commander_id != COMMANDER_ID:
		return null
	var root_script := load("res://Scripts/Run/harpy_wave_a_catalog.gd") as Script
	var root: RunCharacter = root_script.create_by_class_id(ROOT_CLASS_ID)
	if not is_instance_valid(root):
		return null
	var skills: Array[CharacterSkill] = []
	for skill: CharacterSkill in root.get_skills():
		skills.append(skill.duplicate_skill())
	skills.append(CharacterSkill.create(&"open_sky_command", "Open Sky Command", CharacterSkill.Kind.PASSIVE, "Once per round after an ally hits following Move 2 or 3, that ally may immediately move 1 on a legal declared path.", "Triggering ally.", "A direct hit after Move 2 or 3.", "Once per round."))
	var commander := RunCharacter.new(COMMANDER_ID, "Kyris Windscar", root.base_speed, root.max_hp, skills, root.power, root.defense, &"harpy")
	commander.class_id = COMMANDER_ID
	return commander


static func get_presentation(commander_id: StringName) -> Dictionary:
	if commander_id != COMMANDER_ID:
		return {}
	return {&"commander_id": COMMANDER_ID, &"display_name": "Kyris Windscar", &"title": "Sky Matron", &"root_class_id": ROOT_CLASS_ID, &"race_id": &"harpy"}
