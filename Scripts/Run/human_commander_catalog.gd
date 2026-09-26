extends RefCounted

const COMMANDER_ID: StringName = &"marshal_elian_voss"
const ROOT_CLASS_ID: StringName = &"human_vanguard"


static func create_by_commander_id(commander_id: StringName) -> RunCharacter:
	if commander_id != COMMANDER_ID:
		return null
	var root_script := load("res://Scripts/Run/human_wave_a_catalog.gd") as Script
	var root: RunCharacter = root_script.create_by_class_id(ROOT_CLASS_ID)
	if not is_instance_valid(root):
		return null
	var skills: Array[CharacterSkill] = []
	for skill: CharacterSkill in root.get_skills():
		skills.append(skill.duplicate_skill())
	skills.append(_marshal_the_line())
	var commander := RunCharacter.new(COMMANDER_ID, "Marshal Elian Voss", root.base_speed, root.max_hp, skills, root.power, root.defense, &"human")
	commander.class_id = COMMANDER_ID
	return commander


static func get_presentation(commander_id: StringName) -> Dictionary:
	if commander_id != COMMANDER_ID:
		return {}
	return {&"commander_id": COMMANDER_ID, &"display_name": "Marshal Elian Voss", &"title": "Marshal of the Line", &"root_class_id": ROOT_CLASS_ID, &"race_id": &"human"}


static func _marshal_the_line() -> CharacterSkill:
	var source: RefCounted = BattleKeywordSource.create(COMMANDER_ID, &"marshal_the_line", 4)
	var operation: RefCounted = BattleKeywordOperation.create(BattleKeywordOperation.Kind.ADD_ARMOR, COMMANDER_ID, 2, 0, source)
	var reaction: RefCounted = BattleReactionDefinition.create(&"marshal_the_line", BattleReactionDefinition.Trigger.ACTION_START, BattleReactionDefinition.Frequency.ONCE_PER_ROUND, 0, operation, false, &"", BattleReactionDefinition.TargetPolicy.OWNER_AND_ADJACENT_ALLY)
	return CharacterSkill.create(&"marshal_the_line", "Marshal the Line", CharacterSkill.Kind.PASSIVE, "Once per round at action start, Elian and the lowest-slot adjacent ally gain 2 Armor.", "Elian and adjacent ally.", "Requires an adjacent ally.", "Once per round.", -1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0, null, [], null, reaction)
