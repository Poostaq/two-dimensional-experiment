class_name ElfCommanderCatalog
extends RefCounted

const COMMANDER_ID: StringName = &"lady_saelith_moonfall"
const ROOT_CLASS_ID: StringName = &"elf_highborn_mystic"


static func create_by_commander_id(commander_id: StringName) -> RunCharacter:
	if commander_id != COMMANDER_ID:
		return null
	var root_script := load("res://Scripts/Run/elf_wave_b_catalog.gd") as Script
	var root: RunCharacter = root_script.create_by_class_id(ROOT_CLASS_ID)
	if not is_instance_valid(root):
		return null
	var skills: Array[CharacterSkill] = []
	for skill: CharacterSkill in root.get_skills():
		skills.append(skill.duplicate_skill())
	skills.append(_moonfall_edict())
	var commander := RunCharacter.new(COMMANDER_ID, "Lady Saelith Moonfall", root.base_speed, root.max_hp, skills, root.power, root.defense, &"elf")
	commander.class_id = COMMANDER_ID
	commander.root_class_id = ROOT_CLASS_ID
	return commander


static func get_presentation(commander_id: StringName) -> Dictionary:
	if commander_id != COMMANDER_ID:
		return {}
	return {&"commander_id": COMMANDER_ID, &"display_name": "Lady Saelith Moonfall", &"title": "Moonfall Regent", &"root_class_id": ROOT_CLASS_ID, &"race_id": &"elf"}


static func _moonfall_edict() -> CharacterSkill:
	var source: RefCounted = BattleKeywordSource.create(COMMANDER_ID, &"moonfall_edict", 4)
	var operation: RefCounted = BattleKeywordOperation.create(BattleKeywordOperation.Kind.APPLY_ADVANTAGE_AND_SNARED_OWNER_SPEED, COMMANDER_ID, 1, 1, source)
	var reaction: RefCounted = BattleReactionDefinition.create(&"moonfall_edict", BattleReactionDefinition.Trigger.ACTION_START, BattleReactionDefinition.Frequency.ONCE_PER_ROUND, 0, operation, false, &"", BattleReactionDefinition.TargetPolicy.CLOSEST_OPPONENT)
	return CharacterSkill.create(&"moonfall_edict", "Moonfall Edict", CharacterSkill.Kind.PASSIVE, "Once per round at action start, apply Advantage to the closest enemy; if Snared, Saelith gains 1 Speed this round.", "Closest active enemy.", "Requires an active enemy.", "Once per round.", -1, -1, -1, CharacterSkill.Requirement.NONE, -1, -1, 0, CharacterSkill.EffectDuration.NONE, CharacterSkill.CooldownMode.NONE, 0, 0, null, [], null, reaction)
