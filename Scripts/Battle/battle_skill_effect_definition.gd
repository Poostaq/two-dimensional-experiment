class_name BattleSkillEffectDefinition
extends RefCounted

enum Kind {
	DAMAGE,
	KEYWORD,
	SPEED,
	OPTIONAL_SELF_MOVE,
	HISTORY_SCALED_DAMAGE,
	CONDITIONAL_ARMOR,
	FORCED_TARGET_MOVE,
	POISON_SCALED_DAMAGE,
	ARMOR_SPEND_DAMAGE,
	POISON_TRANSFER,
	CONDITIONAL_LEECH,
	CAPPED_SELF_DAMAGE,
}

enum BonusCondition {
	NONE,
	MOVED_THIS_ROUND,
	SNARED_AND_ADVANTAGE,
	LOST_THREE_ARMOR_THIS_ROUND,
	NO_ARMOR,
	LOST_ARMOR_THIS_ROUND,
	PRIMARY_ADVANTAGE,
}

enum TargetRole {
	ACTOR,
	PRIMARY,
	ALL_SELECTED,
	HISTORY_ALLY,
	SECONDARY,
	ALL_ACTIVE_ALLIES,
}

var kind: Kind:
	get:
		return _kind
var target_role: TargetRole:
	get:
		return _target_role
var power_percent: int:
	get:
		return _power_percent
var advantage_power_percent: int:
	get:
		return _advantage_power_percent
var keyword_kind: BattleKeywordOperation.Kind:
	get:
		return _keyword_kind
var magnitude: int:
	get:
		return _magnitude
var duration: int:
	get:
		return _duration
var arms_snared_follow_up: bool:
	get:
		return _arms_snared_follow_up
var history_increment: int:
	get:
		return _history_increment
var maximum_power_percent: int:
	get:
		return _maximum_power_percent
var conditional_magnitude: int:
	get:
		return _conditional_magnitude
var poison_axis: StringName:
	get:
		return _poison_axis
var source_only: bool:
	get:
		return _source_only
var source_skill_id: StringName:
	get:
		return _source_skill_id

var bonus_condition: BonusCondition:
	get:
		return _bonus_condition
var upgraded_power_percent: int:
	get:
		return _upgraded_power_percent
var consume_bonus_advantage: bool:
	get:
		return _consume_bonus_advantage
var ignore_armor: bool:
	get:
		return _ignore_armor
var armor_strip: int:
	get:
		return _armor_strip
var advantage_armor_strip: int:
	get:
		return _advantage_armor_strip

var _bonus_condition: BonusCondition = BonusCondition.NONE
var _upgraded_power_percent: int = 0
var _consume_bonus_advantage: bool = false
var _ignore_armor: bool = false
var _armor_strip: int = 0
var _advantage_armor_strip: int = 0

var _kind: Kind = Kind.DAMAGE
var _target_role: TargetRole = TargetRole.ACTOR
var _power_percent: int = 0
var _advantage_power_percent: int = 0
var _keyword_kind: BattleKeywordOperation.Kind = BattleKeywordOperation.Kind.ADD_ARMOR
var _magnitude: int = 0
var _duration: int = 0
var _arms_snared_follow_up: bool = false
var _history_increment: int = 0
var _maximum_power_percent: int = 0
var _conditional_magnitude: int = 0
var _poison_axis: StringName = &""
var _source_only: bool = false
var _source_skill_id: StringName = &""
var _is_valid: bool = false


func _init(
	effect_kind: int,
	role: int,
	percent: int = 0,
	advantage_percent: int = 0,
	operation_kind: int = BattleKeywordOperation.Kind.ADD_ARMOR,
	effect_magnitude: int = 0,
	effect_duration: int = 0,
	arm_snared_follow_up: bool = false,
	history_step: int = 0,
	maximum_percent: int = 0,
	conditional_amount: int = 0,
	poison_axis_value: StringName = &"",
	source_specific: bool = false,
	poison_source_skill_id: StringName = &""
) -> void:
	if not _is_valid_input(
		effect_kind,
		role,
		percent,
		advantage_percent,
		operation_kind,
		effect_magnitude,
		effect_duration,
		arm_snared_follow_up,
		history_step,
		maximum_percent,
		conditional_amount,
		poison_axis_value,
		source_specific,
		poison_source_skill_id
	):
		return
	_kind = effect_kind as Kind
	_target_role = role as TargetRole
	_power_percent = percent
	_advantage_power_percent = advantage_percent
	_keyword_kind = operation_kind as BattleKeywordOperation.Kind
	_magnitude = effect_magnitude
	_duration = effect_duration
	_arms_snared_follow_up = arm_snared_follow_up
	_history_increment = history_step
	_maximum_power_percent = maximum_percent
	_conditional_magnitude = conditional_amount
	_poison_axis = poison_axis_value
	_source_only = source_specific
	_source_skill_id = poison_source_skill_id
	_is_valid = true


