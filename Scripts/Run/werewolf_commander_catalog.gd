extends RefCounted

const COMMANDER_ID: StringName = &"veyra_moontrace"
const ROOT_CLASS_ID: StringName = &"werewolf_moonfang_skirmisher"


static func create_by_commander_id(commander_id: StringName) -> RunCharacter:
	if commander_id != COMMANDER_ID:
		return null
	var root_script := load("res://Scripts/Run/werewolf_wave_a_catalog.gd") as Script
	var root: RunCharacter = root_script.create_by_class_id(ROOT_CLASS_ID)
	if not is_instance_valid(root):
		return null
	var skills: Array[CharacterSkill] = []
	for skill: CharacterSkill in root.get_skills():
		skills.append(skill.duplicate_skill())
	skills.append(CharacterSkill.create(&"mark_of_the_alpha", "Mark of the Alpha", CharacterSkill.Kind.PASSIVE, "The first enemy crossing below half HP each round grants Veyra Advantage and the triggering ally 15% Leech on its next direct hit.", "Veyra and triggering ally.", "Direct allied threshold damage.", "Once per round."))
	var commander := RunCharacter.new(COMMANDER_ID, "Veyra Moontrace", root.base_speed, root.max_hp, skills, root.power, root.defense, &"werewolf")
	commander.class_id = COMMANDER_ID
	return commander


static func get_presentation(commander_id: StringName) -> Dictionary:
	if commander_id != COMMANDER_ID:
		return {}
	return {&"commander_id": COMMANDER_ID, &"display_name": "Veyra Moontrace", &"title": "Hunt Matriarch", &"root_class_id": ROOT_CLASS_ID, &"race_id": &"werewolf"}
