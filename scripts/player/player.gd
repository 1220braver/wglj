extends CharacterBody2D
## Player 主脚本 — 薄编排层。
## 职责：持有 @export 参数、持有子节点引用、每帧调度组件。

# ═══════════════════════════════════════════
# 移动参数
# ═══════════════════════════════════════════
@export var speed: float = 220.0
@export var acceleration: float = 1800.0
@export var deceleration: float = 2200.0
@export var air_control: float = 0.8
@export var jump_velocity: float = -420.0
@export var max_fall_speed: float = 900.0
@export var jump_buffer_time: float = 0.12
@export var coyote_time: float = 0.12

# ═══════════════════════════════════════════
# 战斗参数
# ═══════════════════════════════════════════
@export var max_hp: int = 100
@export var current_hp: int = 100
@export var defense: int = 0
@export var critical_rate: float = 0.0
@export var move_speed_modifier: float = 1.0

# ═══════════════════════════════════════════
# 游戏规则
# ═══════════════════════════════════════════
@export var infinite_lives: bool = true

# ═══════════════════════════════════════════
# 节点引用
# ═══════════════════════════════════════════
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_point: Marker2D = $AttackPoint
@onready var foot_point: Marker2D = $FootPoint
@onready var hurt_box: Area2D = $HurtBox

# ═══════════════════════════════════════════
# 组件引用
# ═══════════════════════════════════════════
@onready var input_c = $Input
@onready var movement_c = $Movement
@onready var animation_c = $Animation
@onready var health_c = $Health
@onready var attack_c = $Attack

# ═══════════════════════════════════════════
# 主循环
# ═══════════════════════════════════════════
func _physics_process(delta: float) -> void:
	_update_damage_visual()

	# 受伤/死亡锁定一切
	if animation_c.is_locked():
		animation_c.update(input_c.direction)
		return

	# 重力始终生效（攻击期间也不例外 — 防止空中滞空）
	movement_c.apply_gravity(delta)

	# 攻击输入：仅冷却完毕时可触发
	if input_c.attack_just_pressed and attack_c.is_ready():
		attack_c.try_attack()
		animation_c.trigger_attack()
		get_tree().call_group("sfx_bus", "play_sfx", "player_attack")

	# 前摇+激活帧锁移动/跳跃，后摇可移动
	if not attack_c.is_movement_locked():
		movement_c.apply_horizontal(delta, input_c.direction)
		movement_c.apply_jump(input_c.jump_just_pressed)

	move_and_slide()

	attack_c.update(delta)
	animation_c.update(input_c.direction)
	queue_redraw()

# ═══════════════════════════════════════════
# 公共接口
# ═══════════════════════════════════════════
func take_damage(amount: int) -> void:
	attack_c.cancel_attack()
	health_c.take_damage(amount)

func heal(amount: int) -> void:
	health_c.heal(amount)

func is_alive() -> bool:
	return health_c.is_alive()

func respawn() -> void:
	current_hp = max_hp
	velocity = Vector2.ZERO
	visible = true
	modulate = Color.WHITE
	attack_c.cancel_attack()
	health_c.reset_invincible()
	animation_c.set_state(0)  # State.IDLE
	global_position = Vector2(80, 800)

func _update_damage_visual() -> void:
	var t := Time.get_ticks_msec() / 400.0
	if animation_c.is_hurt():
		modulate = Color.RED if int(t * 8) % 2 == 0 else Color.WHITE
	elif health_c.is_invincible():
		var alpha := 0.4 if int(t * 12) % 2 == 0 else 1.0
		modulate = Color(1.0, 1.0, 1.0, alpha)
	else:
		modulate = Color.WHITE

func _draw() -> void:
	var t := Time.get_ticks_msec() / 400.0
	var bob := 0.0
	if abs(velocity.x) > 10:
		bob = sin(t * PI) * 1.0

	# 腿
	draw_rect(Rect2(-12, -6 + bob, 8, 10), Color(0.15, 0.35, 0.15))
	draw_rect(Rect2(4, -6 + bob, 8, 10), Color(0.15, 0.35, 0.15))

	# 鞋
	draw_rect(Rect2(-13, 4 + bob, 10, 4), Color(0.25, 0.2, 0.15))
	draw_rect(Rect2(3, 4 + bob, 10, 4), Color(0.25, 0.2, 0.15))

	# 身体
	draw_rect(Rect2(-10, -28 + bob, 20, 22), Color(0.2, 0.5, 0.2))

	# 腰带
	draw_rect(Rect2(-10, -8 + bob, 20, 3), Color(0.5, 0.35, 0.2))

	# 头
	draw_rect(Rect2(-6, -38 + bob, 12, 12), Color(0.9, 0.75, 0.6))
	# 头发
	draw_rect(Rect2(-7, -42 + bob, 14, 6), Color(0.2, 0.15, 0.1))

	# 眼
	draw_rect(Rect2(-3, -34 + bob, 2, 3), Color(0, 0, 0))
	draw_rect(Rect2(3, -34 + bob, 2, 3), Color(0, 0, 0))

	# 剑（攻击时向前）
	var attacking: bool = attack_c.is_attacking()
	var sword_x := 12 if not sprite.flip_h else -18
	var sword_y := -22 + bob
	if attacking:
		sword_x += (4 if not sprite.flip_h else -4)
		sword_y -= 6
	draw_rect(Rect2(sword_x, sword_y, 3, 18), Color(0.7, 0.7, 0.8))
	draw_rect(Rect2(sword_x - 1, sword_y - 2, 5, 4), Color(0.5, 0.3, 0.1))
