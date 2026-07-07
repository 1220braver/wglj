extends Node
## 攻击层 — 管理攻击时序、HitBox 开关、冷却。
## 所有参数 @export，攻击逻辑与动画/输入解耦。

# ═══════════════════════════════════════════
# 攻击参数
# ═══════════════════════════════════════════
@export var damage: int = 20
@export var attack_range: float = 48.0       # px, 约 1.5 tile
@export var cooldown: float = 0.35           # 总冷却
@export var active_frame: float = 0.08       # HitBox 开启窗口
@export var wind_up: float = 0.05            # 前摇
@export var recovery: float = 0.1            # 后摇

# ═══════════════════════════════════════════
# 内部状态
# ═══════════════════════════════════════════
enum Phase { READY, WINDUP, ACTIVE, RECOVERY }

var player: CharacterBody2D
var hit_box: Area2D
var hit_box_shape: CollisionShape2D
var attack_point: Marker2D

var _phase: Phase = Phase.READY
var _timer: float = 0.0
var _total_time: float = 0.0
var _can_attack: bool = true

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	hit_box = player.get_node("HitBox")
	hit_box_shape = hit_box.get_node("CollisionShape2D")
	attack_point = player.get_node("AttackPoint")
	_update_hitbox_position()

## 尝试发起攻击。返回 true 表示攻击已触发。
func try_attack() -> bool:
	if _phase != Phase.READY:
		return false

	_phase = Phase.WINDUP
	_timer = 0.0
	_total_time = 0.0
	_can_attack = false

	# 前摇阶段：关 HitBox
	if hit_box:
		hit_box.monitorable = false
	if hit_box_shape:
		hit_box_shape.disabled = true
	_update_hitbox_position()

	return true

## 每帧由 Player 调用
func update(delta: float) -> void:
	match _phase:
		Phase.READY:
			return
		Phase.WINDUP:
			_timer += delta
			if _timer >= wind_up:
				_enter_active()
		Phase.ACTIVE:
			_timer += delta
			if _timer >= active_frame:
				_enter_recovery()
		Phase.RECOVERY:
			_timer += delta
			if _timer >= recovery:
				_enter_ready()

	# 安全兜底：超过 0.5 秒强制释放
	_total_time += delta
	if _total_time > 0.5:
		_enter_ready()

## ── 进入激活帧：开 HitBox ──
func _enter_active() -> void:
	_phase = Phase.ACTIVE
	_timer = 0.0
	if hit_box:
		hit_box.monitorable = true
	if hit_box_shape:
		hit_box_shape.disabled = false

## ── 进入后摇：关 HitBox ──
func _enter_recovery() -> void:
	_phase = Phase.RECOVERY
	_timer = 0.0
	if hit_box:
		hit_box.monitorable = false
	if hit_box_shape:
		hit_box_shape.disabled = true

## ── 回到就绪 ──
func _enter_ready() -> void:
	_phase = Phase.READY
	_timer = 0.0
	_can_attack = true

## 是否在攻击动作中（锁移动/其他操作）
func is_attacking() -> bool:
	return _phase != Phase.READY

## 攻击全程锁移动/跳跃/攻击（前摇+激活+后摇）
func is_movement_locked() -> bool:
	return _phase != Phase.READY

## 冷却完毕，可发起攻击
func is_ready() -> bool:
	return _phase == Phase.READY

## 取消当前攻击（受击时调用）
func cancel_attack() -> void:
	_phase = Phase.READY
	_timer = 0.0
	hit_box.set_deferred("monitorable", false)
	hit_box_shape.set_deferred("disabled", true)

## 当前是否处于伤害判定窗口
func is_active() -> bool:
	return _phase == Phase.ACTIVE

## HitBox 位置跟随 AttackPoint（考虑朝向）
func _update_hitbox_position() -> void:
	if not player or not player.sprite:
		return
	var dir := 1.0 if not player.sprite.flip_h else -1.0
	hit_box.position = attack_point.position * Vector2(dir, 1.0)
