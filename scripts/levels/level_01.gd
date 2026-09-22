extends Node2D
## Level 01 — 完整关卡 + Boss 房集成。

const GROUND_Y := 816.0
const GROUND_H := 32.0

@onready var player = $Player
@onready var hud = $HUD
@onready var boss_gate = $BossGate
@onready var boss_trigger = $BossRoomTrigger
@onready var boss = $BossRoom/BoneKing
@onready var flow_ui = $LevelFlowUI

var _boss_activated := false
var _boss_defeated := false
var _paused := false

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS  # 确保暂停期间仍能接收 ESC 输入
	Engine.time_scale = 1.0
	get_tree().paused = false
	_build_all()
	_setup_boss_trigger()

func _process(_delta: float) -> void:
	if _paused:
		return
	if not player or not hud:
		return
	hud.update_hp(player.current_hp, player.max_hp)

	var alive := 0
	var ehp := ""
	var nearest_enemy = null
	var nearest_dist := INF
	for c in $Enemies.get_children():
		if not is_instance_valid(c) or c.is_queued_for_deletion():
			continue
		var hp: int = c.get("current_hp") if "current_hp" in c else 0
		if hp > 0:
			alive += 1
			ehp += "%d " % hp
			var d: float = player.global_position.distance_to(c.global_position)
			if d < nearest_dist:
				nearest_dist = d
				nearest_enemy = c
	hud.update_enemies(alive)

	var health_c = player.get_node("Health")
	var is_inv: bool = health_c.is_invincible() if health_c.has_method("is_invincible") else false
	hud.update_debug(Engine.get_frames_per_second(), player.current_hp,
		player.get_node("Animation").debug_state, player.global_position, ehp.strip_edges(),
		player.is_on_floor(), player.velocity, is_inv)

	# 最近敌人的 debug
	if nearest_enemy and is_instance_valid(nearest_enemy) and not nearest_enemy.is_queued_for_deletion():
		var e_state: String = nearest_enemy.get("debug_state") if "debug_state" in nearest_enemy else ""
		var e_attacking: bool = nearest_enemy.get("current_state") == 3 if "current_state" in nearest_enemy else false
		var e_hb_open: bool = nearest_enemy.get("debug_hitbox_open") if "debug_hitbox_open" in nearest_enemy else false
		hud.update_enemy_debug(e_state, e_attacking, e_hb_open, nearest_dist)
	else:
		hud.update_enemy_debug("", false, false, 0.0)

	if _boss_activated and not _boss_defeated and is_instance_valid(boss):
		hud.show_boss_hp(boss.current_hp, boss.max_hp)
		var b_state: String = boss.get("debug_state") if "debug_state" in boss else ""
		var b_slam_cd: bool = boss.get("_slam_on_cooldown") if "_slam_on_cooldown" in boss else false
		hud.update_boss_debug(b_state, b_slam_cd)
	else:
		hud.hide_boss_hp()
		hud.update_boss_debug("", false)

func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed:
		return

	# Stage Complete 时由 LevelFlowUI 处理
	if flow_ui.stage_completed:
		return

	if event.keycode == KEY_ESCAPE:
		_toggle_pause()
	elif _paused:
		if event.keycode == KEY_R:
			get_tree().paused = false
			get_tree().reload_current_scene()
		elif event.keycode == KEY_Q:
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _toggle_pause() -> void:
	_paused = !_paused
	get_tree().paused = _paused
	if _paused:
		hud.show_pause()
	else:
		hud.hide_pause()

func _build_all() -> void:
	_ground(0, 3500)  # 扩展到右边界，防掉落
	# 空中平台—全部可用一次普通跳跃到达（最大上升 90px）
	_platform(880, 730, 128)   # P1: 地面上升 86px
	_platform(1100, 650, 128)  # P2: P1 上升 80px
	_platform(1360, 730, 128)  # P3: P2 下落 80px
	_platform(2250, 740, 128)  # P4: 陷阱后休息平台
	_invisible_wall(-32, 0, 32, 900)
	_invisible_wall(3500, 0, 32, 900)

	# BossGate
	var gr := RectangleShape2D.new()
	gr.size = Vector2(32, 96)
	boss_gate.get_node("CollisionShape2D").shape = gr
	boss_gate.get_node("CollisionShape2D").position = Vector2(16, -48)

	queue_redraw()

