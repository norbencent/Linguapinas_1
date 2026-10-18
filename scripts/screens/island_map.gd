extends Control
## "Main island" map (hub). Tap Luzon, Visayas or Mindanao.
## Hovering an island (or pressing on it) previews its language map.

var _preview: PanelContainer
var _preview_title: Label
var _preview_map: TextureRect
var _preview_tween: Tween
var _hovered := ""


func _ready() -> void:
	var content := UI.page(self, UI.t("main_island"), func(): Game.goto("menu"))
	var uid := Game.user_id()
	var restored := DB.get_restored_cores(uid)

	var cores := UI.hbox(18)
	cores.alignment = BoxContainer.ALIGNMENT_CENTER
	# The island pearls light up when every language of the island is mastered.
	for region in DB.get_regions():
		var col := UI.vbox(2)
		var orb := PearlOrb.make(UI.REGION_COLORS[region.code], region.code in restored, 42)
		orb.name = "pearl_" + region.code
		col.add_child(orb)
		var l := UI.label(region.name, 16, UI.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		var p := DB.get_pearl_progress(uid, region.code)
		var pl := UI.label("%d/%d" % [p.mastered, p.total], 14, UI.GREEN if region.code in restored else UI.INK_SOFT, false, UI.font_body_black)
		pl.name = "progress_" + region.code
		pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pl.tooltip_text = "Languages mastered (Easy, Medium and Hard)"
		pl.mouse_filter = Control.MOUSE_FILTER_PASS
		col.add_child(pl)
		cores.add_child(col)
	var pearl := UI.vbox(2)
	var orient := PearlOrb.make(PearlCelebration.PEARL_OF_THE_ORIENT, restored.size() == 3, 42)
	orient.name = "pearl_orient"
	pearl.add_child(orient)
	var pl := UI.label("Orient", 16, UI.INK)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pearl.add_child(pl)
	var pl2 := UI.label("%d/3" % restored.size(), 14, UI.INK_SOFT, false, UI.font_body_black)
	pl2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pearl.add_child(pl2)
	cores.add_child(pearl)
	content.add_child(cores)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 470)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(holder)
	for region in ["luzon", "visayas", "mindanao"]:
		var t: Texture2D = UI.tex["map_" + region]
		var b := TextureButton.new()
		b.name = region
		b.texture_normal = t
		b.ignore_texture_size = true
		b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		var mask := BitMap.new()
		mask.create_from_image_alpha(t.get_image(), 0.3)
		b.texture_click_mask = mask
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		if region in restored:
			b.modulate = Color(1.15, 1.15, 1.15)
		b.mouse_entered.connect(func():
			b.self_modulate = Color(1.2, 1.2, 1.2)
			_show_preview(region))
		b.mouse_exited.connect(func():
			b.self_modulate = Color.WHITE
			_hide_preview(region))
		b.pressed.connect(func():
			Sound.click()
			Game.region_code = region
			Game.goto("island"))
		holder.add_child(b)
	_build_preview(holder)

	var hint := UI.label(UI.t("tap_island"), 20, UI.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)

	var row := UI.hbox(8)
	content.add_child(row)
	var items := [
		[UI.t("leaderboard"), UI.GOLD.darkened(0.15), func(): Game.goto("leaderboard")],
		[UI.t("stories"), UI.BLUE, func(): Game.goto("stories")],
		[UI.t("spirit"), Color("6b3fa0"), func(): Game.goto("spirit")],
		["GABAY" if UI.lang == "fil" else "GUIDE", UI.GREEN, func(): Game.goto("guide")],
	]
	for it in items:
		var b := UI.pill_button(it[0], it[1], it[2], 56, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if it[0] in ["GABAY", "GUIDE"]:
			b.name = "guide_button"
		row.add_child(b)
	var settings := UI.pill_button(UI.t("setting"), UI.INK_SOFT, func(): Game.open_settings("map"), 50, 18)
	content.add_child(settings)

	# First visit: the welcome story pages, then the hand tour starts at the map.
	var luzon: TextureButton = holder.get_node("luzon")
	var tour := func(): Tutorial.show_steps(self, [{"id": "map_island", "target": luzon,
		"rect": func(): return island_rect(luzon), "wait": true,
		"text": "This is the Main Island, Guardian! Each island keeps a pearl that lights up when you master all of its languages. Tap LUZON to start your journey."}])
	if GuidePages.maybe_show(self, "welcome", tour) == null:
		tour.call()


## Where the island is drawn inside its (full-size) button, in screen space.
func island_rect(b: TextureButton) -> Rect2:
	var tex := b.texture_normal
	var used := tex.get_image().get_used_rect()
	var r := b.get_global_rect()
	var s := minf(r.size.x / tex.get_width(), r.size.y / tex.get_height())
	var origin := r.position + (r.size - tex.get_size() * s) / 2
	return Rect2(origin + Vector2(used.position) * s, Vector2(used.size) * s)


# ---------------------------------------------------------------- hover preview

## A card over the map area showing the hovered island's language map. It
## ignores the mouse, so the island underneath keeps its hover and its tap.
func _build_preview(holder: Control) -> void:
	_preview = PanelContainer.new()
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.visible = false
	holder.add_child(_preview)
	var v := UI.vbox(6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(v)
	_preview_title = UI.label("", 26, UI.WHITE, false, UI.font_body_black)
	_preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_title.add_theme_color_override("font_outline_color", Color("3b2208"))
	_preview_title.add_theme_constant_override("outline_size", 8)
	v.add_child(_preview_title)
	_preview_map = UI.image(null, Vector2.ZERO)
	_preview_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_preview_map)
	var tip := UI.label("Pindutin para pumasok" if UI.lang == "fil" else "Tap to explore", 18, UI.WHITE)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tip)


func _show_preview(region: String) -> void:
	_hovered = region
	var color: Color = UI.REGION_COLORS[region]
	var sb := UI._box(Color(0.08, 0.06, 0.04, 0.88), 18, color.lightened(0.2), 4, 10)
	_preview.add_theme_stylebox_override("panel", sb)
	var count := DB.get_languages(region).size()
	_preview_title.text = "%s  ·  %d %s" % [region.to_upper(), count, "wika" if UI.lang == "fil" else "languages"]
	_preview_map.texture = UI.tex["lang_map_" + region]
	_preview.visible = true
	_preview.pivot_offset = _preview.size / 2.0
	if _preview_tween:
		_preview_tween.kill()
	_preview.modulate.a = 0.0
	_preview.scale = Vector2(0.94, 0.94)
	_preview_tween = create_tween().set_parallel()
	_preview_tween.tween_property(_preview, "modulate:a", 1.0, 0.15)
	_preview_tween.tween_property(_preview, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_preview(region: String) -> void:
	# Moving straight from one island to another fires the new enter first.
	if _hovered != region:
		return
	_hovered = ""
	if _preview_tween:
		_preview_tween.kill()
	_preview_tween = create_tween()
	_preview_tween.tween_property(_preview, "modulate:a", 0.0, 0.12)
	_preview_tween.tween_callback(func(): _preview.visible = _hovered != "")
