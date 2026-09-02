class_name GoblinCommanderCatalog
extends RefCounted

const BRAKKA_ID: StringName = &"brakka_rustbanner"
const BANNER_HOLDER_ID: StringName = &"banner_holder"
const SCRAPSHIELD_BRUISER_ID: StringName = &"scrapshield_bruiser"
const INHERITED_SKILL_IDS: Array[StringName] = [
	&"shield_tap",
	&"pack_brace",
	&"banner_nudge",
]


static func get_commander_ids() -> Array[StringName]:
	return [BRAKKA_ID]


static func create_by_commander_id(commander_id: StringName) -> RunCharacter:
	if commander_id != BRAKKA_ID:
		return null
	var root: RunCharacter = GoblinWaveACatalog.create_by_class_id(SCRAPSHIELD_BRUISER_ID)
	if not is_instance_valid(root):
		return null
	var root_skills: Array[CharacterSkill] = root.get_skills()
	if not _has_authoritative_root_loadout(root_skills):
		return null
	var skills: Array[CharacterSkill] = []
	for skill: CharacterSkill in root_skills:
		skills.append(skill.duplicate_skill())
	var banner_holder: CharacterSkill = _banner_holder()
	if not is_instance_valid(banner_holder):
		return null
	skills.append(banner_holder)
	return RunCharacter.new(
		BRAKKA_ID,
		"Brakka Rustbanner",
		root.base_speed,
		root.max_hp,
		skills,
		root.power,
		root.defense,
		&"goblin"
	)


static func get_presentation(commander_id: StringName) -> Dictionary:
	var commander: RunCharacter = create_by_commander_id(commander_id)
	if not is_instance_valid(commander):
		return {}
	return {
		"commander_id": commander.character_id,
		"display_name": commander.display_name,
		"title": "Packmarshal · Goblin Commander",
		"summary": "Front-line coalition leader",
		"root_class_name": "Scrapshield Bruiser",
		"portrait_label": "Brakka portrait placeholder",
		"skills": commander.get_skills(),
	}


static func _has_authoritative_root_loadout(skills: Array[CharacterSkill]) -> bool:
	if skills.size() != INHERITED_SKILL_IDS.size():
		return false
	for index: int in skills.size():
		if (
			not is_instance_valid(skills[index])
			or skills[index].skill_id != INHERITED_SKILL_IDS[index]
		):
			return false
	return true


static func _banner_holder() -> CharacterSkill:
	var source: RefCounted = BattleKeywordSource.create(BRAKKA_ID, BANNER_HOLDER_ID, 4)
	var template: RefCounted = BattleKeywordOperation.create(
		BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
		BRAKKA_ID,
		0,
		1,
		source
	)
	var reaction: RefCounted = BattleReactionDefinition.create(
		BANNER_HOLDER_ID,
		BattleReactionDefinition.Trigger.ACTION_START,
		BattleReactionDefinition.Frequency.ONCE_PER_ROUND,
		0,
		template,
		false
	)
	if not is_instance_valid(reaction):
		return null
	return CharacterSkill.create(
		BANNER_HOLDER_ID,
		"Banner Holder",
		CharacterSkill.Kind.PASSIVE,
		"Once per round at the start of your action, apply Advantage to the closest active enemy.",
		"Closest active enemy.",
		"Brakka must be active and starting an eligible action.",
		"Once per round.",
		-1,
		-1,
		-1,
		CharacterSkill.Requirement.NONE,
		-1,
		-1,
		0,
		CharacterSkill.EffectDuration.NONE,
		CharacterSkill.CooldownMode.NONE,
		0,
		0,
		null,
		[],
		null,
		reaction
	)
