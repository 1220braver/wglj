extends CharacterBody2D
## Bone King V1 — 第一关 Boss。
## 完全兼容现有 Combat Framework。

enum State { SLEEP, INTRO, IDLE, CHASE, PUNCH, JUMP_SLAM, HURT, DEAD }

# ═══════════════════════════════════════════
# 参数
# ═══════════════════════════════════════════
@export var max_hp := 300
@export var current_hp := 300
@export var move_speed := 45.0
@export var punch_damage := 20
@export var slam_damage := 25
@export var punch_range := 80.0
@export var chase_range := 500.0
@export var attack_cooldown := 1.8
@export var slam_cooldown := 3.0
@export var knockback_strength := 80.0
@export var knockback_multiplier := 0.25
@export var jump_velocity := -360.0
@export var slam_horizontal_speed := 120.0
@export var slam_recovery_time := 0.8
@export var slam_warning_radius := 60.0
@export var punch_hitbox_offset := 32.0

# ═══════════════════════════════════════════
# 攻击时序
# ═══════════════════════════════════════════
@export var punch_windup := 0.25
@export var punch_active := 0.18
@export var punch_recovery := 0.3
@export var slam_charge := 0.8
@export var slam_active := 0.2

# ═══════════════════════════════════════════
# 动画
# ═══════════════════════════════════════════
@export var anim_idle := "idle"
@export var anim_walk := "walk"
@export var anim_punch := "punch"
@export var anim_slam := "jump_slam"
@export var anim_hurt := "hurt"
@export var anim_dead := "dead"

# ═══════════════════════════════════════════
# 节点引用
# ═══════════════════════════════════════════
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: Area2D = $HurtBox
@onready var punch_hit_box: Area2D = $PunchHitBox
@onready var punch_hit_shape: CollisionShape2D = $PunchHitBox/CollisionShape2D
@onready var slam_hit_box: Area2D = $SlamHitBox
@onready var slam_hit_shape: CollisionShape2D = $SlamHitBox/CollisionShape2D
@onready var front_point: Marker2D = $FrontPoint
@onready var attack_timer: Timer = $AttackTimer
@onready var state_timer: Timer = $StateTimer

# ═══════════════════════════════════════════
# 状态
# ═══════════════════════════════════════════
var current_state: State = State.SLEEP
var player: CharacterBody2D = null
var facing_dir: int = -1
var _attack_phase := 0
var _attack_timer: float = 0.0
var _gate_closed := false
var _dead := false
var _slam_target: Vector2 = Vector2.ZERO
var _slam_on_cooldown := false

# Debug
@export var debug_state: String = "SLEEP"
const STATE_NAMES := ["SLEEP", "INTRO", "IDLE", "CHASE", "PUNCH", "JUMP_SLAM", "HURT", "DEAD"]

func _ready() -> void:
	add_to_group("boss")
	_close_all_hitboxes()
	_update_punch_hitbox_position()
	state_timer.one_shot = true

func activate() -> void:
	if current_state != State.SLEEP:
		return
	current_state = State.INTRO
	debug_state = "INTRO"
	_close_gate()
	await get_tree().create_timer(1.0).timeout
	if current_state == State.INTRO:
		current_state = State.CHASE
		debug_state = "CHASE"

func _close_gate() -> void:
	if _gate_closed:
		return
	_gate_closed = true
	var level := _get_level()
	if level and level.has_method("close_boss_gate"):
		level.close_boss_gate()

func _open_gate() -> void:
	if not _gate_closed:
		return
	_gate_closed = false
	var level := _get_level()
	if level and level.has_method("open_boss_gate"):
		level.open_boss_gate()

func _physics_process(delta: float) -> void:
	debug_state = STATE_NAMES[current_state]

	if current_state == State.SLEEP:
		return
	if current_state == State.DEAD:
		return

	if current_state == State.INTRO:
		velocity.x = 0
		_apply_gravity(delta)
		move_and_slide()
		return

	if current_state == State.HURT:
		_apply_gravity(delta)
		move_and_slide()
		_update_animation()
		queue_redraw()
		return

	_find_player()

	# Jump Slam 期间锁定朝向，不追踪玩家
	if current_state != State.JUMP_SLAM:
		_face_player()

	match current_state:
		State.IDLE:
			velocity.x = 0
		State.CHASE:
			_chase(delta)
		State.PUNCH:
			_update_punch(delta)
		State.JUMP_SLAM:
			_update_slam(delta)

	_apply_gravity(delta)
	move_and_slide()
	_update_animation()
	queue_redraw()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta

