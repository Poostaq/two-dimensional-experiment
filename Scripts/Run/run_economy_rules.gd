class_name RunEconomyRules
extends RefCounted

const STARTING_GOLD: int = 100
const GOLD_PER_DEFEATED_ENEMY: int = 50
const RECRUITMENT_COST: int = 500

static func victory_gold(outcome: BattleOutcome.Type, enemy_ids: Array[StringName]) -> int:
	if outcome != BattleOutcome.Type.VICTORY:
		return 0
	var distinct: Dictionary = {}
	for id: StringName in enemy_ids:
		distinct[id] = true
	return distinct.size() * GOLD_PER_DEFEATED_ENEMY
