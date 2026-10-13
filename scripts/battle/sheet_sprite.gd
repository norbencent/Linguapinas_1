extends Control
## Plays animations cut from a sprite sheet (frame rects from sprite_frames.gd).
## Each frame is drawn at one fixed scale, standing on the bottom-centre of
## this control, so frames of different sizes don't wobble.

signal animation_finished(anim: String)
## Emitted once per play() when the animation reaches its "impact" frame.
signal impact(anim: String)

const KEY_BLACK_SHADER := """
shader_type canvas_item;
// The warrior sheets have a black background instead of transparency.
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float m = max(c.r, max(c.g, c.b));
	c.a *= smoothstep(0.035, 0.11, m);
	COLOR = c * COLOR;
}
"""

var sheet: Texture2D
var animations := {}      # name -> Array[Rect2]
var flip := false         # mirror horizontally (face left)
var unit_height := 1.0    # source pixels that map to the control's height
var current := ""
var frame := 0
var fps := 7.0
var looping := true
var _impact_frame := -1
var _time := 0.0


func setup(texture: Texture2D, anims: Dictionary, key_black := false) -> void:
	sheet = texture
	animations = anims
	unit_height = 1.0
	for f in anims.get("idle", []):
		unit_height = maxf(unit_height, (f as Rect2).size.y)
	if key_black:
		var mat := ShaderMaterial.new()
		var shader := Shader.new()
		shader.code = KEY_BLACK_SHADER
		mat.shader = shader
		material = mat
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	play("idle")


func has_animation(anim: String) -> bool:
	return not animations.get(anim, []).is_empty()


## Plays `anim`; looping animations run until another play(). One-shot ones
## emit `impact` at `impact_at` (0..1 of the way through) and then
## `animation_finished`.
func play(anim: String, speed := 7.0, loop := true, impact_at := 0.5) -> void:
	if not has_animation(anim):
		return
	current = anim
	frame = 0
	fps = speed
	looping = loop
	_time = 0.0
	_impact_frame = -1 if loop else int(floor((animations[anim].size() - 1) * impact_at))
	if _impact_frame == 0:
		impact.emit(anim)
	queue_redraw()


func _process(delta: float) -> void:
	if current == "" or sheet == null:
		return
	_time += delta
	var step := 1.0 / fps
	while _time >= step:
		_time -= step
		var count: int = animations[current].size()
		if frame + 1 < count:
			frame += 1
			if frame == _impact_frame:
				impact.emit(current)
		elif looping:
			frame = 0
		else:
			var done := current
			animation_finished.emit(done)
			if current == done:
				play("idle")
			return
		queue_redraw()


func _draw() -> void:
	if sheet == null or not has_animation(current):
		return
	var src: Rect2 = animations[current][mini(frame, animations[current].size() - 1)]
	var s := size.y / unit_height
	var dest_size := src.size * s
	var pos := Vector2((size.x - dest_size.x) / 2.0, size.y - dest_size.y)
	if flip:
		draw_set_transform(Vector2(size.x, 0), 0.0, Vector2(-1, 1))
	draw_texture_rect_region(sheet, Rect2(pos, dest_size), src)