func _find_player() -> void:
	if player:
		return
	var bodies = $DetectionArea.get_overlapping_bodies() if has_node("DetectionArea") else []
	for b in bodies:
		if b.is_in_group("player"):
			player = b
			return
	# Fallback
	var tree = get_tree()
	if tree:
		var nodes = tree.get_nodes_in_group("player")
		if nodes.size() > 0:
			player = nodes[0]

func _face_player() -> void:
	if not player:
		return
	var d := player.global_position.x - global_position.x
	if abs(d) > 5:
		facing_dir = 1 if d > 0 else -1
		if sprite:
			sprite.flip_h = facing_dir < 0
		_update_punch_hitbox_position()

func _update_punch_hitbox_position() -> void:
	if not punch_hit_box:
		return
	punch_hit_box.position.x = absf(punch_hitbox_offset) * facing_dir

func _chase(delta: float) -> void:
	if not player:
		current_state = State.IDLE
		debug_state = "IDLE"
		return

	var dist := global_position.distance_to(player.global_position)

	if dist <= punch_range and attack_timer.is_stopped():
		# Punch 优先；仅 Slam 未冷却时 30% 概率触发
		if not _slam_on_cooldown and randf() < 0.3:
			_start_slam()
		else:
			_start_punch()
		return

	var dir := 1.0 if player.global_position.x > global_position.x else -1.0
	velocity.x = move_toward(velocity.x, dir * move_speed, 200.0 * delta)

# ═══════════════════════════════════════════
# PUNCH
# ═══════════════════════════════════════════
func _start_punch() -> void:
	get_tree().call_group("sfx_bus", "play_sfx", "boss_punch")
	current_state = State.PUNCH
	debug_state = "PUNCH"
	velocity.x = 0
	_attack_phase = 0
	_attack_timer = 0.0
	_close_all_hitboxes()
	_update_punch_hitbox_position()

func _update_punch(delta: float) -> void:
	_attack_timer += delta
	match _attack_phase:
		0:  # windup
			if _attack_timer >= punch_windup:
				_attack_phase = 1
				_attack_timer = 0.0
				punch_hit_box.set_deferred("monitorable", true)
				punch_hit_shape.set_deferred("disabled", false)
		1:  # active
			if _attack_timer >= punch_active:
				_attack_phase = 2
				_attack_timer = 0.0
				punch_hit_box.set_deferred("monitorable", false)
				punch_hit_shape.set_deferred("disabled", true)
		2:  # recovery
			if _attack_timer >= punch_recovery:
				attack_timer.start(attack_cooldown)
				current_state = State.CHASE
				debug_state = "CHASE"

# ═══════════════════════════════════════════
# JUMP_SLAM
# ═══════════════════════════════════════════
func _start_slam() -> void:
	current_state = State.JUMP_SLAM
	debug_state = "JUMP_SLAM"
	velocity.x = 0
	_attack_phase = 0
	_attack_timer = 0.0
	_close_all_hitboxes()
	# 锁定玩家当前位置，之后不再追踪
	if player:
		_slam_target = player.global_position
	else:
		_slam_target = global_position + Vector2(facing_dir * 200, 0)

func _update_slam(delta: float) -> void:
	_attack_timer += delta
	match _attack_phase:
		0:  # charge (0.8s) — 锁定目标显示蓄力
			if _attack_timer >= slam_charge:
				_attack_phase = 1
				_attack_timer = 0.0
				var gravity := 980.0
				var estimated_flight_time := maxf(absf(2.0 * jump_velocity) / gravity, 0.1)
				var target_speed := (_slam_target.x - global_position.x) / estimated_flight_time
				velocity.y = jump_velocity
				velocity.x = clampf(target_speed, -slam_horizontal_speed, slam_horizontal_speed)
		1:  # airborne — 等待落地
			if is_on_floor() and _attack_timer > 0.1:
				_attack_phase = 2
				_attack_timer = 0.0
				velocity.x = 0
				slam_hit_box.set_deferred("monitorable", true)
				slam_hit_shape.set_deferred("disabled", false)
				_shake(6.0, 0.18)
				get_tree().call_group("sfx_bus", "play_sfx", "boss_slam")
				get_tree().call_group("effect_spawner", "spawn_effect", "slam_dust", global_position + Vector2(0, 32))
		2:  # slam active
			if _attack_timer >= slam_active:
				_attack_phase = 3
				_attack_timer = 0.0
				slam_hit_box.set_deferred("monitorable", false)
				slam_hit_shape.set_deferred("disabled", true)
		3:  # recovery
			if _attack_timer >= slam_recovery_time:
				attack_timer.start(attack_cooldown)
				_start_slam_cooldown()
				current_state = State.CHASE
				debug_state = "CHASE"

