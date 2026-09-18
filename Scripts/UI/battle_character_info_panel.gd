class_name BattleCharacterInfoPanel
extends PanelContainer

signal close_requested

@onready var _close: Button = %InfoClose
var _animation: Tween
var _token: Array = []
var _opened: bool = false

func _ready() -> void:
	_close.pressed.connect(func() -> void: close_requested.emit())
	get_viewport().size_changed.connect(_fit)
	hide()

func render(view: Dictionary, token: Array, resolving: bool) -> void:
	if not _opened or _token.is_empty() or _token[0] != token[0] or _token[3] != token[3]:
		(%InfoScroll as ScrollContainer).scroll_vertical = 0
	_token = token.duplicate()
	(%CharacterName as Label).text = view.get("display_name", "")
	(%CharacterRole as Label).text = view.get("role", "Combatant")
	(%HealthText as Label).text = "Health  " + view.get("hp_text", "")
	(%HealthBar as ProgressBar).max_value = maxi(1, int(view.get("max_hp", 1)))
	(%HealthBar as ProgressBar).value = view.get("current_hp", 0)
	(%Statistics as Label).text = "Speed  %s\nDamage  %s\nDamage reduction  %s\nArmor  %s" % [view.get("speed_text", ""), view.get("damage_text", ""), view.get("defense_text", ""), view.get("armor_text", "0")]
	(%Buffs as Label).text = view.get("buffs_text", "None")
	(%Debuffs as Label).text = view.get("debuffs_text", "None")
	(%Passives as Label).text = view.get("passives_text", "None")
	(%InfoState as Label).text = "Resolving — last committed values" if resolving else view.get("state_text", "")
	accessibility_description = "%s. %s. %s" % [view.get("display_name", ""), view.get("role", ""), view.get("hp_text", "")]
	_fit()

func open_panel() -> void:
	if _opened:
		return
	_opened = true
	show()
	_fit()
	position.x = -size.x
	_animation = create_tween()
	_animation.tween_property(self, "position:x", 0.0, 0.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func close_panel() -> void:
	_opened = false
	_token.clear()
	if is_node_ready():
		(%InfoScroll as ScrollContainer).scroll_vertical = 0
	if is_instance_valid(_animation):
		_animation.kill()
	hide()

func focus_close() -> void:
	_close.grab_focus()

func _fit() -> void:
	if not is_inside_tree():
		return
	size = Vector2(minf(340.0, get_viewport_rect().size.x), maxf(0.0, get_viewport_rect().size.y - 16.0))
	position.y = 8.0
	if _opened and not (is_instance_valid(_animation) and _animation.is_running()):
		position.x = 0.0

func _exit_tree() -> void:
	if is_instance_valid(_animation):
		_animation.kill()
