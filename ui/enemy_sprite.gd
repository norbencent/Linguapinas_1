class_name EnemySprite
extends Control
## Animated enemy warrior for the quiz scene.
## Plays the strips made by tools/art/extract_enemy_sprites.py from
## assets/ui/enemies/<language>/<difficulty>_<animation>.png (square frames
## side by side). Animations: idle (loops), attack, hurt and die.

signal animation_finished(anim: String)

const FPS := {"idle": 6.0, "attack": 10.0, "hurt": 8.0, "die": 6.0}

var strips := {}          # animation name -> Texture2D
var anim := ""
var frame := 0
var frame_count := 1
var looping := true
var flip := false          # true: faces left (towards the hero)
var _time := 0.0
var _tint := Color.WHITE
var _shake: Tween
var _base_x := NAN


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


## Loads the strips for [param language_code] at [param difficulty].
## Returns false when the language has no enemy sprite sheet.
func setup(language_code: String, difficulty: int) -> bool:
	strips.clear()
	for a in FPS:
		var path := "res://assets/ui/enemies/%s/%d_%s.png" % [language_code, difficulty, a]
		if ResourceLoader.exists(path):
			strips[a] = load(path)
	if strips.has("idle"):
		play("idle")
	return strips.has("idle")


func has_animation(a: String) -> bool:
	return strips.has(a)


func play(a: String, loop := false) -> void:
	if not strips.has(a):
		# No strip for this animation: fake it on the idle frames.
		match a:
			"hurt":
				_flash(Color(1.6, 0.5, 0.5))
				if _shake != null:
					_shake.kill()
				if is_nan(_base_x):
					_base_x = position.x
				position.x = _base_x
				_shake = create_tween()
				for dx in [-12.0, 12.0, -8.0, 8.0, 0.0]:
					_shake.tween_property(self, "position:x", _base_x + dx, 0.05)
				_shake.tween_callback(func(): animation_finished.emit(a))
			"die":
				var tw := create_tween()
				tw.tween_property(self, "modulate:a", 0.0, 0.6)
				tw.tween_callback(func(): animation_finished.emit(a))
			_:
				animation_finished.emit(a)
		return
	anim = a
	looping = loop or a == "idle"
	frame = 0
	_time = 0.0
	var t: Texture2D = strips[a]
	frame_count = maxi(1, roundi(float(t.get_width()) / t.get_height()))
	if a == "hurt":
		_flash(Color(1.5, 0.7, 0.7))
	queue_redraw()


func _flash(c: Color) -> void:
	_tint = c
	var tw := create_tween()
	tw.tween_method(func(v: Color):
		_tint = v
		queue_redraw(), c, Color.WHITE, 0.35)


func _process(delta: float) -> void:
	if anim == "":
		return
	_time += delta
	var step: float = 1.0 / float(FPS.get(anim, 8.0))
	while _time >= step:
		_time -= step
		frame += 1
		if frame >= frame_count:
			if looping:
				frame = 0
			else:
				frame = frame_count - 1
				var done := anim
				if done != "die":
					play("idle")
				animation_finished.emit(done)
				break
		queue_redraw()


func _draw() -> void:
	if anim == "" or not strips.has(anim):
		return
	var t: Texture2D = strips[anim]
	var h := float(t.get_height())
	var side := minf(size.x, size.y)
	var dst := Rect2((size.x - side) / 2.0, size.y - side, side, side)
	if flip:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect_region(t, dst, Rect2(frame * h, 0, h, h), _tint)
	draw_set_transform(Vector2.ZERO)
