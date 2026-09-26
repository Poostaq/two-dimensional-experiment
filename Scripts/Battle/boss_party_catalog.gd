class_name BossPartyCatalog
extends RefCounted


static func create_by_enemy_clan_id(enemy_clan_id: StringName) -> Array[RunCharacter]:
	match enemy_clan_id:
		&"human":
			return _create_party([&"marshal_elian_voss", &"human_iron_sentinel", &"human_ranger", &"human_field_medic"])
		&"elf", &"dwarf":
			return []
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
