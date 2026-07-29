class_name BattleOutcome
extends RefCounted

enum Type {
	IN_PROGRESS,
	VICTORY,
	DEFEAT,
}


static func evaluate(units: Array[BattleUnitState]) -> Type:
	var has_player := false
	var has_enemy := false
	var has_active_player := false
	var has_active_enemy := false
	for unit: BattleUnitState in units:
		if not is_instance_valid(unit):
			continue
		match unit.side:
			BattleUnitState.Side.PLAYER:
				has_player = true
				has_active_player = has_active_player or unit.is_active()
			BattleUnitState.Side.ENEMY:
				has_enemy = true
				has_active_enemy = has_active_enemy or unit.is_active()
	if not has_player or not has_enemy:
		return Type.IN_PROGRESS
	if has_active_player == has_active_enemy:
		return Type.IN_PROGRESS
	return Type.VICTORY if has_active_player else Type.DEFEAT


static func get_display_text(outcome: Type) -> String:
	match outcome:
		Type.VICTORY:
			return "Victory"
		Type.DEFEAT:
			return "Defeat"
		_:
			return ""
