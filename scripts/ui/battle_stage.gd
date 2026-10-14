class_name BattleStage
extends Control
## The duel shown over the quiz scene: the player's hero on the left, the
## language's warrior on the right. A right answer makes the hero strike
## (the warrior plays its HURT animation); a wrong answer makes the warrior
## play its ATTACK animation at the hero.
##
## Warrior animations are strips cut from assets/enemies/<region>/ by
## tools/art/extract_enemy_frames.py:
##   assets/enemies/frames/<language code>_<level>_<idle|attack|hurt>.png

const FRAMES_DIR := "res://assets/enemies/frames/%s_%d_%s.png"
const FPS := {"idle": 6.0, "attack": 10.0, "hurt": 8.0}
const FIGURE_HEIGHT := 0.62   # share of the stage height

var hero: TextureRect
var enemy: AnimatedSprite2D
var enemy_code := ""
var _hero_base := Vector2.ZERO
var _enemy_base := Vector2.ZERO
var _bob: Tween


## Builds the stage for a language and level. region/avatar pick the hero.
func setup(language_code: String, level: int, region: String, avatar: String) -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

	hero = TextureRect.new()
	hero.texture = UI.character_texture(region, avatar)
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hero)

	enemy = AnimatedSprite2D.new()
	enemy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	enemy.flip_h = true  # the sheets face right; the warrior faces the hero
	enemy.centered = false
	var frames := _load_frames(language_code, level, region)
	if frames:
		enemy.sprite_frames = frames
		enemy.play("idle")
	add_child(enemy)
	enemy.animation_finished.connect(func():
		if enemy.sprite_frames and enemy.animation != "idle":
			enemy.play("idle"))

	resized.connect(_layout)
	_layout.call_deferred()


func _layout() -> void:
	var h := size.y * FIGURE_HEIGHT
	var ground := size.y - 6
	var tex := hero.texture
	var hw := h * tex.get_width() / maxf(1.0, tex.get_height()) if tex else h * 0.6
	hero.size = Vector2(hw, h)
	_hero_base = Vector2(size.x * 0.12, ground - h)
	hero.position = _hero_base
	hero.pivot_offset = hero.size / 2
	if enemy.sprite_frames:
		var frame := enemy.sprite_frames.get_frame_texture("idle", 0)
		var scale_f := h / maxf(1.0, frame.get_height())
		enemy.scale = Vector2(scale_f, scale_f)
		var w := frame.get_width() * scale_f
		_enemy_base = Vector2(size.x * 0.88 - w, ground - frame.get_height() * scale_f)
		enemy.position = _enemy_base
	_start_bob()


func _start_bob() -> void:
	if _bob:
		_bob.kill()
	_bob = create_tween().set_loops()
	_bob.tween_property(hero, "position:y", _hero_base.y - 5, 0.6).set_trans(Tween.TRANS_SINE)
	_bob.tween_property(hero, "position:y", _hero_base.y, 0.6).set_trans(Tween.TRANS_SINE)


## Strips for this language, falling back to another warrior of the same
## region (some languages have no sheet yet), then to level 1.
func _load_frames(code: String, level: int, region: String) -> SpriteFrames:
	var candidates: Array = [code]
	for l in DB.get_languages(region):
		if not l.code in candidates:
			candidates.append(l.code)
	for c in candidates:
		for lv in [level, 1]:
			if ResourceLoader.exists(FRAMES_DIR % [c, lv, "idle"]):
				enemy_code = c
				return _build_frames(c, lv)
	return null


func _build_frames(code: String, level: int) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim in ["idle", "attack", "hurt"]:
		var path := FRAMES_DIR % [code, level, anim]
		if not ResourceLoader.exists(path):
			path = FRAMES_DIR % [code, level, "idle"]
		var strip: Texture2D = load(path)
		var cell := strip.get_height()
		sf.add_animation(anim)
		sf.set_animation_loop(anim, anim == "idle")
		sf.set_animation_speed(anim, FPS[anim])
		for i in int(strip.get_width() / cell):
			var at := AtlasTexture.new()
			at.atlas = strip
			at.region = Rect2(i * cell, 0, cell, cell)
			sf.add_frame(anim, at)
	return sf


## Right answer: the hero dashes in and the warrior is hurt.
func hero_strikes() -> void:
	var t := create_tween()
	t.tween_property(hero, "position:x", _hero_base.x + size.x * 0.18, 0.12).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if enemy.sprite_frames:
			enemy.play("hurt")
		_flash(enemy, Color(1.8, 1.8, 1.8)))
	t.tween_property(enemy, "position:x", _enemy_base.x + 14, 0.08)
	t.tween_property(enemy, "position:x", _enemy_base.x, 0.15)
	t.parallel().tween_property(hero, "position:x", _hero_base.x, 0.25).set_trans(Tween.TRANS_SINE)


## Wrong answer: the warrior attacks and the hero takes the hit.
func enemy_strikes() -> void:
	if enemy.sprite_frames:
		enemy.play("attack")
	var t := create_tween()
	t.tween_property(enemy, "position:x", _enemy_base.x - size.x * 0.18, 0.18).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		_flash(hero, Color(1.8, 0.4, 0.4))
		_shake(hero))
	t.tween_interval(0.15)
	t.tween_property(enemy, "position:x", _enemy_base.x, 0.25).set_trans(Tween.TRANS_SINE)


## End of the quiz: the loser fades out.
func finish(passed: bool) -> void:
	var loser: CanvasItem = enemy if passed else hero
	create_tween().tween_property(loser, "modulate:a", 0.0, 0.5)


func _flash(node: CanvasItem, color: Color) -> void:
	node.modulate = color
	create_tween().tween_property(node, "modulate", Color.WHITE, 0.3)


func _shake(node: Control) -> void:
	var t := create_tween()
	for dx in [-8, 8, -5, 5, 0]:
		t.tween_property(node, "position:x", _hero_base.x + dx, 0.04)
