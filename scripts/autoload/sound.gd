extends Node
## Music and sound effects (autoload "Sound"). Volumes come from Settings.

var music: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var streams := {}
var music_volume := 70
var sfx_volume := 80


## Background tracks: "main" (menus, map, lessons) and "battle" (the quiz).
const MUSIC := {"main": "res://assets/audio/music_loop.wav", "battle": "res://assets/audio/music_battle.wav"}

var tracks := {}
var current_music := ""
var _fade: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A missing sound file just means silence, not a crash.
	for n in ["click", "correct", "wrong", "win", "slash", "hit"]:
		var path := "res://assets/audio/sfx_%s.wav" % n
		if ResourceLoader.exists(path):
			streams[n] = load(path)
	for key in MUSIC:
		if ResourceLoader.exists(MUSIC[key]):
			var loop: AudioStreamWAV = load(MUSIC[key])
			loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
			loop.loop_begin = 0
			loop.loop_end = int(loop.get_length() * loop.mix_rate)
			tracks[key] = loop
	music = AudioStreamPlayer.new()
	add_child(music)
	for i in 4:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	apply(int(DB.get_setting("music_volume", "70")), int(DB.get_setting("sfx_volume", "80")))
	play_music("main")


## Switches the background track with a short fade (no-op if already playing).
func play_music(key: String) -> void:
	if key == current_music or not tracks.has(key):
		return
	current_music = key
	if DisplayServer.get_name() == "headless":
		music.stream = tracks[key]
		return
	var target := _music_db()
	if _fade:
		_fade.kill()  # e.g. leaving one quiz straight into another
	var t := create_tween()
	_fade = t
	if music.playing:
		t.tween_property(music, "volume_db", -40.0, 0.4)
	t.tween_callback(func():
		music.stream = tracks[key]
		music.volume_db = -40.0
		music.play())
	t.tween_property(music, "volume_db", target, 0.6)


func apply(music_pct: int, sfx_pct: int) -> void:
	music_volume = clampi(music_pct, 0, 100)
	sfx_volume = clampi(sfx_pct, 0, 100)
	music.volume_db = _music_db()
	music.stream_paused = music_volume == 0
	for p in sfx_players:
		p.volume_db = linear_to_db(maxf(sfx_volume / 100.0, 0.0001))


func _music_db() -> float:
	return linear_to_db(maxf(music_volume / 100.0, 0.0001)) - 6.0


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
