extends Control
## Player profile (prototype profile screen).


func _ready() -> void:
	Game.refresh_user()
	var uid := Game.user_id()
	var content := UI.page(self, UI.t("profile"), Game.BACK)
	var last := DB.get_last_language(uid)
	var region: String = last.get("region_code", Game.region_code if Game.region_code != "" else "luzon")

	var portrait := PanelContainer.new()
	var sb := UI._box(Color("fffaf0"), 120, Color("c99a2e"), 8, 8)
	portrait.add_theme_stylebox_override("panel", sb)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var face := UI.image(UI.character_texture(region, Game.user.get("avatar", "boy")), Vector2(210, 210))
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.add_child(face)
	content.add_child(portrait)

	var rewards := DB.get_rewards(uid)
	var secs := int(Game.user.get("playtime", 0))
	var lines := [
		["Name", Game.user.display_name],
		["Island", DB.get_region(region).get("name", "-")],
		["Language", last.get("name", "-")],
		["Fragment", str(rewards.word_fragment)],
		["Crystal", str(rewards.phrase_crystal)],
		["Relics", str(rewards.cultural_relic)],
		["Badge", str(DB.get_badges(uid).size())],
		["Score", str(DB.get_total_score(uid))],
		["Playtime", "%d:%02d" % [secs / 3600, (secs / 60) % 60]],
	]
	var card := UI.panel(Color("fdf6e3"), Color("c99a2e"))
	var v := UI.vbox(6)
	card.add_child(v)
	for l in lines:
		v.add_child(UI.label("%s: %s" % [l[0], l[1]], 24, Color("8b1a1a"), true, UI.font_body_black))
	content.add_child(card)

	content.add_child(UI.heading("Rewards", UI.RED, 24))
	content.add_child(UI.wallet(uid))
	content.add_child(UI.reward_guide())
	var culture_count := DB.get_unlocked_culture(uid).size()
	content.add_child(UI.label("Culture collected: %d / %d" % [culture_count, DB.get_culture_items().size()], 20, UI.INK, true, UI.font_body_black))

	content.add_child(UI.heading("Progress", UI.RED, 24))
	var any := false
	for lang in DB.get_playable_languages():
		var p := DB.get_progress(uid, lang.code)
		if p[1].completed or p[2].completed or p[3].completed:
			any = true
			var row := UI.row_panel()
			var h := UI.hbox(10)
			row.add_child(h)
			var n := UI.label(lang.name, 22, UI.INK, true, UI.font_body_black)
			h.add_child(n)
			h.add_child(UI.level_gems(p))
			content.add_child(row)
	if not any:
		content.add_child(UI.label("No levels completed yet.", 19, UI.INK_SOFT, true))

	content.add_child(UI.gem_button(UI.t("gallery").to_upper(), "gold", func(): Game.goto("gallery"), 84, 30))
	content.add_child(UI.gem_button(UI.t("setting"), "blue", func(): Game.open_settings("profile"), 84, 30))
	content.add_child(UI.gem_button(UI.t("logout"), "red", Game.logout, 84, 30))
