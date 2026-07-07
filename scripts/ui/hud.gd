extends CanvasLayer
## HUD — 左上 HP + 右上敌人计数 + F3 调试面板

@onready var hp_bar: ColorRect = $HPBar/Fill
@onready var hp_label: Label = $HPBar/Label
@onready var enemy_label: Label = $EnemyCount
@onready var debug_panel: Control = $DebugPanel

var debug_visible := false

func _ready() -> void:
	debug_panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		debug_visible = !debug_visible
		debug_panel.visible = debug_visible

func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = "%d/%d" % [current, max_hp]
	hp_bar.size.x = 200.0 * current / max_hp

func update_enemies(remaining: int) -> void:
	enemy_label.text = "Enemies: %d" % remaining

func show_boss_hp(hp: int, max_hp: int) -> void:
	$BossHP.visible = true
	$BossHP/Label.text = "Bone King"
	$BossHP/HPText.text = "%d / %d" % [hp, max_hp]
	$BossHP/Fill.size.x = 300.0 * hp / max_hp

func hide_boss_hp() -> void:
	$BossHP.visible = false

func update_debug(fps: int, hp: int, state: String, pos: Vector2, enemy_hp: String) -> void:
	$DebugPanel/FPS.text = "FPS: %d" % fps
	$DebugPanel/PlayerHP.text = "Player HP: %d" % hp
	$DebugPanel/State.text = "State: %s" % state
	$DebugPanel/Position.text = "Pos: (%.0f, %.0f)" % [pos.x, pos.y]
	$DebugPanel/EnemyHP.text = "Enemy HP: %s" % enemy_hp
