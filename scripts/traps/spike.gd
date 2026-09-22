extends Area2D
## Spike — 尖刺陷阱，接触扣血 + 轻微击退。

@export var damage: int = 20
@export var knockback_force: float = 200.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		# 轻微击退：往上弹出
		if body is CharacterBody2D:
			body.velocity.y = -knockback_force * 0.6
			body.velocity.x = sign(body.global_position.x - global_position.x) * knockback_force * 0.3

func _draw() -> void:
	var w := 32.0
	var h := 16.0
	# 四个三角形尖刺
	for i in range(4):
		var x := i * 8.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, h), Vector2(x + 4, 0), Vector2(x + 8, h)
		]), Color(0.4, 0.4, 0.4))
	# 底座
	draw_rect(Rect2(0, h - 4, w, 4), Color(0.3, 0.3, 0.3))
