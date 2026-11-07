extends Control
## "Main island" map (hub). Tap Luzon, Visayas or Mindanao.
## Hovering an island (or pressing on it) previews its language map.

var _preview: PanelContainer
var _preview_title: Label
var _preview_map: TextureRect
var _preview_list: GridContainer
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
		b.texture_click_mask = tap_mask(region, t)
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
	_build_preview()

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
	settings.name = "settings_button"
	content.add_child(settings)
	var spirit_button: Control = row.get_child(2)

	# First visit: the welcome story pages, then the hand tour starts at the
	# map. After the first quiz the tour comes back here for everything else.
	var luzon: TextureButton = holder.get_node("luzon")
	var first := [{"id": "map_island", "target": luzon,
		"rect": func(): return island_rect(luzon), "wait": true,
		"text": UI.tx("Ito ang Pangunahing Isla, Guardian! May perlas ang bawat isla na sisindi kapag na-master mo ang lahat ng wika nito. Pindutin ang LUZON para simulan ang iyong paglalakbay.",
			"This is the Main Island, Guardian! Each island keeps a pearl that lights up when you master all of its languages. Tap LUZON to start your journey.")}]
	var rest := [
		{"id": "map_pearls", "target": cores,
			"text": UI.tx("Ito ang mga perlas ng isla. Ipinapakita ng mga numero kung ilang wika na ang na-master mo (naipasa ang Madali, Katamtaman at Mahirap). I-master ang lahat para sumindi ang perlas, at sindihan ang tatlo para gisingin ang Perlas ng Silangan!",
				"These are the island pearls. The numbers show how many languages you have mastered (Easy, Medium and Hard passed). Master them all to light the pearl, and light all three to wake the Pearl of the Orient!")},
		{"id": "map_spirit", "target": spirit_button,
			"text": UI.tx("Kausapin mo ako rito anumang oras sa Gabay na Espiritu! Magtanong tungkol sa mga salita at gramatika, magsalin, tingnan kung paano binibigkas ang mga salita, at ipasuri ang iyong mga pangungusap.",
				"Talk to me here any time! Ask me about words and grammar, translate, see how words are said, and let my grammar checker mark your sentences.")},
		{"id": "map_more", "target": row,
			"text": UI.tx("Ipinapakita ng LEADERBOARD ang pinakamahuhusay na Guardian sa device na ito. Ang MGA KUWENTO ay mga alamat na nabubuksan kapag sinindihan mo ang mga perlas. Ang GABAY ang buong gabay ng laro.",
				"LEADERBOARD shows the best Guardians on this device. STORIES are legends you unlock by lighting the pearls. GABAY is the full guide.")},
		{"id": "nav_gallery", "target": find_child("nav_gallery", true, false),
			"text": UI.tx("Nasa GALLERY ang bawat elemento ng kultura na iyong natuklasan: pagkain, pista, kasuotan, sining, sayaw at musika. Gumamit ng Phrase Crystals doon para magbukas ng iba pa.",
				"GALLERY keeps every cultural element you uncover: food, festivals, clothing, art, dances and music. Spend Phrase Crystals there to unlock more.")},
		{"id": "nav_profile", "target": find_child("nav_profile", true, false),
			"text": UI.tx("Ipinapakita ng PROFILE ang iyong bayani, mga gantimpala, badge at progreso. Ibinabalik ka ng HOME sa mapang ito, at ng BACK sa nakaraang screen.",
				"PROFILE shows your hero, rewards, badges and progress. HOME brings you back to this map and BACK returns to the last screen.")},
		{"id": "map_settings", "target": settings,
			"text": UI.tx("PAGSASAAYOS: wika ng laro (Filipino o English), musika, tunog at abiso. Kusang nase-save ang iyong progreso pagkatapos ng bawat aralin at pagsusulit.",
				"SETTINGS: language of the game (Filipino or English), music, sounds and notices. Your progress is saved automatically after every lesson and quiz.")},
		{"id": "map_guide", "target": find_child("guide_button", true, false),
			"text": UI.tx("Iyan ang buong paglilibot! Buksan ang GABAY kapag kailangan mo ng tulong: nandoon ang lahat ng pahina ng gabay, ang iyong listahan sa Pagsisimula, at maaari mong ulitin ang tutorial na ito. Mabuhay, Guardian!",
				"That's the whole tour! Open GABAY whenever you need help: it has every guide page, your Getting Started checklist, and can replay this tutorial. Mabuhay, Guardian!")},
	]
	var tour := func(): Tutorial.show_steps(self, rest if Tutorial.is_done("results_rewards") else first)
	if GuidePages.maybe_show(self, "welcome", tour) == null:
		tour.call()


