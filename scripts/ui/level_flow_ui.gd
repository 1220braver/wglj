extends CanvasLayer
## LevelFlow UI — 开场文字 + 通关文字。

var stage_completed := false

func _ready() -> void:
	$IntroPanel.modulate.a = 0.0
	$IntroPanel.visible = true
	$StageCompletePanel.visible = false
	_play_intro()

func _input(event: InputEvent) -> void:
	if not stage_completed:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		get_tree().reload_current_scene()

func _play_intro() -> void:
	var tween := create_tween()
	tween.tween_property($IntroPanel, "modulate:a", 1.0, 0.5)
	tween.tween_interval(2.0)
	tween.tween_property($IntroPanel, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): $IntroPanel.visible = false)

func show_stage_complete() -> void:
	if stage_completed:
		return
	stage_completed = true

	get_tree().call_group("sfx_bus", "play_sfx", "stage_complete")

	await get_tree().create_timer(1.0).timeout
	$StageCompletePanel.modulate.a = 0.0
	$StageCompletePanel.visible = true
	var tween := create_tween()
	tween.tween_property($StageCompletePanel, "modulate:a", 1.0, 0.5)