# ═══════════════════════════════════════════
# 受击
# ═══════════════════════════════════════════
func take_damage(amount: int, _hit_dir: Vector2 = Vector2.ZERO) -> void:
	if _dead:
		return
	if current_state == State.DEAD:
		return

	current_hp = maxi(current_hp - amount, 0)

	if current_hp <= 0:
		_die()
		return

	# 轻微击退（不打断攻击）
	if current_state not in [State.PUNCH, State.JUMP_SLAM]:
		current_state = State.HURT
		debug_state = "HURT"
		await get_tree().create_timer(0.15).timeout
		if current_state == State.HURT:
			current_state = State.CHASE
			debug_state = "CHASE"

	# 通知 HUD 更新
	var level := _get_level()
	if level and level.has_method("update_boss_hp"):
		level.update_boss_hp(current_hp, max_hp)

func _die() -> void:
	get_tree().call_group("sfx_bus", "play_sfx", "boss_death")
	get_tree().call_group("effect_spawner", "spawn_effect", "boss_death", global_position)
	_dead = true
	current_state = State.DEAD
	debug_state = "DEAD"
	_close_all_hitboxes()
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)
	collision_layer = 0
	$CollisionShape2D.set_deferred("disabled", true)

	# 通知关卡（在 queue_free 之前）
	var level := _get_level()
	if level and level.has_method("boss_defeated"):
		level.boss_defeated()

	await get_tree().create_timer(1.0).timeout
	_open_gate()
	queue_free()

## ── Slam 独立冷却（3s，用 await 实现）──
func _start_slam_cooldown() -> void:
	_slam_on_cooldown = true
	await get_tree().create_timer(slam_cooldown).timeout
	_slam_on_cooldown = false

# ═══════════════════════════════════════════
# 工具
# ═══════════════════════════════════════════
func _close_all_hitboxes() -> void:
	punch_hit_box.set_deferred("monitorable", false)
	punch_hit_shape.set_deferred("disabled", true)
	slam_hit_box.set_deferred("monitorable", false)
	slam_hit_shape.set_deferred("disabled", true)

func _get_level() -> Node:
	var node: Node = get_parent()
	while node:
		if node.has_method("boss_defeated"):
			return node
		node = node.get_parent()
	return null

func _shake(px: float, duration: float) -> void:
	var cameras := get_tree().root.find_children("*", "Camera2D", true, false)
	if cameras.is_empty():
		return
	var cam: Camera2D = cameras[0]
	var original := cam.offset
	var tween := cam.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for i in range(6):
		var x := randf_range(-px, px)
		var y := randf_range(-px, px)
		tween.tween_property(cam, "offset", Vector2(x, y), duration / 6.0)
	tween.tween_property(cam, "offset", original, 0.01)

func _update_animation() -> void:
	if not sprite:
		return
	match current_state:
		State.IDLE, State.SLEEP, State.INTRO:
			sprite.play(anim_idle)
		State.CHASE:
			sprite.play(anim_walk)
		State.PUNCH:
			sprite.play(anim_punch)
		State.JUMP_SLAM:
			sprite.play(anim_slam)
		State.HURT:
			sprite.play(anim_hurt)
		State.DEAD:
			sprite.play(anim_dead)

func _draw() -> void:
	if _dead:
		return
	if current_state == State.JUMP_SLAM and _attack_phase < 2:
		var marker_global := Vector2(_slam_target.x, _slam_target.y + 16.0)
		var marker_local := to_local(marker_global)
		var pulse := 0.45 + sin(Time.get_ticks_msec() / 90.0) * 0.15
		var warning_rect := Rect2(
			marker_local.x - slam_warning_radius,
			marker_local.y - 5.0,
			slam_warning_radius * 2.0,
			10.0
		)
		draw_rect(warning_rect, Color(0.9, 0.08, 0.05, pulse), true)
		draw_rect(warning_rect, Color(1.0, 0.75, 0.2, 0.95), false, 2.0)
	# 大型占位 — 骷髅王
	draw_rect(Rect2(-32, -64, 64, 64), Color(0.6, 0.1, 0.1), true)  # 身体
	draw_rect(Rect2(-28, -60, 56, 56), Color(0.85, 0.75, 0.65))  # 骨色内
	draw_rect(Rect2(-16, -80, 32, 20), Color(0.85, 0.75, 0.65))  # 头
	draw_rect(Rect2(-8, -76, 4, 4), Color(0.2, 0, 0))  # 左眼
	draw_rect(Rect2(4, -76, 4, 4), Color(0.2, 0, 0))  # 右眼
	draw_rect(Rect2(-4, -82, 8, 6), Color(0.6, 0.1, 0.1))  # 冠
	if current_state == State.HURT:
		modulate = Color.RED if int(Time.get_ticks_msec() / 100) % 2 == 0 else Color.WHITE
