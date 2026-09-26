extends RefCounted

const GORUK_ID: StringName = &"goruk_ironline"
const ROOT_CLASS_ID: StringName = &"orc_iron_tusk_vanguard"


static func create_by_commander_id(commander_id: StringName) -> RunCharacter:
	if commander_id != GORUK_ID:
		return null
	var root_script := load("res://Scripts/Run/orc_wave_a_catalog.gd") as Script
	var root: RunCharacter = root_script.create_by_class_id(ROOT_CLASS_ID)
	if not is_instance_valid(root):
		return null
	var skills: Array[CharacterSkill] = []
	for skill: CharacterSkill in root.get_skills():
		skills.append(skill.duplicate_skill())
	var decree := _iron_decree()
	if not is_instance_valid(decree):
		return null
	skills.append(decree)
	var commander := RunCharacter.new(GORUK_ID, "Goruk Ironline", root.base_speed, root.max_hp, skills, root.power, root.defense, &"orc")
	commander.class_id = GORUK_ID
	commander.root_class_id = ROOT_CLASS_ID
	return commander


static func _iron_decree() -> CharacterSkill:
	var source: RefCounted = BattleKeywordSource.create(GORUK_ID, &"iron_decree", 4)
	var operation: RefCounted = BattleKeywordOperation.create(BattleKeywordOperation.Kind.ADD_ARMOR, GORUK_ID, 2, 0, source)
	var reaction: RefCounted = BattleReactionDefinition.create(&"iron_decree", BattleReactionDefinition.Trigger.ACTION_END, BattleReactionDefinition.Frequency.ONCE_PER_ROUND, 0, operation, false, &"", BattleReactionDefinition.TargetPolicy.OWNER_AND_ADJACENT_ALLY)
	if not is_instance_valid(reaction):
		return null
	return CharacterSkill.create(&"iron_decree", "Iron Decree", CharacterSkill.Kind.PASSIVE, "Once per round after Goruk establishes contact, Goruk and one neighboring ally gain 2 Armor.", "Goruk and a deterministic neighboring ally.", "Goruk must end an action neighboring an enemy.", "Once per round.", -1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0, null, [], null, reaction)
