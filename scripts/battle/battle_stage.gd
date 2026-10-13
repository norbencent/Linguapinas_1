extends TextureRect
## The quiz battle: the player's hero (left) against the language's warrior
## (right). A right answer makes the hero attack, a wrong one lets the
## warrior strike back.

const Frames = preload("res://scripts/battle/sprite_frames.gd")
const SheetSprite = preload("res://scripts/battle/sheet_sprite.gd")
const SHEET_DIR := "res://assets/ui/"

var player: Control        # SheetSprite, or a plain TextureRect without a sheet
var enemy: Control
var enemy_bar: ProgressBar
var enemy_name: Label
var busy := false

var _player_home := Vector2.ZERO
var _enemy_home := Vector2.ZERO
var _fx_layer: Control


func setup(region: String, avatar: String, language: Dictionary, difficulty: int, enemy_hp: int) -> void:
	clip_contents = true
	_fx_layer = Control.new()
	_fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE

	player = _make_player(region, avatar)
	add_child(player)
	enemy = _make_enemy(str(language.get("code", "")), difficulty)
	if enemy != null:
		add_child(enemy)
		var plate := UI.vbox(2)
		plate.name = "EnemyPlate"
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		enemy_name = UI.label("%s %s" % [Game.difficulty_name(difficulty), language.get("name", "")],
			16, Color.WHITE, false, UI.font_body_black)
		enemy_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		enemy_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		enemy_name.add_theme_constant_override("outline_size", 5)
		plate.add_child(enemy_name)
		enemy_bar = ProgressBar.new()
		enemy_bar.show_percentage = false
		enemy_bar.custom_minimum_size = Vector2(150, 12)
		enemy_bar.max_value = maxi(1, enemy_hp)
		enemy_bar.value = enemy_bar.max_value
		var fill := UI._box(Color("e0242c"), 6, Color.TRANSPARENT, 0, 0)
		var back := UI._box(Color(0, 0, 0, 0.55), 6, Color("f3dc84"), 2, 0)
		enemy_bar.add_theme_stylebox_override("fill", fill)
		enemy_bar.add_theme_stylebox_override("background", back)
		plate.add_child(enemy_bar)
		add_child(plate)
	add_child(_fx_layer)
	resized.connect(_layout)
	_layout()


func _make_player(region: String, avatar: String) -> Control:
	var frames: Dictionary = Frames.HEROES.get(region, Frames.HEROES.luzon).get(avatar, {})
	var path: String = Frames.HERO_SHEETS.get(region, Frames.HERO_SHEETS.luzon)
	if not frames.is_empty() and ResourceLoader.exists(path):
		var s := SheetSprite.new()
		s.setup(load(path), frames)
		return s
	# No sheet: fall back to the still portrait.
	var t := TextureRect.new()
	t.texture = UI.character_texture(region, avatar)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _make_enemy(code: String, difficulty: int) -> Control:
	if not Frames.ENEMIES.has(code):
		return null
	var entry: Dictionary = Frames.ENEMIES[code]
	var path: String = SHEET_DIR + entry.sheet
	if not ResourceLoader.exists(path):
		return null
	var levels: Array = entry.levels
	var s := SheetSprite.new()
	s.setup(load(path), levels[clampi(difficulty - 1, 0, levels.size() - 1)], true)
	s.flip = true  # the warriors are drawn facing right; face the hero
	return s


func _layout() -> void:
	var h := size.y
	var w := size.x
	var body := Vector2(w * 0.34, h * 0.62)
	_player_home = Vector2(w * 0.07, h - body.y - h * 0.06)
	_enemy_home = Vector2(w * 0.59, h - body.y - h * 0.06)
	if player:
		player.size = body
		player.position = _player_home
	if enemy:
		enemy.size = body
		enemy.position = _enemy_home
		var plate: Control = get_node_or_null("EnemyPlate")
		if plate:
			plate.size = Vector2(body.x, 0)
			plate.position = Vector2(_enemy_home.x, maxf(4, _enemy_home.y - 40))


