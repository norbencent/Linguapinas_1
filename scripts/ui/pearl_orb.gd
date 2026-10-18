class_name PearlOrb
extends Control
## An island's pearl, drawn as a glossy sphere. Dormant pearls are grey;
## lit pearls glow in the island's colour and slowly shimmer.

var color := Color.WHITE
var lit := false
## 0 = dormant grey, 1 = fully lit. Tweened by the celebration.
var light := 0.0:
	set(v):
		light = v
		queue_redraw()
var _time := 0.0

const DORMANT := Color("8d8170")


static func make(pearl_color: Color, is_lit: bool, diameter: float) -> PearlOrb:
	var o := PearlOrb.new()
	o.color = pearl_color
	o.lit = is_lit
	o.light = 1.0 if is_lit else 0.0
	o.custom_minimum_size = Vector2(diameter, diameter)
	o.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	o.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return o


func _process(delta: float) -> void:
	if light > 0.0:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var c := size / 2.0
	var r := minf(size.x, size.y) / 2.0
	var body := DORMANT.lerp(color, light)
	# Glow: soft rings that breathe while lit.
	if light > 0.0:
		var breathe := 0.5 + 0.5 * sin(_time * 2.4)
		for i in 6:
			var t := float(i) / 6.0
			draw_circle(c, r * (1.15 + 0.55 * t + 0.08 * breathe), Color(color.lightened(0.3), 0.16 * light * (1.0 - t)))
	# Rim, body and shading.
	draw_circle(c, r, Color("f6d36b").lerp(Color("5f5446"), 1.0 - light))
	draw_circle(c, r * 0.9, body.darkened(0.35))
	for i in 8:
		var t := float(i) / 8.0
		draw_circle(c - Vector2(r, r) * 0.12 * t, r * 0.9 * (1.0 - t * 0.55), body.lightened(0.06 * i))
	# Highlights.
	draw_circle(c + Vector2(-r * 0.32, -r * 0.34), r * 0.2, Color(1, 1, 1, 0.55 + 0.3 * light))
	draw_circle(c + Vector2(-r * 0.12, -r * 0.5), r * 0.07, Color(1, 1, 1, 0.7))
	# A slow sparkle crossing the lit pearl.
	if light > 0.6:
		var a := fmod(_time * 0.8, TAU)
		var p := c + Vector2(cos(a), sin(a) * 0.5) * r * 0.55
		var s := r * 0.16 * (0.6 + 0.4 * sin(_time * 5.0))
		draw_line(p - Vector2(s, 0), p + Vector2(s, 0), Color(1, 1, 1, 0.8), 2.0)
		draw_line(p - Vector2(0, s), p + Vector2(0, s), Color(1, 1, 1, 0.8), 2.0)
