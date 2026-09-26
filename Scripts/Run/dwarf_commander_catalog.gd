class_name DwarfCommanderCatalog
extends RefCounted

const COMMANDER_ID: StringName = &"thane_brokk_stonevein"
const ROOT_CLASS_ID: StringName = &"dwarf_forgewarden"


static func create_by_commander_id(commander_id: StringName) -> RunCharacter:
	if commander_id != COMMANDER_ID:
		return null
	var root_script := load("res://Scripts/Run/dwarf_wave_a_catalog.gd") as Script
	var root: RunCharacter = root_script.create_by_class_id(ROOT_CLASS_ID)
	if not is_instance_valid(root):
		return null
	var skills: Array[CharacterSkill] = []
	for skill: CharacterSkill in root.get_skills():
		skills.append(skill.duplicate_skill())
	skills.append(_stonevein_bulwark())
	var commander := RunCharacter.new(COMMANDER_ID, "Thane Brokk Stonevein", root.base_speed, root.max_hp, skills, root.power, root.defense, &"dwarf")
	commander.class_id = COMMANDER_ID
	commander.root_class_id = ROOT_CLASS_ID
	return commander


static func get_presentation(commander_id: StringName) -> Dictionary:
	if commander_id != COMMANDER_ID:
		return {}
	return {&"commander_id": COMMANDER_ID, &"display_name": "Thane Brokk Stonevein", &"title": "Stonevein Thane", &"root_class_id": ROOT_CLASS_ID, &"race_id": &"dwarf"}


static func _stonevein_bulwark() -> CharacterSkill:
	var source: RefCounted = BattleKeywordSource.create(COMMANDER_ID, &"stonevein_bulwark", 4)
	var operation: RefCounted = BattleKeywordOperation.create(BattleKeywordOperation.Kind.ADD_ARMOR, COMMANDER_ID, 2, 0, source)
	var reaction: RefCounted = BattleReactionDefinition.create(&"stonevein_bulwark", BattleReactionDefinition.Trigger.ACTION_START, BattleReactionDefinition.Frequency.ONCE_PER_ROUND, 0, operation, false, &"", BattleReactionDefinition.TargetPolicy.OWNER_AND_ALL_ADJACENT_ALLIES)
	return CharacterSkill.create(&"stonevein_bulwark", "Stonevein Bulwark", CharacterSkill.Kind.PASSIVE, "Once per round at action start, Brokk and every active adjacent ally gain 2 Armor.", "Brokk and adjacent allies.", "Requires an active adjacent ally.", "Once per round.", -1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0, null, [], null, reaction)
