class_name GemButton
extends Button
## Glossy gem button from the LinguaPinas prototype art.
## The diamond caps keep their shape; only the middle stretches.

const CAP := 0.215  # fraction of the texture width used by each diamond cap

var tex: Texture2D
var label := ""
var font_size := 34


func _init() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	text = ""


func _draw() -> void:
	if tex == null:
		return
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var s := size.y / th
	var cap_src := tw * CAP
	var cap_dst := minf(cap_src * s, size.x / 2.0)
	var m := Color.WHITE
	match get_draw_mode():
		DRAW_PRESSED, DRAW_HOVER_PRESSED:
			m = Color(0.8, 0.8, 0.8)
		DRAW_HOVER:
			m = Color(1.08, 1.08, 1.08)
		DRAW_DISABLED:
			m = Color(0.5, 0.5, 0.5)
	draw_texture_rect_region(tex, Rect2(0, 0, cap_dst, size.y), Rect2(0, 0, cap_src, th), m)
	draw_texture_rect_region(tex, Rect2(size.x - cap_dst, 0, cap_dst, size.y), Rect2(tw - cap_src, 0, cap_src, th), m)
	draw_texture_rect_region(tex, Rect2(cap_dst, 0, size.x - 2 * cap_dst, size.y),
		Rect2(cap_src, 0, tw - 2 * cap_src, th), m)

	var font: Font = UI.font_button
	var fs := font_size
	var room := size.x - 2 * cap_dst * 0.9
	while fs > 14 and font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
		fs -= 2
	var y := (size.y + font.get_ascent(fs) - font.get_descent(fs)) / 2.0 - size.y * 0.02
	var outline := Color("3b2208") if get_draw_mode() != DRAW_DISABLED else Color("444444")
	draw_string_outline(font, Vector2(0, y), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, maxi(6, fs / 5), outline)
	draw_string(font, Vector2(0, y), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, fs, Color.WHITE if not disabled else Color(0.85, 0.85, 0.85))
