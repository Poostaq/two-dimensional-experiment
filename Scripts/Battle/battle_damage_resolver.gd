class_name BattleDamageResolver
extends RefCounted

const DEBUG_DAMAGE := 7


static func apply_damage(
	attacker: BattleUnitState,
	receiver: BattleUnitState,
	amount: int
) -> BattleDamageResult:
	if (
		not is_instance_valid(attacker)
		or not is_instance_valid(receiver)
		or amount <= 0
		or not attacker.is_active()
		or not receiver.is_active()
		or attacker.side == receiver.side
	):
		return null
	var hp_before: int = receiver.current_hp
	var applied_damage: int = mini(amount, hp_before)
	receiver.current_hp = maxi(0, hp_before - amount)
	return BattleDamageResult.new(
		attacker.unit_id,
		receiver.unit_id,
		amount,
		applied_damage,
		receiver.current_hp,
		hp_before > 0 and receiver.current_hp == 0
	)
