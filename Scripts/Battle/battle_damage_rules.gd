class_name BattleDamageRules
extends RefCounted


static func physical_damage(power: int, multiplier: float, defense: int) -> int:
	if power < 1 or multiplier <= 0.0 or defense < 0:
		return -1
	return max(1, ceili(float(power) * multiplier) - defense)
