class_name LockedPhoto
extends TextureRect
## A culture photo the player has not unlocked yet: blurred beyond recognition
## (read from a tiny mipmap level), darkened, with a padlock on top. The real
## photo is only shown once the item is unlocked.

const SHADER := """
shader_type canvas_item;
uniform float lod = 6.0;
void fragment() {
	vec3 c = textureLod(TEXTURE, UV, lod).rgb;
	float grey = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(grey), c, 0.35) * 0.42;            // washed out and dark
	COLOR = vec4(c, 1.0);
}
"""

static var _shader: Shader


static func make(texture: Texture2D, height := 180) -> LockedPhoto:
	var r := LockedPhoto.new()
	r.name = "locked_photo"
	r.texture = texture
	r.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.custom_minimum_size = Vector2(0, height)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	r.material = m
	# The padlock is a separate layer so the blur shader doesn't grey it out.
	var lock := Padlock.new()
	lock.name = "padlock"
	lock.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(lock)
	return r


class Padlock extends Control:
	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED:
			queue_redraw()

	func _draw() -> void:
		# Padlock in the middle of the hidden photo.
		var s := clampf(minf(size.x, size.y) * 0.42, 48.0, 140.0)
		var c := size / 2.0
		var body := Rect2(c.x - s * 0.36, c.y - s * 0.06, s * 0.72, s * 0.56)
		var gold := UI.GOLD
		var dark := Color("3b200c")
		var w := maxf(4.0, s * 0.09)
		# Shackle.
		draw_arc(Vector2(c.x, c.y - s * 0.06), s * 0.24, PI, TAU, 32, dark, w + 6.0, true)
		draw_arc(Vector2(c.x, c.y - s * 0.06), s * 0.24, PI, TAU, 32, gold.lightened(0.15), w, true)
		# Body.
		var sb := StyleBoxFlat.new()
		sb.bg_color = gold
		sb.set_corner_radius_all(int(s * 0.1))
		sb.border_color = dark
		sb.set_border_width_all(int(maxf(3.0, s * 0.04)))
		draw_style_box(sb, body)
		draw_rect(Rect2(body.position + Vector2(body.size.x * 0.1, body.size.y * 0.12), Vector2(body.size.x * 0.8, body.size.y * 0.16)),
			Color(1, 1, 1, 0.25))
		# Keyhole.
		var k := body.get_center()
		draw_circle(k - Vector2(0, s * 0.04), s * 0.07, dark)
		draw_colored_polygon(PackedVector2Array([k + Vector2(-s * 0.04, -s * 0.02), k + Vector2(s * 0.04, -s * 0.02),
			k + Vector2(s * 0.06, s * 0.16), k + Vector2(-s * 0.06, s * 0.16)]), dark)
		# Caption under the lock.
		var font: Font = UI.font_body_black
		var text := UI.t("locked").to_upper()
		var fs := int(clampf(s * 0.2, 16.0, 30.0))
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(c.x - tw / 2.0, body.end.y + fs + 6.0)
		draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, dark)
		draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("ffe08a"))

