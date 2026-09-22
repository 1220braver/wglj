extends Node2D
## EffectSpawner — 粒子效果生成器。通过 group "effect_spawner" 调用。

func _ready() -> void:
	add_to_group("effect_spawner")

func spawn_effect(effect_name: String, pos: Vector2) -> void:
	match effect_name:
		"hit_spark":
			_spawn(pos, Color.WHITE, Color.YELLOW, 8, 120.0, 0.2)
		"boss_hit_spark":
			_spawn(pos, Color.WHITE, Color.ORANGE, 14, 180.0, 0.3)
		"death_dust":
			_spawn(pos, Color(0.5, 0.4, 0.3), Color(0.3, 0.25, 0.2), 12, 80.0, 0.4)
		"slam_dust":
			_spawn(pos, Color(0.5, 0.45, 0.3), Color(0.3, 0.25, 0.15), 25, 200.0, 0.5)
		"boss_death":
			_spawn(pos, Color(0.8, 0.7, 0.6), Color(0.6, 0.1, 0.1), 32, 250.0, 0.8)
		"landing_dust":
			_spawn(pos, Color(0.5, 0.45, 0.4), Color(0.3, 0.3, 0.3), 6, 60.0, 0.2)
		_:
			push_warning("EffectSpawner: unknown effect '%s'" % effect_name)

func _spawn(pos: Vector2, color_a: Color, color_b: Color, count: int, speed: float, lifetime: float) -> void:
	for i in range(count):
		var p := _create_particle(pos, color_a, color_b, speed, lifetime)
		add_child(p)

func _create_particle(pos: Vector2, color_a: Color, color_b: Color, speed: float, lifetime: float) -> Node2D:
	var p := Node2D.new()
	p.position = pos

	var angle := randf_range(0, TAU)
	var dist := randf_range(speed * 0.3, speed)
	p.position += Vector2.RIGHT.rotated(angle) * 2.0

	var s := ColorRect.new()
	s.color = color_a.lerp(color_b, randf())
	var sz := randf_range(2.0, 5.0)
	s.size = Vector2(sz, sz)
	s.position = -s.size / 2.0
	p.add_child(s)

	var tween := create_tween()
	tween.set_parallel()
	var end := pos + Vector2.RIGHT.rotated(angle) * dist
	tween.tween_property(p, "position", end, lifetime).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(s, "modulate:a", 0.0, lifetime)
	tween.tween_property(s, "scale", Vector2(0.2, 0.2), lifetime)
	tween.chain().tween_callback(p.queue_free)

	return p
