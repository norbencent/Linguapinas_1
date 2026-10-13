extends Control
## "Main island" map (hub). Tap Luzon, Visayas or Mindanao.


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
		b.mouse_entered.connect(func(): b.self_modulate = Color(1.2, 1.2, 1.2))
		b.mouse_exited.connect(func(): b.self_modulate = Color.WHITE)
		b.pressed.connect(func():
			Sound.click()
			Game.region_code = region
			Game.goto("island"))
		holder.add_child(b)

	var hint := UI.label(UI.t("tap_island"), 20, UI.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)

	var row := UI.hbox(8)
	content.add_child(row)
	var items := [
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
