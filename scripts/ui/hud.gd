extends CanvasLayer
## HUD — HP + 敌人计数 + Boss HP + Debug(F3) + Pause面板

@onready var hp_bar: ColorRect = $HPBar/Fill
@onready var hp_label: Label = $HPBar/Label
@onready var enemy_label: Label = $EnemyCount
@onready var debug_panel: Control = $DebugPanel
@onready var pause_panel: Control = $PausePanel

var debug_visible := false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS  # 暂停时仍接收 F3
	debug_panel.visible = false
	pause_panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		debug_visible = !debug_visible
		debug_panel.visible = debug_visible

## ── Pause ──
func show_pause() -> void:
	pause_panel.visible = true

func hide_pause() -> void:
	pause_panel.visible = false

func is_pause_visible() -> bool:
	return pause_panel.visible

## ── HP / Enemy ──
func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = "%d/%d" % [current, max_hp]
	hp_bar.size.x = 200.0 * current / max_hp

func update_enemies(remaining: int) -> void:
	enemy_label.text = "Enemies: %d" % remaining

## ── Boss HP ──
func show_boss_hp(hp: int, max_hp: int) -> void:
	$BossHP.visible = true
	$BossHP/Label.text = "Bone King"
	$BossHP/HPText.text = "%d / %d" % [hp, max_hp]
	$BossHP/Fill.size.x = 300.0 * hp / max_hp

func hide_boss_hp() -> void:
	$BossHP.visible = false

## ── Debug ──
func update_debug(fps: int, hp: int, state: String, pos: Vector2, enemy_hp: String,
                  on_floor: bool, vel: Vector2, invincible: bool) -> void:
	$DebugPanel/FPS.text = "FPS: %d" % fps
	$DebugPanel/PlayerHP.text = "HP: %d  State: %s" % [hp, state]
	$DebugPanel/Position.text = "Pos: (%.0f, %.0f)" % [pos.x, pos.y]
	$DebugPanel/EnemyHP.text = "Enemy HP: %s" % enemy_hp
	$DebugPanel/PlayerExt.text = "Floor: %s  Vel: (%.0f, %.0f)  Inv: %s" % [
		"YES" if on_floor else "NO", vel.x, vel.y, "YES" if invincible else "NO"]

func update_enemy_debug(e_state: String, e_attacking: bool, e_hitbox: bool, e_dist: float) -> void:
	if e_state == "":
		$DebugPanel/EnemyDbg.visible = false
		return
	$DebugPanel/EnemyDbg.visible = true
	$DebugPanel/EnemyDbg.text = "E: %s  Atk: %s  HB: %s  Dist: %.0f" % [
		e_state, "YES" if e_attacking else "NO", "ON" if e_hitbox else "OFF", e_dist]

func update_boss_debug(b_state: String, b_slam_cd: bool) -> void:
	if b_state == "":
		$DebugPanel/BossDbg.visible = false
		return
	$DebugPanel/BossDbg.visible = true
	$DebugPanel/BossDbg.text = "Boss: %s  SlamCD: %s" % [b_state, "YES" if b_slam_cd else "NO"]
