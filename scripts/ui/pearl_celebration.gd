class_name PearlCelebration
extends Control
## Full-screen animation when an island's pearl lights up: the dormant grey
## pearl rises, flashes and lights up in the island's colour, light rays
## turn behind it, rings of light spread out and sparkles burst. Tap
## CONTINUE (or the back key) to close it.
##
## badge is "core_luzon", "core_visayas", "core_mindanao" or "pearl" (all
## three restored: the Pearl of the Orient).

signal finished

const PEARL_OF_THE_ORIENT := Color("fdf8ec")

var badge := ""
var pearl: PearlOrb
var _rays_angle := 0.0
var _ring := 0.0
var _rays_alpha := 0.0
var _color := Color.WHITE


static func play(parent: Node, badge_code: String) -> PearlCelebration:
	var c := PearlCelebration.new()
	c.badge = badge_code
	c.name = "PearlCelebration"
	var layer := CanvasLayer.new()
	layer.layer = 45
	parent.add_child(layer)
	layer.add_child(c)
	return c


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var region := badge.trim_prefix("core_")
	var is_orient := badge == "pearl"
	_color = PEARL_OF_THE_ORIENT if is_orient else UI.REGION_COLORS.get(region, UI.GOLD)
	Game.overlays.append(self)
	tree_exiting.connect(func(): finished.emit())  # also when the back key closes it

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 22)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)

	var holder := CenterContainer.new()
	holder.custom_minimum_size = Vector2(0, 300)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(holder)
	pearl = PearlOrb.make(_color, false, 230 if is_orient else 200)
	pearl.name = "Pearl"
	holder.add_child(pearl)

	var title := UI.label(_title(region, is_orient), 38, Color("ffe08a"), true, UI.font_title)
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_outline_color", Color("3b2208"))
	title.add_theme_constant_override("outline_size", 12)
	title.modulate.a = 0.0
	col.add_child(title)
	var sub := UI.label(_subtitle(region, is_orient), 21, UI.WHITE, true, UI.font_body_black)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	sub.add_theme_constant_override("outline_size", 8)
	sub.modulate.a = 0.0
	col.add_child(sub)
	var box := CenterContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(box)
	var cont := UI.gem_button(UI.t("next") if UI.lang == "fil" else "CONTINUE", "gold", close, 96, 36)
	cont.name = "continue"
	cont.custom_minimum_size.x = 380
	cont.modulate.a = 0.0
	box.add_child(cont)

	_play(title, sub, cont)


func _title(region: String, is_orient: bool) -> String:
	if is_orient:
		return "The Pearl of the Orient shines!"
	return "%s restored!" % DB.get_region(region).get("core_name", region.capitalize() + " Pearl")


func _subtitle(region: String, is_orient: bool) -> String:
	if is_orient:
		return "All three island pearls are lit. You are a true Language Guardian of the Philippines!"
	var names: Array = []
	for l in DB.get_languages(region):
		if int(l.playable) == 1:
			names.append(l.name)
	return "You mastered every language of %s: %s." % [DB.get_region(region).get("name", region), ", ".join(names)]


func _play(title: Control, sub: Control, cont: Control) -> void:
	Sound.play("win")
	pearl.pivot_offset = pearl.custom_minimum_size / 2
	pearl.scale = Vector2(0.2, 0.2)
	pearl.modulate.a = 0.0
	var t := create_tween()
	# 1. The dark backdrop fades in and the dormant pearl rises.
	t.tween_property(self, "_rays_alpha", 0.0, 0.01)
	t.parallel().tween_property(pearl, "modulate:a", 1.0, 0.35)
	t.parallel().tween_property(pearl, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 2. It flickers... and lights up.
	t.tween_property(pearl, "light", 0.35, 0.15)
	t.tween_property(pearl, "light", 0.05, 0.12)
	t.tween_property(pearl, "light", 0.6, 0.15)
	t.tween_property(pearl, "light", 0.2, 0.1)
	t.tween_callback(func():
		_burst()
		Sound.play("correct"))
	t.tween_property(pearl, "light", 1.0, 0.35)
	t.parallel().tween_property(pearl, "scale", Vector2(1.25, 1.25), 0.2).set_trans(Tween.TRANS_SINE)
	t.parallel().tween_property(self, "_rays_alpha", 1.0, 0.5)
	t.parallel().tween_property(self, "_ring", 1.0, 1.1).set_ease(Tween.EASE_OUT)
	t.tween_property(pearl, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)
	# 3. The words appear.
	t.tween_property(title, "modulate:a", 1.0, 0.35)
	t.tween_property(sub, "modulate:a", 1.0, 0.35)
	t.tween_property(cont, "modulate:a", 1.0, 0.3)
	# The pearl keeps bobbing gently.
	var bob := create_tween().set_loops()
	bob.tween_property(pearl, "position:y", -8.0, 1.2).set_trans(Tween.TRANS_SINE).set_delay(2.0)
	bob.tween_property(pearl, "position:y", 0.0, 1.2).set_trans(Tween.TRANS_SINE)


## Sparkles bursting out of the pearl.
func _burst() -> void:
	var p := CPUParticles2D.new()
	p.name = "Sparkles"
	p.amount = 90
	p.one_shot = true
	p.explosiveness = 0.9
	p.lifetime = 1.6
	p.direction = Vector2(0, -1)
	p.spread = 180.0
	p.initial_velocity_min = 180.0
	p.initial_velocity_max = 420.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 0.95, 0.6, 1))
	ramp.set_color(1, Color(_color.lightened(0.4), 0))
	p.color_ramp = ramp
	p.position = pearl.get_global_rect().get_center() - get_global_rect().position
	add_child(p)
	p.emitting = true


func _process(_delta: float) -> void:
	_rays_angle += _delta * 0.35
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.02, 0.08, 0.86))
	if not is_instance_valid(pearl):
		return
	var c := pearl.get_global_rect().get_center() - get_global_rect().position
	var reach := size.length()
	# Turning light rays.
	if _rays_alpha > 0.0:
		var rays := 14
		for i in rays:
			var a := _rays_angle + TAU * i / rays
			var w := 0.09
			var pts := PackedVector2Array([c, c + Vector2(cos(a - w), sin(a - w)) * reach, c + Vector2(cos(a + w), sin(a + w)) * reach])
			draw_colored_polygon(pts, Color(_color.lightened(0.5), 0.10 * _rays_alpha))
	# Rings of light spreading out once.
	if _ring > 0.0 and _ring < 1.0:
		for k in 3:
			var rr := (_ring - k * 0.15) * reach * 0.6
			if rr > 0:
				draw_arc(c, rr, 0, TAU, 96, Color(_color.lightened(0.4), (1.0 - _ring) * 0.8), 6.0)


func close() -> void:
	Game.overlays.erase(self)
	if is_instance_valid(get_parent()):
		get_parent().queue_free()
