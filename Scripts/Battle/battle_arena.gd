class_name BattleArena
extends Control

signal exit_requested

const SIDE_SLOT_COUNT := 6
const NEUTRAL_SLOT_COLOR := Color.WHITE
const CURRENT_SLOT_COLOR := Color(1.0, 0.82, 0.32, 1.0)

@onready var _encounter_type_label: Label = %EncounterTypeLabel
@onready var _player_formation: GridContainer = %PlayerFormation
@onready var _enemy_formation: GridContainer = %EnemyFormation
@onready var _round_label: Label = %RoundLabel
@onready var _current_unit_label: Label = %CurrentUnitLabel
@onready var _advance_debug_button: Button = %AdvanceTurnDebugButton
@onready var _exit_debug_button: Button = %ExitBattleDebugButton

var encounter_coordinate: Vector2i = Vector2i.ZERO
var encounter_type: String = ""
var round_number: int = 1

var _units: Array[BattleUnitState] = []
var _turn_queue: Array[BattleUnitState] = []
var _current_turn_index: int = 0


func _ready() -> void:
	var exit_callable := Callable(self, "_on_exit_debug_pressed")
	if not _exit_debug_button.pressed.is_connected(exit_callable):
		_exit_debug_button.pressed.connect(exit_callable)
	var advance_callable := Callable(self, "_on_advance_debug_pressed")
	if not _advance_debug_button.pressed.is_connected(advance_callable):
		_advance_debug_button.pressed.connect(advance_callable)
	_assign_slot_metadata(_player_formation, "player")
	_assign_slot_metadata(_enemy_formation, "enemy")
	_refresh_context()
	configure_units(_create_debug_units())


func configure(coordinate: Vector2i, type: String) -> void:
	if type != HexMapModel.ENCOUNTER_COMBAT and type != HexMapModel.ENCOUNTER_BOSS:
		return
	encounter_coordinate = coordinate
	encounter_type = type
	if is_node_ready():
		_refresh_context()


func configure_units(units: Array[BattleUnitState]) -> void:
	_units = units.duplicate()
	_turn_queue = BattleTurnQueue.build(_units)
	_current_turn_index = 0
	round_number = 1
	if is_node_ready():
		_refresh_turn_ui()


func get_turn_queue() -> Array[BattleUnitState]:
	return _turn_queue.duplicate()


func get_current_unit() -> BattleUnitState:
	if _turn_queue.is_empty() or _current_turn_index < 0 or _current_turn_index >= _turn_queue.size():
		return null
	return _turn_queue[_current_turn_index]


func advance_turn() -> void:
	if _turn_queue.is_empty():
		return
	_current_turn_index += 1
	if _current_turn_index >= _turn_queue.size():
		round_number += 1
		_turn_queue = BattleTurnQueue.build(_units)
		_current_turn_index = 0
	_refresh_turn_ui()


func get_player_slots() -> Array[Control]:
	return _get_control_children(_player_formation)


func get_enemy_slots() -> Array[Control]:
	return _get_control_children(_enemy_formation)


func _create_debug_units() -> Array[BattleUnitState]:
	return [
		BattleUnitState.new(&"player_0", "Player Front 1", BattleUnitState.Side.PLAYER, 0, 8),
		BattleUnitState.new(&"player_1", "Player Front 2", BattleUnitState.Side.PLAYER, 1, 6),
		BattleUnitState.new(&"player_2", "Player Front 3", BattleUnitState.Side.PLAYER, 2, 6),
		BattleUnitState.new(&"player_3", "Player Back 1", BattleUnitState.Side.PLAYER, 3, 4),
		BattleUnitState.new(&"player_4", "Player Back 2", BattleUnitState.Side.PLAYER, 4, 9),
		BattleUnitState.new(&"player_5", "Player Back 3", BattleUnitState.Side.PLAYER, 5, 2),
		BattleUnitState.new(&"enemy_0", "Enemy Front 1", BattleUnitState.Side.ENEMY, 0, 8),
		BattleUnitState.new(&"enemy_1", "Enemy Front 2", BattleUnitState.Side.ENEMY, 1, 7),
		BattleUnitState.new(&"enemy_2", "Enemy Front 3", BattleUnitState.Side.ENEMY, 2, 6),
		BattleUnitState.new(&"enemy_3", "Enemy Back 1", BattleUnitState.Side.ENEMY, 3, 4),
		BattleUnitState.new(&"enemy_4", "Enemy Back 2", BattleUnitState.Side.ENEMY, 4, 9),
		BattleUnitState.new(&"enemy_5", "Enemy Back 3", BattleUnitState.Side.ENEMY, 5, 2),
	]


func _get_control_children(formation: GridContainer) -> Array[Control]:
	var slots: Array[Control] = []
	for child: Node in formation.get_children():
		if child is Control:
			slots.append(child as Control)
	return slots


func _assign_slot_metadata(formation: GridContainer, side: String) -> void:
	for slot: Control in _get_control_children(formation):
		var slot_index := int(String(slot.name).trim_prefix("Slot"))
		slot.set_meta("side", side)
		slot.set_meta("slot_index", slot_index)
		slot.set_meta("is_current_unit", false)


func _refresh_context() -> void:
	if encounter_type.is_empty():
		_encounter_type_label.text = "Battle"
		return
	_encounter_type_label.text = "%s Battle" % encounter_type.capitalize()


func _refresh_turn_ui() -> void:
	_round_label.text = "Round %d" % round_number
	_render_units()
	var current_unit := get_current_unit()
	if not is_instance_valid(current_unit):
		_current_unit_label.text = "No active units"
		_advance_debug_button.disabled = true
		return
	_current_unit_label.text = "%s | Speed %d" % [current_unit.display_name, current_unit.speed]
	_advance_debug_button.disabled = false
	var current_slot := _get_slot_for_unit(current_unit)
	if is_instance_valid(current_slot):
		current_slot.self_modulate = CURRENT_SLOT_COLOR
		current_slot.set_meta("is_current_unit", true)


func _render_units() -> void:
	for slot: Control in get_player_slots() + get_enemy_slots():
		slot.self_modulate = NEUTRAL_SLOT_COLOR
		slot.set_meta("is_current_unit", false)
		var name_label := slot.get_node("UnitInfo/UnitNameLabel") as Label
		var speed_label := slot.get_node("UnitInfo/SpeedLabel") as Label
		name_label.text = "Unoccupied"
		speed_label.text = "Speed —"
	for unit: BattleUnitState in _units:
		if not is_instance_valid(unit):
			continue
		var slot := _get_slot_for_unit(unit)
		if not is_instance_valid(slot):
			continue
		var name_label := slot.get_node("UnitInfo/UnitNameLabel") as Label
		var speed_label := slot.get_node("UnitInfo/SpeedLabel") as Label
		name_label.text = unit.display_name
		speed_label.text = "Speed %d" % unit.speed


func _get_slot_for_unit(unit: BattleUnitState) -> Control:
	if not is_instance_valid(unit) or unit.slot_index < 0 or unit.slot_index >= SIDE_SLOT_COUNT:
		return null
	var slots: Array[Control] = get_player_slots() if unit.side == BattleUnitState.Side.PLAYER else get_enemy_slots()
	for slot: Control in slots:
		if int(slot.get_meta("slot_index", -1)) == unit.slot_index:
			return slot
	return null


func _on_advance_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	advance_turn()


func _on_exit_debug_pressed() -> void:
	get_viewport().set_input_as_handled()
	call_deferred("_emit_exit_requested")


func _emit_exit_requested() -> void:
	exit_requested.emit()