static func damage(
	role: int,
	percent: int,
	advantage_percent: int = 0
) -> RefCounted:
	return _create(Kind.DAMAGE, role, percent, advantage_percent)


static func keyword(
	role: int,
	operation_kind: int,
	effect_magnitude: int = 0,
	effect_duration: int = 0,
	arm_snared_follow_up: bool = false
) -> RefCounted:
	return _create(
		Kind.KEYWORD,
		role,
		0,
		0,
		operation_kind,
		effect_magnitude,
		effect_duration,
		arm_snared_follow_up
	)


static func poison(
	role: int,
	axis: StringName,
	stacks: int = 1,
	duration_rounds: int = 3,
	poison_source_skill_id: StringName = &""
) -> RefCounted:
	return _create(
		Kind.KEYWORD,
		role,
		0,
		0,
		BattleKeywordOperation.Kind.APPLY_POISON,
		stacks,
		duration_rounds,
		false,
		0,
		0,
		0,
		axis,
		false,
		poison_source_skill_id
	)


static func stun(role: int) -> RefCounted:
	return _create(
		Kind.KEYWORD,
		role,
		0,
		0,
		BattleKeywordOperation.Kind.APPLY_STUN,
		0,
		1
	)


static func leech(role: int, percent: int) -> RefCounted:
	return _create(
		Kind.KEYWORD,
		role,
		0,
		0,
		BattleKeywordOperation.Kind.LEECH,
		percent
	)


static func next_hit_leech(role: int, percent: int, duration_rounds: int = 1) -> RefCounted:
	return keyword(
		role,
		BattleKeywordOperation.Kind.GRANT_NEXT_HIT_LEECH,
		percent,
		duration_rounds
	)


static func post_hit_move_one(role: int, duration_rounds: int = 1) -> RefCounted:
	return keyword(
		role,
		BattleKeywordOperation.Kind.ARM_POST_HIT_MOVE_ONE,
		0,
		duration_rounds
	)


static func conditional_leech(
	role: int,
	base_percent: int,
	advantage_percent: int
) -> RefCounted:
	return _create(
		Kind.CONDITIONAL_LEECH, role, 0, 0,
		BattleKeywordOperation.Kind.LEECH, base_percent, 0, false, 0, 0,
		advantage_percent
	)


static func capped_self_damage(percent_of_max_hp: int) -> RefCounted:
	return _create(
		Kind.CAPPED_SELF_DAMAGE, TargetRole.ACTOR, 0, 0,
		BattleKeywordOperation.Kind.CAPPED_SELF_DAMAGE, percent_of_max_hp
	)


static func speed(
	role: int,
	effect_magnitude: int,
	effect_duration: int
) -> RefCounted:
	return _create(
		Kind.SPEED,
		role,
		0,
		0,
		BattleKeywordOperation.Kind.ADD_ARMOR,
		effect_magnitude,
		effect_duration
	)


static func optional_self_move(maximum_distance: int = 3, minimum_distance: int = 0) -> RefCounted:
	return _create(
		Kind.OPTIONAL_SELF_MOVE, TargetRole.ACTOR, 0, 0,
		BattleKeywordOperation.Kind.ADD_ARMOR, maximum_distance, 0, false, 0, 0,
		minimum_distance
	)


static func self_move(maximum_distance: int, minimum_distance: int = 1) -> RefCounted:
	return optional_self_move(maximum_distance, minimum_distance)


