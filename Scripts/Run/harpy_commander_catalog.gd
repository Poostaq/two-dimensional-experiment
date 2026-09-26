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
	skills.append(_open_sky_command())
	var commander := RunCharacter.new(COMMANDER_ID, "Kyris Windscar", root.base_speed, root.max_hp, skills, root.power, root.defense, &"harpy")
	commander.class_id = COMMANDER_ID
	return commander


static func _open_sky_command() -> CharacterSkill:
	var source: RefCounted = BattleKeywordSource.create(COMMANDER_ID, &"open_sky_command", 4)
	var operation: RefCounted = BattleKeywordOperation.create(
		BattleKeywordOperation.Kind.ARM_POST_HIT_MOVE_ONE,
		COMMANDER_ID,
		0,
		1,
		source
	)
	var reaction: RefCounted = BattleReactionDefinition.create(
		&"open_sky_command",
		BattleReactionDefinition.Trigger.FORCED_MOVEMENT,
		BattleReactionDefinition.Frequency.ONCE_PER_ROUND,
		0,
		operation,
		false,
		&"",
		BattleReactionDefinition.TargetPolicy.LOWEST_SLOT_ALLY
	)
	return CharacterSkill.create(&"open_sky_command", "Open Sky Command", CharacterSkill.Kind.PASSIVE, "Once per round after Kyris causes hostile movement, the lowest-slot active ally may move 1 after its next direct hit this round.", "Lowest-slot active ally.", "Successful hostile movement caused by Kyris.", "Once per round.", -1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0, null, [], null, reaction)


static func get_presentation(commander_id: StringName) -> Dictionary:
	if commander_id != COMMANDER_ID:
		return {}
	return {&"commander_id": COMMANDER_ID, &"display_name": "Kyris Windscar", &"title": "Sky Matron", &"root_class_id": ROOT_CLASS_ID, &"race_id": &"harpy"}
