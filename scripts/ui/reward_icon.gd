class_name RewardIcon
extends Control
## A reward drawn in code so it stays sharp at any size:
## - Word Fragment: a torn blue parchment shard with a letter on it.
## - Phrase Crystal: a faceted purple gem.
## - Cultural Relic: an amber amulet.

var kind := "word_fragment"


static func make(reward_kind: String, diameter: float) -> RewardIcon:
	var icon := RewardIcon.new()
	icon.kind = reward_kind
	icon.custom_minimum_size = Vector2(diameter, diameter)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) / 2.0
	var p := func(x: float, y: float) -> Vector2: return o + Vector2(x, y) * s
	var base: Color = UI.REWARD_COLORS.get(kind, UI.GOLD)
	var outline := Color("3b200c")
	# Soft golden glow behind every reward.
	draw_circle(o + Vector2(s, s) / 2.0, s * 0.48, Color(UI.GOLD, 0.22))
	match kind:
		"word_fragment":
			var shard := PackedVector2Array([p.call(0.22, 0.14), p.call(0.62, 0.08), p.call(0.70, 0.22),
				p.call(0.84, 0.30), p.call(0.80, 0.56), p.call(0.88, 0.80), p.call(0.56, 0.90),
				p.call(0.44, 0.82), p.call(0.18, 0.88), p.call(0.24, 0.60), p.call(0.12, 0.40)])
			draw_colored_polygon(shard, base)
			draw_colored_polygon(PackedVector2Array([p.call(0.22, 0.14), p.call(0.62, 0.08), p.call(0.70, 0.22),
				p.call(0.84, 0.30), p.call(0.50, 0.42), p.call(0.12, 0.40)]), base.lightened(0.25))
			_outline(shard, outline, s)
			var font: Font = UI.font_title
			var fs := int(s * 0.42)
			var glyph := "A"
			var w := font.get_string_size(glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string_outline(font, p.call(0.5, 0.66) - Vector2(w / 2.0, 0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, int(s * 0.05), base.darkened(0.6))
			draw_string(font, p.call(0.5, 0.66) - Vector2(w / 2.0, 0), glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff3c4"))
		"phrase_crystal":
			var top: Vector2 = p.call(0.5, 0.06)
			var bottom: Vector2 = p.call(0.5, 0.94)
			var l: Vector2 = p.call(0.16, 0.38)
			var r: Vector2 = p.call(0.84, 0.38)
			var ml: Vector2 = p.call(0.36, 0.38)
			var mr: Vector2 = p.call(0.64, 0.38)
			draw_colored_polygon(PackedVector2Array([top, ml, l]), base.lightened(0.45))
			draw_colored_polygon(PackedVector2Array([top, mr, ml]), base.lightened(0.6))
			draw_colored_polygon(PackedVector2Array([top, r, mr]), base.lightened(0.25))
			draw_colored_polygon(PackedVector2Array([l, ml, bottom]), base)
			draw_colored_polygon(PackedVector2Array([ml, mr, bottom]), base.lightened(0.15))
			draw_colored_polygon(PackedVector2Array([mr, r, bottom]), base.darkened(0.3))
			_outline(PackedVector2Array([top, r, bottom, l]), outline, s)
			for e in [[l, r], [ml, bottom], [mr, bottom], [top, ml], [top, mr]]:
				draw_line(e[0], e[1], Color(outline, 0.45), maxf(1.0, s * 0.015), true)
			draw_circle(p.call(0.42, 0.24), s * 0.04, Color(1, 1, 1, 0.85))
		_:
			draw_circle(p.call(0.5, 0.55), s * 0.34, base)
			draw_circle(p.call(0.5, 0.55), s * 0.22, base.lightened(0.35))
			draw_arc(p.call(0.5, 0.55), s * 0.34, 0, TAU, 48, outline, maxf(2.0, s * 0.04), true)
			draw_arc(p.call(0.5, 0.18), s * 0.08, 0, TAU, 24, UI.GOLD, maxf(2.0, s * 0.04), true)


func _outline(points: PackedVector2Array, color: Color, s: float) -> void:
	var closed := points.duplicate()
	closed.append(points[0])
	draw_polyline(closed, color, maxf(2.0, s * 0.035), true)