static func forced_target_move(role: int, distance: int) -> RefCounted:
	return _create(
		Kind.FORCED_TARGET_MOVE,
		role,
		0,
		0,
		BattleKeywordOperation.Kind.ADD_ARMOR,
		distance
	)


static func poison_scaled_damage(
	role: int,
	base_percent: int,
	percent_per_stack: int,
	maximum_percent: int,
	axis: StringName = &"",
	source_specific: bool = false,
	advantage_bonus_percent: int = 0,
	poison_source_skill_id: StringName = &""
) -> RefCounted:
	return _create(
		Kind.POISON_SCALED_DAMAGE, role, base_percent, advantage_bonus_percent,
		BattleKeywordOperation.Kind.ADD_ARMOR, 0, 0, false, percent_per_stack,
		maximum_percent, 0, axis, source_specific, poison_source_skill_id
	)


static func armor_spend_damage(role: int, percent_per_armor: int, maximum_spend: int) -> RefCounted:
	return _create(
		Kind.ARMOR_SPEND_DAMAGE, role, percent_per_armor, 0,
		BattleKeywordOperation.Kind.ADD_ARMOR, maximum_spend
	)


static func poison_transfer() -> RefCounted:
	return _create(Kind.POISON_TRANSFER, TargetRole.ALL_SELECTED)


static func history_scaled_damage(
	role: int,
	base_percent: int,
	percent_per_distinct_attacker: int,
	maximum_percent: int
) -> RefCounted:
	return _create(Kind.HISTORY_SCALED_DAMAGE, role, base_percent, 0, BattleKeywordOperation.Kind.ADD_ARMOR, 0, 0, false, percent_per_distinct_attacker, maximum_percent)


static func conditional_armor(
	role: int,
	base_amount: int,
	upgraded_amount: int,
	bonus_condition_value: int = BonusCondition.NONE
) -> RefCounted:
	if bonus_condition_value < BonusCondition.NONE or bonus_condition_value > BonusCondition.PRIMARY_ADVANTAGE:
		return null
	var definition: RefCounted = _create(Kind.CONDITIONAL_ARMOR, role, 0, 0, BattleKeywordOperation.Kind.ADD_ARMOR, base_amount, 0, false, 0, 0, upgraded_amount)
	if is_instance_valid(definition):
		definition._bonus_condition = bonus_condition_value
	return definition


static func conditional_damage(
	role: int,
	base_percent: int,
	upgraded_percent: int,
	bonus_condition_value: int,
	consume_advantage: bool = false,
	bypass_armor: bool = false
) -> RefCounted:
	if bonus_condition_value < BonusCondition.MOVED_THIS_ROUND or bonus_condition_value > BonusCondition.PRIMARY_ADVANTAGE or upgraded_percent <= base_percent:
		return null
	if consume_advantage and bonus_condition_value != BonusCondition.SNARED_AND_ADVANTAGE:
		return null
	var definition: RefCounted = damage(role, base_percent)
	if not is_instance_valid(definition):
		return null
	definition._bonus_condition = bonus_condition_value
	definition._upgraded_power_percent = upgraded_percent
	definition._consume_bonus_advantage = consume_advantage
	definition._ignore_armor = bypass_armor
	return definition


static func armor_stripping_damage(
	role: int,
	percent: int,
	strip_amount: int,
	advantage_strip_amount: int = 0
) -> RefCounted:
	if strip_amount <= 0 or (advantage_strip_amount != 0 and advantage_strip_amount < strip_amount):
		return null
	var definition: RefCounted = damage(role, percent)
	if is_instance_valid(definition):
		definition._armor_strip = strip_amount
		definition._advantage_armor_strip = advantage_strip_amount
	return definition


static func ignoring_armor_damage(role: int, percent: int) -> RefCounted:
	var definition: RefCounted = damage(role, percent)
	if is_instance_valid(definition):
		definition._ignore_armor = true
	return definition


func is_valid() -> bool:
	return _is_valid