## Right answer: the hero dashes in and strikes. `label` floats over the warrior.
func player_attack(label: String, enemy_hp_left: int, defeated := false) -> void:
	if enemy == null:
		_float_text(label, player.position + Vector2(player.size.x / 2, 0), Color("ffe27a"))
		return
	_strike(player, enemy, _player_home, _enemy_home, 1.0, func():
		_hit(enemy)
		_float_text(label, enemy.position + Vector2(enemy.size.x / 2, 10), Color("ffe27a"))
		_tween_bar(enemy_hp_left),
		func():
			if defeated:
				_fall(enemy))


## Wrong answer: the warrior rushes the hero; the hero loses a heart.
func enemy_attack(knocked_out := false) -> void:
	var on_hit := func():
		_hit(player)
		_float_text("-1 ♥", player.position + Vector2(player.size.x / 2, 10), Color("ff5a5a"))
	var after := func():
		if knocked_out:
			_fall(player)
	if enemy == null:
		on_hit.call()
		after.call()
		return
	_strike(enemy, player, _enemy_home, _player_home, -1.0, on_hit, after)


func _strike(attacker: Control, target: Control, from: Vector2, to: Vector2, dir: float,
		on_impact: Callable, on_done: Callable) -> void:
	if busy:
		# Still busy with the last exchange: land this one at once.
		on_impact.call()
		on_done.call()
		return
	busy = true
	attacker.z_index = 1
	target.z_index = 0
	var reach := to + Vector2(-dir * size.x * 0.2, 0)
	var t := create_tween()
	t.tween_property(attacker, "position", reach, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_callback(func():
		if attacker.has_method("play") and attacker.has_animation("attack"):
			var frames: int = attacker.animations.attack.size()
			attacker.impact.connect(func(_a): on_impact.call(), CONNECT_ONE_SHOT)
			attacker.play("attack", clampf(frames / 0.75, 8.0, 16.0), false, 0.55)
		else:
			_lunge(attacker, dir)
			on_impact.call())
	t.tween_interval(0.8)
	t.tween_property(attacker, "position", from, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(func():
		attacker.z_index = 0
		busy = false
		on_done.call())


func _lunge(node: Control, dir: float) -> void:
	var t := create_tween()
	t.tween_property(node, "rotation", deg_to_rad(10 * dir), 0.08)
	t.tween_property(node, "rotation", 0.0, 0.15)


func _hit(target: Control) -> void:
	if target.has_method("play") and target.has_animation("hurt"):
		target.play("hurt", 10.0, false)
	var t := create_tween()
	target.modulate = Color(1, 0.35, 0.35)
	t.tween_property(target, "modulate", Color.WHITE, 0.35)
	var home := target.position
	var shake := create_tween()
	for i in 4:
		shake.tween_property(target, "position:x", home.x + (8 if i % 2 == 0 else -8), 0.04)
	shake.tween_property(target, "position:x", home.x, 0.04)
	_slash(target.position + target.size / 2)


func _slash(at: Vector2) -> void:
	var fx := Control.new()
	fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx.position = at
	fx.draw.connect(func():
		for i in 3:
			var off := Vector2(-6 + i * 6, -6 + i * 6)
			fx.draw_line(Vector2(-40, -30) + off, Vector2(40, 30) + off, Color(1, 1, 0.85, 0.9), 4.0 - i, true))
	_fx_layer.add_child(fx)
	fx.scale = Vector2(0.3, 0.3)
	var t := create_tween()
	t.tween_property(fx, "scale", Vector2(1.2, 1.2), 0.12)
	t.parallel().tween_property(fx, "modulate:a", 0.0, 0.3).set_delay(0.08)
	t.tween_callback(fx.queue_free)


func _float_text(text: String, at: Vector2, color: Color) -> void:
	var l := UI.label(text, 30, color, false, UI.font_body_black)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fx_layer.add_child(l)
	l.reset_size()
	l.position = at - Vector2(l.size.x / 2, l.size.y)
	var t := create_tween()
	t.tween_property(l, "position:y", l.position.y - 50, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	t.tween_callback(l.queue_free)


func _tween_bar(value: int) -> void:
	if enemy_bar:
		create_tween().tween_property(enemy_bar, "value", float(value), 0.3)


func _fall(node: Control) -> void:
	var t := create_tween()
	t.tween_property(node, "modulate", Color(1, 1, 1, 0), 0.6)
	t.parallel().tween_property(node, "position:y", node.position.y + 30, 0.6)
