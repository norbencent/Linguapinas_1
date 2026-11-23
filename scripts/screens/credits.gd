extends Control
## Copyright and Photo Credits. The text lives in database/credits.json so it
## can be edited without touching code. Opened from Settings and the Gallery.

const CREDITS_PATH := "res://database/credits.json"

const LINK := Color("1f4f9c")


func _ready() -> void:
	# Settings is never kept in the back history, so return to it directly.
	var from_settings: bool = not Game.history.is_empty() and Game.history[-1] == "settings"
	var content := UI.page(self, "CREDITS", "settings" if from_settings else Game.BACK, {"nav": Game.is_logged_in()})
	var data := load_credits()
	if data.is_empty():
		content.add_child(UI.label("Credits could not be loaded.", 20, UI.RED, true))
		return

	var head := UI.panel(Color("fff2c2"), UI.GOLD)
	head.name = "copyright"
	var hv := UI.vbox(8)
	head.add_child(hv)
	var title := UI.label(str(data.title), 26, UI.RED, true, UI.font_body_black)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(title)
	var c := UI.label(str(data.copyright), 20, UI.INK, true, UI.font_body_black)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hv.add_child(c)
	hv.add_child(_text(str(data.about)))
	content.add_child(head)

	var tp := UI.panel()
	tp.name = "third_party"
	var tv := UI.vbox(8)
	tp.add_child(tv)
	tv.add_child(UI.label(str(data.third_party_heading), 23, UI.RED, true, UI.font_body_black))
	tv.add_child(_text(str(data.third_party)))
	tv.add_child(_text(str(data.used_only_intro)))
	for line in data.used_only:
		tv.add_child(_text("•  " + str(line)))
	tv.add_child(_text(str(data.fair_use)))
	tv.add_child(_text(str(data.contact)))
	content.add_child(tp)

	var heading := UI.label(str(data.credits_heading), 26, UI.RED, true, UI.font_body_black)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(heading)
	var n := 0
	for island in data.islands:
		var code := str(island.island).to_lower()
		var color: Color = UI.REGION_COLORS.get(code, UI.GOLD)
		var card := UI.panel(UI.CARD, color)
		card.name = "credits_" + code
		var v := UI.vbox(10)
		card.add_child(v)
		v.add_child(UI.pill(str(island.island).to_upper(), color, 20))
		for photo in island.photos:
			n += 1
			v.add_child(_credit_row(n, photo))
		content.add_child(card)
	var closing := UI.label(str(data.closing), 17, UI.INK_SOFT, true, UI.font_body_black)
	closing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(closing)


static func load_credits() -> Dictionary:
	var f := FileAccess.open(CREDITS_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


func _text(t: String) -> Label:
	return UI.label(t, 18, UI.INK, true)


## "1. Pahiyas Festival: Rappler" and its link underneath (tap to open it).
func _credit_row(n: int, photo: Dictionary) -> VBoxContainer:
	var box := UI.vbox(2)
	box.name = "credit_%d" % n
	var source := str(photo.get("source", ""))
	box.add_child(UI.label("%d. %s%s" % [n, photo.title, (": " + source) if source != "" else ""], 18, UI.INK, true, UI.font_body_black))
	var url := str(photo.get("url", ""))
	if url != "":
		var link := RichTextLabel.new()
		link.bbcode_enabled = true
		link.fit_content = true
		link.scroll_active = false
		link.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY  # long links wrap anywhere
		link.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		link.add_theme_font_override("normal_font", UI.font_button)  # has lowercase: links stay exact
		link.add_theme_font_size_override("normal_font_size", 15)
		link.add_theme_color_override("default_color", LINK)
		link.text = "[url=%s][u]%s[/u][/url]" % [url, url]
		link.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
		box.add_child(link)
	return box
