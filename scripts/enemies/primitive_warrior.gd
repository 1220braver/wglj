extends CharacterBody2D
## PrimitiveWarrior — 基础敌人。
## 通过 DetectionArea 发现玩家 → 追击 → 近战攻击。
## 兼容现有 Combat Framework（HurtBox + HitBox）。

# ═══════════════════════════════════════════
# 参数
# ═══════════════════════════════════════════
@export var max_hp := 40
@export var current_hp := 40
@export var move_speed := 70.0
@export var chase_speed := 90.0
@export var attack_damage := 10
@export var attack_range := 36.0
@export var detection_range := 180.0
@export var patrol_distance := 120.0
@export var wait_time := 1.0
@export var attack_cooldown := 0.8
@export var knockback_strength := 120.0
@export var knockback_decay := 900.0

# ═══════════════════════════════════════════
# 攻击时序（动画驱动）
# ═══════════════════════════════════════════
@export var hit_frame := 3
@export var hit_duration := 0.15

# ═══════════════════════════════════════════
# 动画
# ═══════════════════════════════════════════
@export var anim_idle: String = "idle"
@export var anim_walk: String = "walk"
@export var anim_attack: String = "attack"
@export var anim_hurt: String = "hurt"
@export var anim_dead: String = "dead"

# ═══════════════════════════════════════════
# 节点引用
# ═══════════════════════════════════════════
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: Area2D = $HitBox
@onready var hit_shape: CollisionShape2D = $HitBox/CollisionShape2D
@onready var detect_area: Area2D = $DetectionArea
@onready var ground_check: RayCast2D = $GroundCheck
@onready var wall_check: RayCast2D = $WallCheck
@onready var attack_timer: Timer = $AttackCooldown

# ═══════════════════════════════════════════
# 状态机
# ═══════════════════════════════════════════
enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }
const STATE_NAMES := ["IDLE", "PATROL", "CHASE", "ATTACK", "HURT", "DEAD"]

var current_state: State = State.IDLE
var player: CharacterBody2D = null
var facing_dir: int = 1
var _spawn_pos: Vector2 = Vector2.ZERO
var _patrol_dir: int = 1
var _wait_timer: float = 0.0
var _hitbox_open: bool = false
var _hitbox_timer: float = 0.0

# ═══════════════════════════════════════════
# Debug（Inspector 实时查看）
# ═══════════════════════════════════════════
@export var debug_state: String = ""
@export var debug_hp: int = 0
@export var debug_velocity: Vector2 = Vector2.ZERO

func _ready() -> void:
	_spawn_pos = global_position
	attack_timer.wait_time = attack_cooldown

	# 同步 knockback 参数到 HurtBox
	var hb = $HurtBox
	if hb:
		hb.knockback_speed = knockback_strength
		hb.knockback_decay = knockback_decay

	detect_area.body_entered.connect(_on_player_detected)
	detect_area.body_exited.connect(_on_player_lost)
	attack_timer.timeout.connect(_on_attack_cooldown_end)
	sprite.animation_finished.connect(_on_attack_animation_finished)
	sprite.frame_changed.connect(_on_attack_frame_changed)
	_set_state(State.PATROL)

func _physics_process(delta: float) -> void:
	# 同步 Debug 变量
	debug_state = STATE_NAMES[current_state]
	debug_hp = current_hp
	debug_velocity = velocity

	if current_state == State.DEAD:
		return

	# HURT 状态：不操控移动，但必须 move_and_slide 处理 knockback
	if current_state != State.HURT:
		_face_player()
		match current_state:
			State.IDLE:
				velocity.x = 0
			State.PATROL:
				_update_patrol(delta)
			State.CHASE:
				_chase_player(delta)
			State.ATTACK:
				velocity.x = 0
				if _hitbox_open:
					_hitbox_timer -= delta
					if _hitbox_timer <= 0.0:
						_close_hitbox()

	_apply_gravity(delta)
	move_and_slide()
	_update_animation()
	queue_redraw()

	if current_state != State.HURT:
		# 边缘检测：PATROL 时前方无地面 → 翻转
		if is_on_floor() and not ground_check.is_colliding():
			if current_state == State.PATROL:
				_patrol_dir *= -1
				_wait_timer = 0.0
				_turn_around()
			else:
				velocity.x = 0
		# 墙壁检测
		if wall_check.is_colliding():
			if current_state == State.PATROL:
				_patrol_dir *= -1
				_wait_timer = 0.0
			_turn_around()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta

func _face_player() -> void:
	if not player:
		return
	var to_player := player.global_position.x - global_position.x
	if abs(to_player) > 2:
		facing_dir = 1 if to_player > 0 else -1
		if sprite: sprite.flip_h = facing_dir < 0
		_wall_check_to_facing()

func _wall_check_to_facing() -> void:
	wall_check.target_position.x = abs(wall_check.target_position.x) * facing_dir
	ground_check.target_position.x = 16 * facing_dir  # 前方地面检测
	ground_check.target_position.y = 24

func _turn_around() -> void:
	facing_dir *= -1
	if sprite: sprite.flip_h = facing_dir < 0
	_wall_check_to_facing()

func _update_patrol(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait_timer -= delta
		velocity.x = 0
		return

	var half_dist := patrol_distance / 2.0
	var offset := global_position.x - _spawn_pos.x

	if offset >= half_dist:
		_patrol_dir = -1
		_wait_timer = wait_time
	elif offset <= -half_dist:
		_patrol_dir = 1
		_wait_timer = wait_time

	if _wait_timer > 0.0:
		velocity.x = 0
		return

	facing_dir = _patrol_dir
	if sprite: sprite.flip_h = facing_dir < 0
	_wall_check_to_facing()
	velocity.x = _patrol_dir * move_speed

func _set_state(new_state: State) -> void:
	current_state = new_state

func _update_animation() -> void:
	if not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation(anim_walk):
		return

	match current_state:
		State.IDLE, State.PATROL:
			if abs(velocity.x) > 1:
				sprite.play(anim_walk)
			else:
				sprite.play(anim_idle)
		State.CHASE:
			sprite.play(anim_walk)
		State.ATTACK:
			sprite.play(anim_attack)
		State.HURT:
			sprite.play(anim_hurt)
		State.DEAD:
			sprite.play(anim_dead)

func _chase_player(delta: float) -> void:
	if not player:
		_set_state(State.PATROL)
		return

	var dist := global_position.distance_to(player.global_position)

	# 进入攻击范围
	if dist <= attack_range:
		_try_attack()
		return

	# 追击
	var dir := 1.0 if player.global_position.x > global_position.x else -1.0
	velocity.x = move_toward(velocity.x, dir * chase_speed, 600.0 * delta)

func _try_attack() -> void:
	if current_state == State.ATTACK:
		return
	if not attack_timer.is_stopped():
		return

	_set_state(State.ATTACK)
	_close_hitbox()
	sprite.play(anim_attack)

	# 有精灵帧 → frame_changed 触发；无帧 → 计时器兜底
	var frame_count := sprite.sprite_frames.get_frame_count(anim_attack) if sprite.sprite_frames else 0
	if frame_count == 0:
		get_tree().create_timer(0.2).timeout.connect(_open_hitbox)
		get_tree().create_timer(0.55).timeout.connect(_finish_attack)

func _finish_attack() -> void:
	if current_state not in [State.ATTACK, State.CHASE, State.PATROL, State.IDLE]:
		return
	_close_hitbox()
	attack_timer.start()
	_set_state(State.CHASE)

func _on_attack_frame_changed() -> void:
	if current_state != State.ATTACK:
		return
	if _hitbox_open:
		return
	if sprite.animation != anim_attack:
		return
	if sprite.frame >= hit_frame:
		_open_hitbox()

func _on_attack_animation_finished() -> void:
	if current_state != State.ATTACK:
		return
	if sprite.animation != anim_attack:
		return
	# 占位精灵（0帧）由计时器管理，跳过
	if sprite.sprite_frames.get_frame_count(anim_attack) == 0:
		return
	_finish_attack()

func _open_hitbox() -> void:
	if current_state not in [State.ATTACK, State.CHASE, State.PATROL, State.IDLE]:
		return
	_hitbox_open = true
	_hitbox_timer = hit_duration
	hit_box.set_deferred("monitorable", true)
	hit_shape.set_deferred("disabled", false)

func _close_hitbox() -> void:
	_hitbox_open = false
	_hitbox_timer = 0.0
	hit_box.set_deferred("monitorable", false)
	hit_shape.set_deferred("disabled", true)

func _on_attack_cooldown_end() -> void:
	pass  # attack_timer 的 timeout 仅用于标记冷却结束

func _on_player_detected(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D
		if current_state not in [State.ATTACK, State.HURT, State.DEAD]:
			_set_state(State.CHASE)

func _on_player_lost(body: Node2D) -> void:
	if body == player:
		player = null
		if current_state not in [State.ATTACK, State.HURT, State.DEAD]:
			_set_state(State.PATROL)

# ═══════════════════════════════════════════
# 受击
# ═══════════════════════════════════════════
func take_damage(amount: int, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if current_state == State.DEAD:
		return

	current_hp = maxi(current_hp - amount, 0)

	if current_hp <= 0:
		_die()
		return

	if current_state != State.ATTACK:
		_enter_hurt(hit_direction)

func _enter_hurt(_hit_direction: Vector2) -> void:
	_close_hitbox()
	_set_state(State.HURT)
	sprite.play(anim_hurt)

	# HURT 结束后回到追击或巡逻
	await get_tree().create_timer(0.3).timeout
	if current_state != State.HURT:
		return
	if player and global_position.distance_to(player.global_position) <= detection_range:
		_set_state(State.CHASE)
	else:
		_set_state(State.PATROL)

func _die() -> void:
	get_tree().call_group("sfx_bus", "play_sfx", "enemy_death")
	_close_hitbox()
	_set_state(State.DEAD)
	sprite.play(anim_dead)
	detect_area.set_deferred("monitoring", false)
	collision_layer = 0
	$CollisionShape2D.set_deferred("disabled", true)

	# 关闭 HurtBox
	var hurt_box_node = $HurtBox
	if hurt_box_node:
		hurt_box_node.set_deferred("monitoring", false)
		hurt_box_node.set_deferred("monitorable", false)

	# 死亡动画播完消失
	await get_tree().create_timer(0.6).timeout
	queue_free()

# ═══════════════════════════════════════════
# 占位绘制
# ═══════════════════════════════════════════
func _draw() -> void:
	if current_state == State.DEAD:
		return

	var t := Time.get_ticks_msec() / 500.0
	var bob := sin(t * PI) * 1.0 if current_state == State.IDLE else 0.0

	# 腿
	draw_rect(Rect2(-12, -4 + bob, 8, 16), Color(0.3, 0.2, 0.15))
	draw_rect(Rect2(4, -4 + bob, 8, 16), Color(0.3, 0.2, 0.15))

	# 身体
	draw_rect(Rect2(-10, -32 + bob, 20, 28), Color(0.45, 0.3, 0.2))

	# 头
	draw_rect(Rect2(-6, -46 + bob, 12, 14), Color(0.55, 0.4, 0.25))
	draw_rect(Rect2(-3, -43 + bob, 2, 2), Color(0, 0, 0))  # 左眼
	draw_rect(Rect2(3, -43 + bob, 2, 2), Color(0, 0, 0))   # 右眼

	# 木棒
	var stick_x := 10 if not sprite.flip_h else -14
	draw_rect(Rect2(stick_x, -38 + bob, 3, 22), Color(0.5, 0.35, 0.15))
	draw_rect(Rect2(stick_x - 2, -40 + bob, 7, 6), Color(0.55, 0.4, 0.2))

	# HURT 闪烁效果
	if current_state == State.HURT:
		if int(t * 10) % 2 == 0:
			modulate = Color(1, 0.3, 0.3)
		else:
			modulate = Color.WHITE