func duplicate_definition() -> RefCounted:
	if not is_valid():
		return null
	var copied: RefCounted = _create(
		_kind,
		_target_role,
		_power_percent,
		_advantage_power_percent,
		_keyword_kind,
		_magnitude,
		_duration,
		_arms_snared_follow_up,
		_history_increment,
		_maximum_power_percent,
		_conditional_magnitude,
		_poison_axis,
		_source_only,
		_source_skill_id
	)
	copied._bonus_condition = _bonus_condition
	copied._upgraded_power_percent = _upgraded_power_percent
	copied._consume_bonus_advantage = _consume_bonus_advantage
	copied._ignore_armor = _ignore_armor
	copied._armor_strip = _armor_strip
	copied._advantage_armor_strip = _advantage_armor_strip
	return copied


static func _create(
	effect_kind: int,
	role: int,
	percent: int = 0,
	advantage_percent: int = 0,
	operation_kind: int = BattleKeywordOperation.Kind.ADD_ARMOR,
	effect_magnitude: int = 0,
	effect_duration: int = 0,
	arm_snared_follow_up: bool = false,
	history_step: int = 0,
	maximum_percent: int = 0,
	conditional_amount: int = 0,
	poison_axis_value: StringName = &"",
	source_specific: bool = false,
	poison_source_skill_id: StringName = &""
) -> RefCounted:
	var definition: RefCounted = load("res://Scripts/Battle/battle_skill_effect_definition.gd").new(
		effect_kind,
		role,
		percent,
		advantage_percent,
		operation_kind,
		effect_magnitude,
		effect_duration,
		arm_snared_follow_up,
		history_step,
		maximum_percent,
		conditional_amount,
		poison_axis_value,
		source_specific,
		poison_source_skill_id
	)
	return definition if definition.is_valid() else null


