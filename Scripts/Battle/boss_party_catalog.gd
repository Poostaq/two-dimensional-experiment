class_name BossPartyCatalog
extends RefCounted


static func create_by_enemy_clan_id(enemy_clan_id: StringName) -> Array[RunCharacter]:
	match enemy_clan_id:
		&"human", &"elf", &"dwarf":
			return []
		_:
			return []
