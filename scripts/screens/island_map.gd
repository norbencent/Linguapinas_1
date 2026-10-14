extends Control
## "Main island" map (hub). Tap Luzon, Visayas or Mindanao.

var preview: Control
var preview_image: TextureRect
var preview_title: Label
var preview_hint: Label
var preview_region := ""
var preview_close: Button


func _ready() -> void:
	var content := UI.page(self, UI.t("main_island"), func(): Game.goto("menu"))
	var uid := Game.user_id()
	var restored := DB.get_restored_cores(uid)

	var cores := UI.hbox(18)
	cores.alignment = BoxContainer.ALIGNMENT_CENTER
	for region in DB.get_regions():
		var col := UI.vbox(2)
		col.add_child(UI.orb(UI.REGION_COLORS[region.code], region.code in restored, 34))
		var l := UI.label(region.name, 16, UI.INK)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(l)
		cores.add_child(col)
	var pearl := UI.vbox(2)
	pearl.add_child(UI.orb(Color("fdf8ec"), restored.size() == 3, 34))
	var pl := UI.label("Pearl", 16, UI.INK)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pearl.add_child(pl)
	cores.add_child(pearl)
	content.add_child(cores)

	var holder := Control.new()
	holder.custom_minimum_size = Vector2(0, 470)
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(holder)
	var names := {}
	for region in DB.get_regions():
		names[region.code] = region.name
	# Mouse: hovering an island shows its language map and a click enters it.
	# Touch has no hover, so the first tap shows the map and tapping it enters.
	var touch := DisplayServer.is_touchscreen_available()
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
			if not touch:
				_show_preview(region, names.get(region, region), false))
		b.mouse_exited.connect(func():
			b.self_modulate = Color.WHITE
			if not touch:
				_hide_preview())
		b.pressed.connect(func():
			if touch:
				_show_preview(region, names.get(region, region), true)
			else:
				_enter_region(region))
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
		[UI.t("spirit"), Color("6b3fa0"), func():
			Game.return_to = "map"
			Game.goto("spirit")],
	]
	for it in items:
		var b := UI.pill_button(it[0], it[1], it[2], 56, 18)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(b)
	var settings := UI.pill_button(UI.t("setting"), UI.INK_SOFT, func(): Game.open_settings("map"), 50, 18)
	content.add_child(settings)


func _enter_region(region: String) -> void:
	Sound.click()
	Game.region_code = region
	Game.goto("island")


## Card over the map that shows the languages of one island group.
func _build_preview(holder: Control) -> void:
	preview = Button.new()
	preview.focus_mode = Control.FOCUS_NONE
	preview.add_theme_stylebox_override("normal", _preview_box())
	preview.add_theme_stylebox_override("hover", _preview_box())
	preview.add_theme_stylebox_override("pressed", _preview_box())
	preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	preview.visible = false
	preview.pressed.connect(func(): _enter_region(preview_region))
	holder.add_child(preview)

	var box := UI.vbox(4)
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10
	box.offset_top = 8
	box.offset_right = -10
	box.offset_bottom = -8
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(box)

	preview_title = UI.label("", 26, UI.INK)
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview_title)

	preview_image = TextureRect.new()
	preview_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview_image)

	preview_hint = UI.label("", 18, UI.INK_SOFT)
	preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(preview_hint)

	preview_close = UI.pill_button("X", UI.RED, _hide_preview, 44, 20)
	preview_close.custom_minimum_size = Vector2(44, 44)
	preview_close.position = Vector2(8, 8)
	preview.add_child(preview_close)


func _preview_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("fbf3e0")
	sb.border_color = Color("c9a76b")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(16)
	return sb


## [param tappable] is true on touch screens: the card then takes taps (tap
## it to enter the island, X to close). With a mouse it lets the pointer
## through so moving off the island hides it again.
func _show_preview(region: String, title: String, tappable: bool) -> void:
	var t: Texture2D = load("res://assets/ui/lang_map_%s.png" % region)
	if t == null:
		if tappable:
			_enter_region(region)
		return
	preview_region = region
	preview_image.texture = t
	preview_title.text = title
	preview_title.add_theme_color_override("font_color", UI.REGION_COLORS[region].darkened(0.2))
	preview_hint.text = "Tap the map to explore %s" % title if tappable else "Click to explore %s" % title
	preview.mouse_filter = Control.MOUSE_FILTER_STOP if tappable else Control.MOUSE_FILTER_IGNORE
	preview_close.visible = tappable
	if not preview.visible:
		preview.modulate.a = 0.0
		preview.visible = true
		create_tween().tween_property(preview, "modulate:a", 1.0, 0.15)


func _hide_preview() -> void:
	preview.visible = false
	preview_region = ""
