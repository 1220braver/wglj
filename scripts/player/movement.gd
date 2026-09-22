extends Node
## 移动层 — 处理重力、跳跃、水平移动。
## 所有数值从 Player 的 @export 属性读取，本组件不持有参数。

var player: CharacterBody2D

## ── 内部状态 ──
var _gravity: float

func _ready() -> void:
	player = get_parent() as CharacterBody2D
	_gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

## 重力 — 始终调用（包括攻击期间），防止空中滞空
func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		player.velocity.y += _gravity * delta
		player.velocity.y = minf(player.velocity.y, player.max_fall_speed)

## 跳跃 — 仅在非锁定状态调用
func apply_jump(want_jump: bool) -> void:
	if want_jump and player.is_on_floor():
		player.velocity.y = player.jump_velocity

## 水平移动 — 仅在非锁定状态调用
func apply_horizontal(delta: float, input_dir: float) -> void:
	var target: float = input_dir * player.speed * player.move_speed_modifier
	if not player.is_on_floor():
		target *= player.air_control

	var rate: float = player.acceleration if input_dir != 0.0 else player.deceleration
	player.velocity.x = move_toward(player.velocity.x, target, rate * delta)
