extends CharacterBody2D
## PrimitiveWarrior — 基础敌人。
## 攻击流程：CHASE → WINDUP(0.2s,不可见) → ACTIVE(0.15s,HitBox开) → RECOVERY(0.2s) → COOLDOWN(0.8s)

# ═══════════════════════════════════════════
# 参数
# ═══════════════════════════════════════════
@export var max_hp := 40
@export var current_hp := 40
@export var move_speed := 70.0
@export var chase_speed := 90.0
@export var attack_damage := 10
@export var attack_range := 60.0
@export var detection_range := 180.0
@export var patrol_distance := 120.0
@export var wait_time := 1.0
@export var attack_cooldown := 0.8
@export var attack_windup := 0.2
@export var attack_active_time := 0.15
@export var attack_recovery := 0.2
@export var knockback_strength := 120.0
@export var knockback_decay := 900.0
@export var attack_hitbox_offset := 30.0

# ═══════════════════════════════════════════
# 动画名
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
enum AttackPhase { INACTIVE, WINDUP, ACTIVE, RECOVERY }

const STATE_NAMES := ["IDLE", "PATROL", "CHASE", "ATTACK", "HURT", "DEAD"]

var current_state: State = State.IDLE
var player: CharacterBody2D = null
var facing_dir: int = 1
var _spawn_pos: Vector2 = Vector2.ZERO
var _patrol_dir: int = 1
var _wait_timer: float = 0.0

# ── 攻击内部状态 ──
var _attack_phase: AttackPhase = AttackPhase.INACTIVE
var _attack_phase_timer: float = 0.0
var _has_hit_this_attack: bool = false

# ═══════════════════════════════════════════
# Debug
# ═══════════════════════════════════════════
@export var debug_state: String = ""
@export var debug_hp: int = 0
@export var debug_velocity: Vector2 = Vector2.ZERO
@export var debug_hitbox_open: bool = false

func _ready() -> void:
	_spawn_pos = global_position
	attack_timer.wait_time = attack_cooldown

	var hb: Area2D = $HurtBox
	if hb:
		hb.knockback_speed = knockback_strength
		hb.knockback_decay = knockback_decay

	detect_area.body_entered.connect(_on_player_detected)
	detect_area.body_exited.connect(_on_player_lost)
	attack_timer.timeout.connect(_on_attack_cooldown_end)

	# 确保 HitBox 关闭
	_close_hitbox()
	_update_attack_hitbox_position()
	_set_state(State.PATROL)

# ═══════════════════════════════════════════
# 主循环
# ═══════════════════════════════════════════
func _physics_process(delta: float) -> void:
	debug_state = STATE_NAMES[current_state]
	debug_hp = current_hp
	debug_velocity = velocity

	if current_state == State.DEAD:
		return

	if current_state != State.HURT:
		# 攻击开始后锁定朝向，避免贴身时快速左右翻转造成抖动/残影。
		if current_state != State.ATTACK:
			_face_player()
		match current_state:
			State.IDLE:
				velocity.x = 0
			State.PATROL:
				_update_patrol(delta)
			State.CHASE:
				_chase_player(delta)
			State.ATTACK:
				_update_attack(delta)

	_apply_gravity(delta)
	move_and_slide()
	_update_animation()
	_update_attack_visual()
	queue_redraw()

	if current_state != State.HURT:
		if is_on_floor() and not ground_check.is_colliding():
			if current_state == State.PATROL:
				_patrol_dir *= -1
				_wait_timer = 0.0
				_turn_around()
			else:
				velocity.x = 0
		if wall_check.is_colliding():
			if current_state == State.PATROL:
				_patrol_dir *= -1
				_wait_timer = 0.0
				_turn_around()
			elif current_state == State.CHASE:
				velocity.x = 0

# ═══════════════════════════════════════════
# 移动 / 辅助
# ═══════════════════════════════════════════
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta

func _face_player() -> void:
	if not player:
		return
	var to_player := player.global_position.x - global_position.x
	# 留出小型死区，避免角色中心非常接近时朝向每帧反复切换。
	if abs(to_player) > 8:
		facing_dir = 1 if to_player > 0 else -1
		if sprite: sprite.flip_h = facing_dir < 0
		_wall_check_to_facing()
		_update_attack_hitbox_position()

func _wall_check_to_facing() -> void:
	wall_check.target_position.x = abs(wall_check.target_position.x) * facing_dir
	ground_check.target_position.x = 16 * facing_dir
	ground_check.target_position.y = 24

func _turn_around() -> void:
	facing_dir *= -1
	if sprite: sprite.flip_h = facing_dir < 0
	_wall_check_to_facing()
	_update_attack_hitbox_position()

func _update_attack_hitbox_position() -> void:
	if not hit_box:
		return
	hit_box.position.x = absf(attack_hitbox_offset) * facing_dir

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

func _chase_player(delta: float) -> void:
	if not player:
		_set_state(State.PATROL)
		return

	var dist := global_position.distance_to(player.global_position)
	if dist <= attack_range:
		_try_start_attack()
		return

	var dir := 1.0 if player.global_position.x > global_position.x else -1.0
	velocity.x = move_toward(velocity.x, dir * chase_speed, 600.0 * delta)

# ═══════════════════════════════════════════
# 攻击系统（核心重写）
# ═══════════════════════════════════════════
func _try_start_attack() -> void:
	if current_state == State.ATTACK:
		return
	if not attack_timer.is_stopped():
		return
	if not player:
		return

	velocity.x = 0
	_set_state(State.ATTACK)
	_attack_phase = AttackPhase.WINDUP
	_attack_phase_timer = 0.0
	_has_hit_this_attack = false
	_close_hitbox()

