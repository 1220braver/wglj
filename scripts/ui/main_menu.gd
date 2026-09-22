extends Control
## MainMenu — 最简单的开始菜单。

func _ready() -> void:
	# 确保从暂停状态恢复
	get_tree().paused = false

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/levels/level_01.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