## Where a tap opens [param region]: its land plus the sea around it, so the
## small islands are easy to hit with a finger (assets/ui/map_<region>_tap.png,
## made by tools/art/make_island_tap_masks.py). Falls back to the land only.
static func tap_mask(region: String, art: Texture2D) -> BitMap:
	var mask := BitMap.new()
	var path := "res://assets/ui/map_%s_tap.png" % region
	var img: Image = (load(path) as Texture2D).get_image() if ResourceLoader.exists(path) else art.get_image()
	if img.is_compressed():
		img.decompress()
	mask.create_from_image_alpha(img, 0.3)
	return mask


## Where the island is drawn inside its (full-size) button, in screen space.
func island_rect(b: TextureButton) -> Rect2:
	var tex := b.texture_normal
	var used := tex.get_image().get_used_rect()
	var r := b.get_global_rect()
	var s := minf(r.size.x / tex.get_width(), r.size.y / tex.get_height())
	var origin := r.position + (r.size - tex.get_size() * s) / 2
	return Rect2(origin + Vector2(used.position) * s, Vector2(used.size) * s)


# ---------------------------------------------------------------- hover preview

## A large card over the whole screen with the island's language map and,
## in clear text, its languages and where they are spoken. It ignores the
## mouse, so the island underneath keeps its hover and its tap.
func _build_preview() -> void:
	_preview = PanelContainer.new()
	_preview.name = "MapPreview"
	_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_preview.offset_left = 14
	_preview.offset_right = -14
	_preview.offset_top = 96
	_preview.offset_bottom = -96
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.visible = false
	add_child(_preview)
	var v := UI.vbox(8)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview.add_child(v)
	_preview_title = UI.label("", 30, UI.WHITE, false, UI.font_body_black)
	_preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_title.add_theme_color_override("font_outline_color", Color("3b2208"))
	_preview_title.add_theme_constant_override("outline_size", 8)
	v.add_child(_preview_title)
	_preview_map = UI.map_image("luzon", Vector2.ZERO)
	_preview_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_preview_map)
	_preview_list = GridContainer.new()
	_preview_list.name = "languages"
	_preview_list.columns = 2
	_preview_list.add_theme_constant_override("h_separation", 14)
	_preview_list.add_theme_constant_override("v_separation", 4)
	_preview_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_preview_list)
	var tip := UI.label("Pindutin para pumasok" if UI.lang == "fil" else "Tap to explore", 20, Color("ffe08a"), false, UI.font_body_black)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tip)


## The island's languages in the map's order and numbering.
func _fill_preview_list(region: String) -> void:
	for c in _preview_list.get_children():
		_preview_list.remove_child(c)
		c.queue_free()
	var i := 1
	for lang in DB.get_languages(region):
		var entry := UI.vbox(0)
		entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var playable := int(lang.playable) == 1
		var name_l := UI.label("%d. %s" % [i, lang.name], 19, Color("ffe08a") if playable else Color("e8dcc3"), true, UI.font_body_black)
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(name_l)
		var area := UI.label(UI.LANGUAGE_AREAS.get(lang.name, ""), 14, Color("f3ead8"), true)
		area.mouse_filter = Control.MOUSE_FILTER_IGNORE
		entry.add_child(area)
		_preview_list.add_child(entry)
		i += 1


func _show_preview(region: String) -> void:
	_hovered = region
	var color: Color = UI.REGION_COLORS[region]
	var sb := UI._box(Color(0.1, 0.07, 0.04, 0.97), 18, color.lightened(0.2), 4, 14)
	_preview.add_theme_stylebox_override("panel", sb)
	var count := DB.get_languages(region).size()
	_preview_title.text = "%s  ·  %d %s" % [region.to_upper(), count, "wika" if UI.lang == "fil" else "languages"]
	_preview_map.texture = UI.tex["lang_map_" + region]
	_fill_preview_list(region)
	_preview.visible = true
	# Shown at once, solid and at full size: a zoom or fade-in blurs the
	# map and its text while it plays (on a phone the tap shows only that).
	if _preview_tween:
		_preview_tween.kill()
	_preview.scale = Vector2.ONE
	_preview.modulate.a = 1.0


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
