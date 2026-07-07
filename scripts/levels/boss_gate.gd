extends StaticBody2D
## BossGate — 石门，占位绘制。

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	# 门框
	draw_rect(Rect2(0, -96, 32, 96), Color(0.35, 0.3, 0.25), true)
	draw_rect(Rect2(0, -96, 32, 96), Color(0.5, 0.45, 0.4), false)

	# 中间竖线（双开）
	draw_line(Vector2(16, -88), Vector2(16, -8), Color(0.3, 0.25, 0.2), 2)

	# 锁链
	for y in range(-80, -30, 12):
		draw_circle(Vector2(16, y), 3, Color(0.45, 0.4, 0.35))
		draw_circle(Vector2(10, y + 5), 2.5, Color(0.45, 0.4, 0.35))
		draw_circle(Vector2(22, y + 5), 2.5, Color(0.45, 0.4, 0.35))

	# 锁
	draw_rect(Rect2(12, -36, 8, 12), Color(0.55, 0.5, 0.2), true)
	draw_circle(Vector2(16, -30), 4, Color(0.65, 0.6, 0.3))

	# 铆钉
	draw_circle(Vector2(6, -90), 2, Color(0.4, 0.35, 0.3))
	draw_circle(Vector2(26, -90), 2, Color(0.4, 0.35, 0.3))