func _update_attack(delta: float) -> void:
	_attack_phase_timer += delta

	match _attack_phase:
		AttackPhase.WINDUP:
			# HitBox 保持关闭 — 玩家看到前摇但不会受伤
			if _attack_phase_timer >= attack_windup:
				_attack_phase = AttackPhase.ACTIVE
				_attack_phase_timer = 0.0
				_open_hitbox()

		AttackPhase.ACTIVE:
			# HitBox 打开中 — 可以命中玩家
			if _attack_phase_timer >= attack_active_time:
				_attack_phase = AttackPhase.RECOVERY
				_attack_phase_timer = 0.0
				_close_hitbox()

		AttackPhase.RECOVERY:
			# HitBox 已关闭 — 后摇等待
			if _attack_phase_timer >= attack_recovery:
				_attack_phase = AttackPhase.INACTIVE
				_attack_phase_timer = 0.0
				attack_timer.start(attack_cooldown)
				if player and global_position.distance_to(player.global_position) <= detection_range:
					_set_state(State.CHASE)
				else:
					_set_state(State.PATROL)

## ── 攻击视觉效果（占位）──
func _update_attack_visual() -> void:
	if current_state == State.ATTACK:
		match _attack_phase:
			AttackPhase.WINDUP:
				modulate = Color(1.0, 0.7, 0.3)   # 黄色蓄力信号
			AttackPhase.ACTIVE:
				modulate = Color(1.0, 0.3, 0.3)    # 红色攻击信号
			AttackPhase.RECOVERY:
				modulate = Color(1.0, 0.8, 0.6)    # 淡红恢复
			_:
				modulate = Color.WHITE
	elif current_state == State.HURT:
		modulate = Color.RED if int(Time.get_ticks_msec() / 100) % 2 == 0 else Color.WHITE
	else:
		modulate = Color.WHITE

## ── HitBox 开关 ──
func _open_hitbox() -> void:
	_update_attack_hitbox_position()
	debug_hitbox_open = true
	hit_box.set_deferred("monitorable", true)
	hit_shape.set_deferred("disabled", false)

func _close_hitbox() -> void:
	debug_hitbox_open = false
	hit_box.set_deferred("monitorable", false)
	hit_shape.set_deferred("disabled", true)

## ── 冷却结束 ──
func _on_attack_cooldown_end() -> void:
	pass

# ═══════════════════════════════════════════
# Player 检测
# ═══════════════════════════════════════════
func _on_player_detected(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body as CharacterBody2D
		# 玩家与敌人不做实体推挤；否则贴身时两个 CharacterBody2D
		# 会互相挤到对侧并快速翻转，造成抖动与残影。
		if player:
			add_collision_exception_with(player)
			player.add_collision_exception_with(self)
			wall_check.add_exception(player)
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

	# 受击时关闭 HitBox + 打断攻击
	_close_hitbox()
	if current_state == State.ATTACK:
		_attack_phase = AttackPhase.INACTIVE

	current_state = State.HURT
	sprite.play(anim_hurt)

	await get_tree().create_timer(0.3).timeout
	if current_state != State.HURT:
		return
	if player and global_position.distance_to(player.global_position) <= detection_range:
		_set_state(State.CHASE)
	else:
		_set_state(State.PATROL)

func _die() -> void:
	get_tree().call_group("sfx_bus", "play_sfx", "enemy_death")
	get_tree().call_group("effect_spawner", "spawn_effect", "death_dust", global_position)
	_close_hitbox()
	_set_state(State.DEAD)
	sprite.play(anim_dead)
	detect_area.set_deferred("monitoring", false)
	collision_layer = 0
	$CollisionShape2D.set_deferred("disabled", true)

	var hurt_box_node: Area2D = $HurtBox
	if hurt_box_node:
		hurt_box_node.set_deferred("monitoring", false)
		hurt_box_node.set_deferred("monitorable", false)

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

	# 攻击动画：身体前冲效果
	var lunge := 0.0
	if current_state == State.ATTACK:
		match _attack_phase:
			AttackPhase.WINDUP:
				lunge = 0.0   # 蓄力不动
			AttackPhase.ACTIVE:
				lunge = 8.0   # 前冲 8px
			AttackPhase.RECOVERY:
				lunge = lerpf(8.0, 0.0, _attack_phase_timer / attack_recovery)
	var dir := 1.0 if not sprite.flip_h else -1.0

	# 腿
	draw_rect(Rect2(-12 + lunge * dir, -4 + bob, 8, 16), Color(0.3, 0.2, 0.15))
	draw_rect(Rect2(4 + lunge * dir, -4 + bob, 8, 16), Color(0.3, 0.2, 0.15))
	# 身体
	draw_rect(Rect2(-10 + lunge * dir, -32 + bob, 20, 28), Color(0.45, 0.3, 0.2))
	# 头
	draw_rect(Rect2(-6 + lunge * dir, -46 + bob, 12, 14), Color(0.55, 0.4, 0.25))
	draw_rect(Rect2(-3 + lunge * dir, -43 + bob, 2, 2), Color(0, 0, 0))
	draw_rect(Rect2(3 + lunge * dir, -43 + bob, 2, 2), Color(0, 0, 0))
	# 木棒
	var stick_x := (10 if not sprite.flip_h else -14) + lunge * dir
	draw_rect(Rect2(stick_x, -38 + bob, 3, 22), Color(0.5, 0.35, 0.15))
	draw_rect(Rect2(stick_x - 2, -40 + bob, 7, 6), Color(0.55, 0.4, 0.2))
