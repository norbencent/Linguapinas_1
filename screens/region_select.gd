extends Control
## Island page: the region's guide, its two heroes and the region button.

const GREETINGS := {
	"luzon": ["Mabuhay, Tagapangalaga! Ako si Maelor. Matuto ng wika ng Luzon upang muling paliwanagin ang Luzon Core.",
		"Welcome, Guardian! I am Maelor. Learn a language of Luzon to relight the Luzon Core."],
	"visayas": ["Maayong adlaw! Ako si Marea. Ibalik natin ang liwanag ng Visayas Core.",
		"Good day! I am Marea. Let us bring back the light of the Visayas Core."],
	"mindanao": ["Assalamu alaikum! Ako si Lanora. Gisingin natin ang Mindanao Core.",
		"Peace be with you! I am Lanora. Let us awaken the Mindanao Core."],
}


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
	var greet := UI.label(GREETINGS[code][0 if UI.lang == "fil" else 1], 20, UI.INK, true)
	greet.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(greet)

	var heroes := UI.hbox(10)
	heroes.alignment = BoxContainer.ALIGNMENT_CENTER
	for a in ["boy", "girl"]:
		var img := UI.image(UI.tex["%s_%s" % [code, a]], Vector2(230, 215))
		img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if a == UI.avatar_gender(Game.user.get("avatar", "boy")):
			img.modulate = Color(1.08, 1.08, 1.08)
		heroes.add_child(img)
	content.add_child(heroes)

	var langs := DB.get_languages(code)
	var playable := langs.filter(func(l): return int(l.playable) == 1).size()
	var levels := DB.get_completed_level_count(uid, code)
	var restored := DB.is_core_restored(uid, code)
	var status := "%s: %s   |   %d / %d" % [region.core_name, "RESTORED" if restored else "dormant", levels, playable * 3]
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
