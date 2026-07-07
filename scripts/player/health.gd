extends Node
## 生命层 — HP 管理、受伤、治疗、死亡判定 + 无敌帧。

var player: CharacterBody2D
var _invincible: bool = false

func _ready() -> void:
	player = get_parent() as CharacterBody2D

func take_damage(amount: int) -> bool:
	if player.current_hp <= 0:
		return false
	if _invincible:
		return false

	var anim = player.get_node("Animation")
	var real := maxi(amount - player.defense, 1)
	player.current_hp = maxi(player.current_hp - real, 0)

	if player.current_hp <= 0:
		anim.trigger_dead()
		_die_then_respawn()
		return false

	anim.trigger_hurt()
	_start_invincible()
	get_tree().call_group("sfx_bus", "play_sfx", "player_hurt")
	return true

func heal(amount: int) -> void:
	player.current_hp = mini(player.current_hp + amount, player.max_hp)

func is_alive() -> bool:
	return player.current_hp > 0

func is_invincible() -> bool:
	return _invincible

## ── 死亡 1 秒后重生 ──
func _die_then_respawn() -> void:
	await player.get_tree().create_timer(1.0).timeout
	if not is_instance_valid(player):
		return
	player.respawn()

## ── 0.6 秒无敌 ──
func _start_invincible() -> void:
	_invincible = true
	await player.get_tree().create_timer(0.6).timeout
	_invincible = false
