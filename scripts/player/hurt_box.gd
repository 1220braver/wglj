extends Area2D
## HurtBox — 统一受伤判定层。Hit Stop + Camera Shake + Knockback。

@export var knockback_speed: float = 150.0
@export var knockback_duration: float = 0.12
@export var knockback_decay: float = 900.0
@export var hit_stop_duration: float = 0.04
@export var camera_shake_px: float = 2.0
@export var camera_shake_duration: float = 0.08

var _knockback_timer: float = 0.0
var _knockback_dir: Vector2 = Vector2.ZERO
var _knockback_current_speed: float = 0.0

func _ready() -> void:
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)

func _physics_process(delta: float) -> void:
	if _knockback_timer <= 0.0:
		return
	_knockback_timer -= delta
	_knockback_current_speed = maxf(_knockback_current_speed - knockback_decay * delta, 0.0)
	var owner_node = get_parent()
	if owner_node is CharacterBody2D:
		owner_node.velocity = _knockback_dir * _knockback_current_speed
	elif owner_node is RigidBody2D:
		owner_node.linear_velocity = _knockback_dir * _knockback_current_speed

func _on_area_entered(hit_box: Area2D) -> void:
	var attacker = hit_box.get_parent()
	if attacker == get_parent():
		return
	var attack_comp = attacker.get_node_or_null("Attack")
	if not attack_comp:
		return

	var damage: int = attack_comp.get("damage")
	var owner_node = get_parent()

	if owner_node.has_method("take_damage"):
		owner_node.take_damage(damage)

	# 命中音效
	var sfx_name := "hit_enemy"
	if owner_node.is_in_group("boss"):
		sfx_name = "hit_boss"
	get_tree().call_group("sfx_bus", "play_sfx", sfx_name)

	_knockback_dir = (owner_node.global_position - attacker.global_position).normalized()
	_knockback_timer = knockback_duration
	_knockback_current_speed = knockback_speed

	# Hit Stop — 暂时禁用，避免卡死
	# Engine.time_scale = 0.0
	# get_tree().create_timer(hit_stop_duration, true, false, true).timeout.connect(_restore_time_scale)

	_shake_camera()

func _restore_time_scale() -> void:
	Engine.time_scale = 1.0

func _shake_camera() -> void:
	var cameras := get_tree().root.find_children("*", "Camera2D", true, false)
	if cameras.is_empty():
		return
	var cam: Camera2D = cameras[0]
	var original_offset := cam.offset
	var tween := cam.create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	for i in range(6):
		var x := randf_range(-camera_shake_px, camera_shake_px)
		var y := randf_range(-camera_shake_px, camera_shake_px)
		tween.tween_property(cam, "offset", Vector2(x, y), camera_shake_duration / 6.0)
	tween.tween_property(cam, "offset", original_offset, 0.01)
