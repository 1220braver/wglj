extends Node
## SFXBus — 集中音效播放。通过 group "sfx_bus" 调用。

const SFX_PATH := "res://assets/audio/sfx"
var _players := {}
var _last_play := {}

func _ready() -> void:
	add_to_group("sfx_bus")

func play_sfx(name: String) -> void:
	var player = _players.get(name)
	if not player:
		var path := "%s/%s.wav" % [SFX_PATH, name]
		if not FileAccess.file_exists(path):
			push_warning("SFXBus: no file '%s'" % path)
			return
		var stream = load(path)
		if not stream:
			return
		player = AudioStreamPlayer.new()
		player.name = name
		player.stream = stream
		player.volume_db = -6.0
		add_child(player)
		_players[name] = player
	player.play()
