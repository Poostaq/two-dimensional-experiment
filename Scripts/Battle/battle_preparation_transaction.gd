class_name BattlePreparationTransaction
extends RefCounted

static var RECORD_SCRIPT: GDScript = load(
	"res://Scripts/Battle/battle_preparation_record.gd"
)

var _offered_record: RefCounted
var _offered_setup_key: String = ""
var _choice: int = 0
var _target_unit_id: StringName = &""
var _committed: bool = false


static func begin(record: RefCounted, identity: RefCounted) -> RefCounted:
	if (
		not is_instance_valid(record)
		or not record.call("is_valid")
		or int(record.get("state")) != RECORD_SCRIPT.State.OFFERED
		or not is_instance_valid(identity)
		or String(identity.get("canonical_key")).is_empty()
		or String(record.get("setup_key")) != String(identity.get("canonical_key"))
	):
		return null
	var script: GDScript = load("res://Scripts/Battle/battle_preparation_transaction.gd")
	var transaction: RefCounted = script.new()
	transaction._offered_record = record
	transaction._offered_setup_key = String(identity.get("canonical_key"))
	return transaction


func cancel() -> bool:
	return false


func select_choice(value: int) -> bool:
	if _committed or value not in [
		RECORD_SCRIPT.Choice.FRONTLINE_BRIEFING,
		RECORD_SCRIPT.Choice.SPARE_PLATING,
	]:
		return false
	_choice = value
	_target_unit_id = &""
	return true


func select_target(target_unit_id: StringName, units: Array[BattleUnitState]) -> bool:
	if _committed or _choice != RECORD_SCRIPT.Choice.FRONTLINE_BRIEFING:
		return false
	var target := _find_unit(target_unit_id, units)
	if (
		not is_instance_valid(target)
		or target.side != BattleUnitState.Side.ENEMY
		or not target.is_active()
	):
		return false
	_target_unit_id = target_unit_id
	return true


func commit(current_identity: RefCounted, units: Array[BattleUnitState]) -> Dictionary:
	if _committed:
		return _failure(&"already_committed")
	if (
		not is_instance_valid(current_identity)
		or String(current_identity.get("canonical_key")) != _offered_setup_key
	):
		return _failure(&"stale_setup")
	var resolved_ids: Array[StringName] = []
	if _choice == RECORD_SCRIPT.Choice.FRONTLINE_BRIEFING:
		var target := _find_unit(_target_unit_id, units)
		if (
			not is_instance_valid(target)
			or target.side != BattleUnitState.Side.ENEMY
			or not target.is_active()
		):
			return _failure(&"stale_target")
		resolved_ids.append(target.unit_id)
	elif _choice == RECORD_SCRIPT.Choice.SPARE_PLATING:
		for unit: BattleUnitState in units:
			if (
				is_instance_valid(unit)
				and unit.side == BattleUnitState.Side.PLAYER
				and unit.is_active()
				and BattleFormationRules.is_front_slot(unit.slot_index)
			):
				resolved_ids.append(unit.unit_id)
		if resolved_ids.is_empty():
			return _failure(&"no_frontline_allies")
	else:
		return _failure(&"choice_required")
	var committed_record: RefCounted = RECORD_SCRIPT.committed(
		_offered_record.get("preparation_id"),
		_offered_record.get("encounter_coord"),
		_offered_record.get("encounter_type"),
		_offered_setup_key,
		_choice,
		_target_unit_id
	)
	if not is_instance_valid(committed_record):
		return _failure(&"invalid_commit")
	_committed = true
	return {
		"ok": true,
		"record": committed_record,
		"resolved_unit_ids": resolved_ids,
		"reason": &"",
	}


static func _find_unit(
	target_unit_id: StringName,
	units: Array[BattleUnitState]
) -> BattleUnitState:
	if target_unit_id.is_empty():
		return null
	for unit: BattleUnitState in units:
		if is_instance_valid(unit) and unit.unit_id == target_unit_id:
			return unit
	return null


static func _failure(reason: StringName) -> Dictionary:
	return {
		"ok": false,
		"record": null,
		"resolved_unit_ids": [],
		"reason": reason,
	}
