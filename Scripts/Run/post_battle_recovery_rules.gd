class_name PostBattleRecoveryRules
extends RefCounted


static func calculate_next_hp(character_id: StringName, final_hp: int, max_hp: int) -> int:
	if character_id.is_empty() or max_hp <= 0 or final_hp < 0 or final_hp > max_hp:
		return -1
	if final_hp > 0:
		return max_hp
	return (max_hp + 1) / 2
