class_name BattleUnitPresentation
extends RefCounted

# Authored skill identity survives recruitment IDs and display-name changes.
const ROLE_SKILLS: Array[StringName] = [
	&"banner_holder", &"shield_tap", &"quick_mark", &"tripline_tag",
	&"spot_buyer", &"quick_nick", &"point_and_yell",
]
const ROLE_NAMES: Array[String] = [
	"Commander", "Bruiser", "Skirmisher", "Controller", "Support", "Striker", "Support",
]


static func role_for(unit: BattleUnitState) -> String:
	for index: int in range(ROLE_SKILLS.size()):
		for skill: CharacterSkill in unit.skills:
			if skill.skill_id == ROLE_SKILLS[index]:
				return ROLE_NAMES[index]
	return "Combatant"


static func figure_for(unit: BattleUnitState) -> StringName:
	return StringName(role_for(unit).to_lower())


static func statuses_for(unit: BattleUnitState, round_number: int) -> Array[Dictionary]:
	var statuses: Array[Dictionary] = []
	if not unit.is_active():
		return statuses
	if unit.get_armor() > 0:
		statuses.append(_status(&"armor", "Armor", str(unit.get_armor()), "Armor absorbs physical damage."))
	if unit.has_advantage(round_number):
		statuses.append(_status(&"advantage", "Advantage", "", "Marked for Advantage interactions."))
	if unit.is_snared(round_number):
		statuses.append(_status(&"snared", "Snared", "", "Snared until the end of the round."))
	var bleed_count: int = unit.get_bleed_snapshot().size()
	if bleed_count > 0:
		statuses.append(_status(&"bleed", "Bleed", str(bleed_count), "Active Bleed sources, not damage."))
	if not unit.get_speed_modifier_snapshot().is_empty():
		var delta: int = unit.get_effective_speed() - unit.get_base_speed()
		var value: String = "%+d" % delta if delta != 0 else "±0"
		statuses.append(_status(&"speed", "Speed", value, "Temporary Speed change."))
	return statuses


static func _status(id: StringName, label: String, value: String, description: String) -> Dictionary:
	return {"id": id, "label": label, "value": value, "description": description}