static func _is_valid_input(
	effect_kind: int,
	role: int,
	percent: int,
	advantage_percent: int,
	operation_kind: int,
	effect_magnitude: int,
	effect_duration: int,
	arm_snared_follow_up: bool,
	history_step: int,
	maximum_percent: int,
	conditional_amount: int,
	poison_axis_value: StringName,
	source_specific: bool,
	poison_source_skill_id: StringName
) -> bool:
	if effect_kind not in [Kind.DAMAGE, Kind.KEYWORD, Kind.SPEED, Kind.OPTIONAL_SELF_MOVE, Kind.HISTORY_SCALED_DAMAGE, Kind.CONDITIONAL_ARMOR, Kind.FORCED_TARGET_MOVE, Kind.POISON_SCALED_DAMAGE, Kind.ARMOR_SPEND_DAMAGE, Kind.POISON_TRANSFER, Kind.CONDITIONAL_LEECH, Kind.CAPPED_SELF_DAMAGE]:
		return false
	if role not in [TargetRole.ACTOR, TargetRole.PRIMARY, TargetRole.ALL_SELECTED, TargetRole.HISTORY_ALLY, TargetRole.SECONDARY, TargetRole.ALL_ACTIVE_ALLIES]:
		return false
	if not poison_source_skill_id.is_empty() and not (
		effect_kind == Kind.POISON_SCALED_DAMAGE
		or effect_kind == Kind.KEYWORD and operation_kind == BattleKeywordOperation.Kind.APPLY_POISON
	):
		return false
	if source_specific and poison_source_skill_id.is_empty():
		return false
	if arm_snared_follow_up and (effect_kind != Kind.KEYWORD or operation_kind != BattleKeywordOperation.Kind.APPLY_SNARED):
		return false
	match effect_kind:
		Kind.DAMAGE:
			return (
				role in [TargetRole.PRIMARY, TargetRole.ALL_SELECTED, TargetRole.SECONDARY]
				and percent > 0
				and (advantage_percent == 0 or advantage_percent > percent)
				and effect_magnitude == 0
				and effect_duration == 0
			)
		Kind.KEYWORD:
			if advantage_percent != 0:
				return false
			if operation_kind not in [
				BattleKeywordOperation.Kind.ADD_ARMOR,
				BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
				BattleKeywordOperation.Kind.APPLY_SNARED,
				BattleKeywordOperation.Kind.APPLY_BLEED,
				BattleKeywordOperation.Kind.APPLY_POISON,
				BattleKeywordOperation.Kind.APPLY_STUN,
				BattleKeywordOperation.Kind.LEECH,
				BattleKeywordOperation.Kind.REDUCE_COOLDOWN,
				BattleKeywordOperation.Kind.GRANT_NEXT_HIT_LEECH,
				BattleKeywordOperation.Kind.ARM_POST_HIT_MOVE_ONE,
			]:
				return false
			if operation_kind == BattleKeywordOperation.Kind.ADD_ARMOR:
				return effect_magnitude > 0 and effect_duration == 0
			if operation_kind == BattleKeywordOperation.Kind.APPLY_POISON:
				return effect_magnitude > 0 and effect_duration > 0 and poison_axis_value in [&"power", &"defense", &"speed"]
			if operation_kind == BattleKeywordOperation.Kind.APPLY_STUN:
				return effect_magnitude == 0 and effect_duration == 1
			if operation_kind == BattleKeywordOperation.Kind.LEECH:
				return role == TargetRole.ACTOR and effect_magnitude > 0 and effect_magnitude <= 100 and effect_duration == 0
			if operation_kind == BattleKeywordOperation.Kind.GRANT_NEXT_HIT_LEECH:
				return effect_magnitude > 0 and effect_magnitude <= 100 and effect_duration > 0
			if operation_kind == BattleKeywordOperation.Kind.ARM_POST_HIT_MOVE_ONE:
				return effect_magnitude == 0 and effect_duration > 0
			if operation_kind in [
				BattleKeywordOperation.Kind.APPLY_ADVANTAGE,
				BattleKeywordOperation.Kind.APPLY_SNARED,
				BattleKeywordOperation.Kind.APPLY_BLEED,
			]:
				return effect_magnitude == 0 and effect_duration > 0
			return effect_magnitude > 0 and effect_duration == 0
		Kind.SPEED:
			return (
				advantage_percent == 0
				and role in [TargetRole.ACTOR, TargetRole.PRIMARY, TargetRole.ALL_SELECTED]
				and effect_magnitude != 0
				and effect_duration > 0
			)
		Kind.HISTORY_SCALED_DAMAGE:
			return role == TargetRole.PRIMARY and percent > 0 and history_step > 0 and maximum_percent >= percent + history_step and not source_specific
		Kind.POISON_SCALED_DAMAGE:
			return role == TargetRole.PRIMARY and percent > 0 and history_step > 0 and maximum_percent >= percent + history_step and advantage_percent >= 0 and poison_axis_value in [&"", &"power", &"defense", &"speed"]
		Kind.ARMOR_SPEND_DAMAGE:
			return role == TargetRole.PRIMARY and percent > 0 and effect_magnitude >= 1 and effect_magnitude <= 10 and advantage_percent == 0 and not source_specific
		Kind.CONDITIONAL_LEECH:
			return (
				role == TargetRole.ACTOR
				and effect_magnitude >= 0
				and conditional_amount > effect_magnitude
				and conditional_amount <= 100
			)
		Kind.CAPPED_SELF_DAMAGE:
			return role == TargetRole.ACTOR and effect_magnitude > 0 and effect_magnitude <= 100
		Kind.POISON_TRANSFER:
			return (
				role == TargetRole.ALL_SELECTED
				and percent == 0
				and advantage_percent == 0
				and effect_magnitude == 0
				and effect_duration == 0
				and not source_specific
			)
		Kind.CONDITIONAL_ARMOR:
			return role in [TargetRole.ACTOR, TargetRole.PRIMARY, TargetRole.ALL_SELECTED, TargetRole.SECONDARY, TargetRole.ALL_ACTIVE_ALLIES] and effect_magnitude > 0 and conditional_amount >= effect_magnitude
		Kind.OPTIONAL_SELF_MOVE:
			return (
				role == TargetRole.ACTOR
				and advantage_percent == 0
				and percent == 0
				and effect_magnitude >= 1
				and effect_magnitude <= 3
				and conditional_amount >= 0
				and conditional_amount <= effect_magnitude
				and effect_duration == 0
				and not source_specific
			)
		Kind.FORCED_TARGET_MOVE:
			return (
				role in [TargetRole.PRIMARY, TargetRole.SECONDARY]
				and advantage_percent == 0
				and percent == 0
				and effect_magnitude >= 1
				and effect_magnitude <= 3
				and effect_duration == 0
			)
	return false
