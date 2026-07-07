extends Area2D
## KillZone — 掉出地图即死，重生回出生点。

@export var spawn_point: Marker2D

func _ready() -> void:
	monitoring = true
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("respawn"):
		body.respawn()
	elif body.has_method("take_damage"):
		body.take_damage(9999)
		body.global_position = spawn_point.global_position if spawn_point else Vector2.ZERO
