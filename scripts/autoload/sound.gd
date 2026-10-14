extends Node
## Music and sound effects (autoload "Sound"). Volumes come from Settings.

var music: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var streams := {}
var music_volume := 70
var sfx_volume := 80

const MUSIC_PATH := "res://assets/audio/music_loop.wav"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for n in ["click", "correct", "wrong", "win"]:
		var path := "res://assets/audio/sfx_%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	music = AudioStreamPlayer.new()
	if ResourceLoader.exists(MUSIC_PATH):
		var loop: AudioStreamWAV = load(MUSIC_PATH)
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		music.stream = loop
	add_child(music)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	apply(int(DB.get_setting("music_volume", "70")), int(DB.get_setting("sfx_volume", "80")))
	if music.stream and DisplayServer.get_name() != "headless":
		music.play()


func apply(music_pct: int, sfx_pct: int) -> void:
	music_volume = clampi(music_pct, 0, 100)
	sfx_volume = clampi(sfx_pct, 0, 100)
	music.volume_db = linear_to_db(maxf(music_volume / 100.0, 0.0001)) - 6.0
	music.stream_paused = music_volume == 0
	for p in sfx_players:
		p.volume_db = linear_to_db(maxf(sfx_volume / 100.0, 0.0001))


func play(name: String) -> void:
	if sfx_volume == 0 or not streams.has(name):
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = streams[name]
			p.play()
			return


func click() -> void:
	play("click")
