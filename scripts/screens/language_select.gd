extends Control
## List of the region's languages (prototype: yellow rows with a red gem),
## under the island's language map. Tap the map to see it full screen.

## Where each language is spoken, as labelled on the language maps.
const AREAS := {
	"Tagalog": "Central and Southern Luzon (Manila, CALABARZON, MIMAROPA)",
	"Ilocano": "Ilocos Region and parts of La Union",
	"Pangasinan": "Pangasinan Province",
	"Kapampangan": "Pampanga and southern Tarlac",
	"Bikolano": "Bicol Region, southeastern Luzon",
	"Ibanag": "Cagayan Valley, especially Cagayan",
	"Kankanaey": "Mountain Province and Benguet",
	"Ivatan": "Batanes Islands",
	"Ifugao": "Ifugao Province, Cordillera",
	"Kalinga": "Kalinga Province, Cordillera",
	"Cebuano": "Cebu Province and nearby islands",
	"Hiligaynon": "Western Visayas (Iloilo, Negros Occidental)",
	"Waray-Waray": "Eastern Visayas (Samar and Leyte)",
	"Aklanon": "Aklan Province",
	"Kinaray-a": "Antique Province",
	"Capiznon": "Capiz Province",
	"Masbateño": "Masbate Province",
	"Romblomanon": "Romblon Province",
	"Cuyonon": "Palawan (Cuyo Islands)",
	"Porohanon": "Camotes Islands (Poro), Cebu",
	"Bisaya": "Davao Region, Davao del Sur, Davao Oriental",
	"Tausug": "Sulu and Tawi-Tawi",
	"Maguindanaon": "Maguindanao del Sur and Maguindanao del Norte",
	"Maranao": "Lanao del Sur",
	"Higaonon": "Misamis Oriental, Bukidnon, parts of Lanao del Norte",
	"Surigaonon": "Surigao del Norte and Surigao del Sur",
	"Subanen": "Zamboanga del Norte, Zamboanga del Sur, Zamboanga Sibugay",
	"Blaan": "South Cotabato, Sarangani, parts of Davao del Sur",
	"Chavacano": "Zamboanga City and nearby areas",
	"Yakan": "Basilan and nearby areas",
}


func _ready() -> void:
	var region := DB.get_region(Game.region_code)
	if region.is_empty():
		Game.goto("map")
		return
	var color: Color = UI.REGION_COLORS[region.code]
	var content := UI.page(self, region.name, "island")
	var uid := Game.user_id()
	content.add_theme_constant_override("separation", 14)
	_add_map(content, region.code)
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
		if AREAS.has(lang.name):
			info.add_child(UI.label(AREAS[lang.name], 15, UI.INK_SOFT, true))
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


func _add_map(content: VBoxContainer, code: String) -> void:
	var map := UI.image(UI.tex["lang_map_" + code], Vector2(0, 420))
	content.add_child(map)
	UI.clickable(map, func(): _show_map(code)).set_anchors_preset(Control.PRESET_FULL_RECT)
	var hint := UI.label("Pindutin ang mapa para palakihin" if UI.lang == "fil" else "Tap the map to enlarge", 16, UI.INK_SOFT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(hint)


## Full-screen view of the language map; tap anywhere to close it.
func _show_map(code: String) -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var img := UI.image(UI.tex["lang_map_" + code], Vector2.ZERO)
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.offset_left = 8
	img.offset_right = -8
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(img)
	overlay.gui_input.connect(func(e: InputEvent):
		if (e is InputEventMouseButton or e is InputEventScreenTouch) and e.pressed:
			Sound.click()
			overlay.queue_free())
	add_child(overlay)
	Game.overlays.append(overlay)