func _setup_boss_trigger() -> void:
	var s := RectangleShape2D.new()
	s.size = Vector2(64, 600)
	boss_trigger.get_node("CollisionShape2D").shape = s
	boss_trigger.body_entered.connect(_on_boss_trigger)

func _on_boss_trigger(body: Node2D) -> void:
	if _boss_activated:
		return
	if not body.is_in_group("player"):
		return
	_boss_activated = true
	if boss:
		boss.activate()

func close_boss_gate() -> void:
	boss_gate.get_node("CollisionShape2D").disabled = false

func open_boss_gate() -> void:
	boss_gate.get_node("CollisionShape2D").disabled = true

func update_boss_hp(hp: int, _max: int) -> void:
	pass  # HUD handles this via _process

func boss_defeated() -> void:
	_boss_defeated = true
	flow_ui.show_stage_complete()

# ═══════════════════════════════════════════
# 地形工具
# ═══════════════════════════════════════════
func _ground(x: float, w: float) -> void:
	var s := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, GROUND_H)
	c.shape = r
	c.position = Vector2(w / 2.0, GROUND_H / 2.0)
	s.add_child(c)
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, GROUND_H), Vector2(0, GROUND_H)])
	vis.color = Color(0.5, 0.45, 0.4)
	s.add_child(vis)
	for ty in range(8, int(GROUND_H), 8):
		var line := Polygon2D.new()
		line.polygon = PackedVector2Array([Vector2(0, ty), Vector2(w, ty), Vector2(w, ty + 1), Vector2(0, ty + 1)])
		line.color = Color(0.35, 0.3, 0.25)
		s.add_child(line)
	var top := Polygon2D.new()
	top.polygon = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 2), Vector2(0, 2)])
	top.color = Color(0.6, 0.55, 0.5)
	s.add_child(top)
	s.position = Vector2(x, GROUND_Y)
	$Ground.add_child(s)

func _platform(x: float, y: float, w: float) -> void:
	var s := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, 12)
	c.shape = r
	c.position = Vector2(w / 2.0, 6)
	s.add_child(c)
	var vis := Polygon2D.new()
	vis.polygon = PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 12), Vector2(0, 12)])
	vis.color = Color(0.35, 0.5, 0.35)
	s.add_child(vis)
	s.position = Vector2(x, y)
	$Platforms.add_child(s)

func _invisible_wall(x: float, y: float, w: float, h: float) -> void:
	var s := StaticBody2D.new()
	var c := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	c.shape = r
	c.position = Vector2(w / 2.0, h / 2.0)
	s.add_child(c)
	s.position = Vector2(x, y)
	add_child(s)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 3500, 900), Color("#8ED6FF"), true)
	var mountain := PackedVector2Array([Vector2(0, 800), Vector2(200, 650), Vector2(500, 720), Vector2(800, 580), Vector2(1100, 700), Vector2(1400, 620), Vector2(1700, 680), Vector2(2000, 560), Vector2(2300, 640), Vector2(2600, 590), Vector2(2900, 660), Vector2(3200, 600), Vector2(3500, 690), Vector2(3500, 800), Vector2(0, 800)])
	draw_colored_polygon(mountain, Color("#6E8FB5"))
	var trees := PackedVector2Array([Vector2(0, 780), Vector2(0, 830), Vector2(3500, 830), Vector2(3500, 780), Vector2(3400, 760), Vector2(3300, 790), Vector2(3200, 770), Vector2(3100, 790), Vector2(3000, 760), Vector2(2800, 790), Vector2(2600, 770), Vector2(2500, 790), Vector2(2400, 760), Vector2(2200, 790), Vector2(2100, 770), Vector2(2000, 790), Vector2(1800, 760), Vector2(1700, 790), Vector2(1600, 770), Vector2(1500, 790), Vector2(1300, 760), Vector2(1200, 790), Vector2(1100, 770), Vector2(1000, 790), Vector2(800, 760), Vector2(700, 790), Vector2(600, 770), Vector2(400, 790), Vector2(300, 760), Vector2(100, 790)])
	draw_colored_polygon(trees, Color("#4C7A4C"))
	draw_rect(Rect2(0, 800, 3500, 100), Color("#775533"), true)
