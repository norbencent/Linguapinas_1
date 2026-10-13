extends Control
## List of the region's languages (prototype: yellow rows with a red gem).


func _ready() -> void:
	var region := DB.get_region(Game.region_code)
	if region.is_empty():
		Game.goto("map")
		return
	var color: Color = UI.REGION_COLORS[region.code]
	var content := UI.page(self, region.name, "island")
	var uid := Game.user_id()
	content.add_theme_constant_override("separation", 14)
	for lang in DB.get_languages(region.code):
		var playable := int(lang.playable) == 1
		var row := UI.row_panel(UI.ROW if playable else Color("e3d8bf"))
		var h := UI.hbox(14)
		row.add_child(h)
		h.add_child(UI.orb(color if playable else Color("8d8170"), true, 26))
		var info := UI.vbox(0)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		info.add_child(UI.label(lang.name, 26, UI.INK if playable else UI.INK_SOFT, true, UI.font_body_black))
		if playable:
			h.add_child(UI.level_gems(DB.get_progress(uid, lang.code)))
			var code: String = lang.code
			UI.clickable(row, func():
				Game.language_code = code
				Game.category_code = ""
				Game.goto("difficulty"))
		else:
			info.add_child(UI.label(UI.t("coming_soon"), 16, UI.INK_SOFT))
		content.add_child(row)
