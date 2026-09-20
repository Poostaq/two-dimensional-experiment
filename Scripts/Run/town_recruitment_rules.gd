class_name TownRecruitmentRules
extends RefCounted


static func eligible_class_ids(clan_id: StringName, roster: RunRoster) -> Array[StringName]:
	var result: Array[StringName] = []
	if not is_instance_valid(roster):
		return result
	var occupied: Dictionary[StringName, bool] = {}
	for character: RunCharacter in roster.get_characters():
		occupied[character.class_id] = true
	for class_id: StringName in RunCharacterCatalog.get_recruitable_class_ids(clan_id):
		if not occupied.has(class_id):
			result.append(class_id)
	return result


static func purchase_error(
	clan_id: StringName,
	roster: RunRoster,
	class_id: StringName,
	gold: int,
	town_available: bool
) -> StringName:
	if not town_available:
		return &"town_unavailable"
	if not is_instance_valid(roster):
		return &"invalid_roster"
	if not RunCharacterCatalog.get_recruitable_class_ids(clan_id).has(class_id):
		return &"class_not_recruitable"
	if not eligible_class_ids(clan_id, roster).has(class_id):
		return &"class_already_present"
	if gold < RunEconomyRules.RECRUITMENT_COST:
		return &"insufficient_gold"
	return &""
