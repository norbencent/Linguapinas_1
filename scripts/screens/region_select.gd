extends Control
## Island page: the region's guide, its two heroes and the region button.


func _ready() -> void:
	var region := DB.get_region(Game.region_code)
	if region.is_empty():
		Game.goto("map")
		return
	var code: String = region.code
	var color: Color = UI.REGION_COLORS[code]
	var content := UI.page(self, UI.t("main_island"), "map")
	content.add_theme_constant_override("separation", 10)
	var uid := Game.user_id()

	content.add_child(UI.ribbon(UI.t("language"), color))
	content.add_child(UI.center(UI.image(UI.tex["guide_" + code], Vector2(120, 120))))
	content.add_child(UI.heading(UI.GUIDES[code].to_upper(), color, 26))
	var greet := UI.label(Spirit.speak_line(code, "greet"), 20, UI.INK, true)
	greet.name = "greeting"
	var title := UI.label(Spirit.persona(code).get("title", ""), 16, UI.INK_SOFT, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	greet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(greet)

	var heroes := UI.hbox(10)
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	for a in ["boy", "girl"]:
		var img := UI.image(UI.tex["%s_%s" % [code, a]], Vector2(230, 215))
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if a == Game.user.get("avatar", "boy"):
			img.modulate = Color(1.08, 1.08, 1.08)
		heroes.add_child(img)
	content.add_child(heroes)

	var langs := DB.get_languages(code)
	var restored := DB.is_core_restored(uid, code)
	var pearl := DB.get_pearl_progress(uid, code)
	var status := "%s: %s   |   %d / %d languages mastered" % [region.core_name, "LIT" if restored else "dormant",
		pearl.mastered, pearl.total]
	var sl := UI.label(status, 18, color.darkened(0.2) if restored else UI.INK_SOFT, true)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(sl)

	var b := TextureButton.new()
	b.texture_normal = UI.tex["btn_region_" + code]
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(0, 150)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func():
		Sound.click()
		Game.goto("language"))
	content.add_child(b)
	Tutorial.show_steps(self, [{"id": "island_languages", "target": b, "wait": true,
		"text": "I am %s, your Guiding Spirit. I will help you on this island. Tap the %s button to see its languages."
			% [UI.GUIDES[code], region.name.to_upper()]}])
