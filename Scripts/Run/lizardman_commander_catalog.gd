extends RefCounted

const COMMANDER_ID: StringName = &"sszek_still_mire"
const ROOT_CLASS_ID: StringName = &"lizardman_venom_saurian"


static func create_by_commander_id(commander_id: StringName) -> RunCharacter:
	if commander_id != COMMANDER_ID:
		return null
	var root_script := load("res://Scripts/Run/lizardman_wave_a_catalog.gd") as Script
	var root: RunCharacter = root_script.create_by_class_id(ROOT_CLASS_ID)
	if not is_instance_valid(root):
		return null
	var skills: Array[CharacterSkill] = []
	for skill: CharacterSkill in root.get_skills():
		skills.append(skill.duplicate_skill())
	skills.append(_cartographer_of_venoms())
	var commander := RunCharacter.new(COMMANDER_ID, "Sszek Still-Mire", root.base_speed, root.max_hp, skills, root.power, root.defense, &"lizardman")
	commander.class_id = COMMANDER_ID
	return commander


static func get_presentation(commander_id: StringName) -> Dictionary:
	if commander_id != COMMANDER_ID:
		return {}
	return {
		&"commander_id": COMMANDER_ID,
		&"display_name": "Sszek Still-Mire",
		&"title": "Delta Strategist",
		&"root_class_id": ROOT_CLASS_ID,
		&"race_id": &"lizardman",
	}


static func _cartographer_of_venoms() -> CharacterSkill:
	return CharacterSkill.create(&"cartographer_of_venoms", "Cartographer of Venoms", CharacterSkill.Kind.PASSIVE, "Once per round, Sszek's first same-axis Poison reapplication spreads one stack to an adjacent enemy for two rounds.", "Adjacent enemy.", "Same-axis reapplication.", "Once per round.", -1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE)
