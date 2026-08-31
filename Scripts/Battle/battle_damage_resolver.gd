class_name BattleDamageResolver
extends RefCounted

const DEBUG_DAMAGE := 7


static func apply_damage(
	attacker: BattleUnitState,
	receiver: BattleUnitState,
	amount: int
) -> BattleDamageResult:
	return apply_direct_damage(attacker, receiver, amount)


static func apply_direct_damage(
	attacker: BattleUnitState,
	receiver: BattleUnitState,
	amount: int
) -> BattleDamageResult:
	if not _can_apply_damage(attacker, receiver, amount):
		return null
	var hp_before: int = receiver.current_hp
	var armor_prevented: int = receiver.spend_armor(amount)
	var hp_damage: int = max(0, amount - armor_prevented)
	var applied_damage: int = min(hp_damage, hp_before)
	receiver.current_hp = max(0, hp_before - hp_damage)
	return BattleDamageResult.new(
		attacker.unit_id,
		receiver.unit_id,
		amount,
		applied_damage,
		receiver.current_hp,
		hp_before > 0 and receiver.current_hp == 0,
		armor_prevented,
		true,
		false
	)


static func apply_status_damage(
	attacker: BattleUnitState,
	receiver: BattleUnitState,
	amount: int
) -> BattleDamageResult:
	if not _can_apply_damage(attacker, receiver, amount):
		return null
	var hp_before: int = receiver.current_hp
	var applied_damage: int = min(amount, hp_before)
	receiver.current_hp = max(0, hp_before - amount)
	return BattleDamageResult.new(
		attacker.unit_id,
		receiver.unit_id,
		amount,
		applied_damage,
		receiver.current_hp,
		hp_before > 0 and receiver.current_hp == 0,
		0,
		false,
		true
	)


static func _can_apply_damage(attacker: BattleUnitState, receiver: BattleUnitState, amount: int) -> bool:
	return (
		is_instance_valid(attacker)
		and is_instance_valid(receiver)
		and amount > 0
		and attacker.is_active()
		and receiver.is_active()
		and attacker.side != receiver.side
	)
