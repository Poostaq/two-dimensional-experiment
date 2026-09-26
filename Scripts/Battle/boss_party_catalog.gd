class_name BossPartyCatalog
extends RefCounted


static func create_by_enemy_clan_id(enemy_clan_id: StringName) -> Array[RunCharacter]:
	match enemy_clan_id:
		&"human":
			return _create_party([&"marshal_elian_voss", &"human_iron_sentinel", &"human_ranger", &"human_field_medic"])
		&"elf":
			return _create_party([&"lady_saelith_moonfall", &"elf_warden_of_the_grove", &"elf_star_archer", &"elf_crescent_duelist"])
		&"dwarf":
			return _create_party([&"thane_brokk_stonevein", &"dwarf_rune_sentinel", &"dwarf_siege_smith", &"dwarf_hearthkeeper"])
		_:
			return []


static func _create_party(class_ids: Array[StringName]) -> Array[RunCharacter]:
	var party: Array[RunCharacter] = []
	for class_id: StringName in class_ids:
		var member: RunCharacter = RunCharacterCatalog.create_by_class_id(class_id)
		if not is_instance_valid(member):
			return []
		party.append(member)
	return party
