extends Control
## The Guiding Spirit: offline translator, dictionary and grammar tips.

var lang_picker: OptionButton
var direction_picker: OptionButton
var input: LineEdit
var result_label: Label
var source_label: Label
var matches_box: VBoxContainer
var tips_box: VBoxContainer
var server_label: Label
var lang_codes: Array = []


func _ready() -> void:
	var content := UI.page(self, UI.t("spirit"), Game.BACK)
	var region: String = Game.region_code if Game.region_code in UI.GUIDES else "luzon"
	var head := UI.hbox(12)
	head.add_child(UI.image(UI.tex["guide_" + region], Vector2(96, 96)))
	head.add_child(UI.label("%s: Ask me to translate words and phrases. I work offline." % UI.GUIDES[region], 19, UI.INK, true))
	content.add_child(head)

	lang_picker = OptionButton.new()
	for l in DB.get_playable_languages():
		lang_picker.add_item(l.name)
		lang_codes.append(l.code)
	lang_picker.select(maxi(0, lang_codes.find(Game.language_code)))
	lang_picker.item_selected.connect(func(_i): _show_tips())
	content.add_child(lang_picker)
	direction_picker = OptionButton.new()
	direction_picker.add_item("Language -> English")
	direction_picker.add_item("English -> Language")
	content.add_child(direction_picker)

	input = UI.line_edit("e.g. Salamat / Thank you")
	input.text_submitted.connect(func(_t): _translate())
	content.add_child(input)
	content.add_child(UI.gem_button("TRANSLATE", "purple", _translate, 80, 30))

	var result_panel := UI.panel(Color("efe0ff"), Color("8a63c2"))
	var rv := UI.vbox(6)
	result_panel.add_child(rv)
	result_label = UI.label("...", 28, Color("5a3591"), true, UI.font_body_black)
	rv.add_child(result_label)
	source_label = UI.label("", 15, UI.INK_SOFT, true)
	rv.add_child(source_label)
	matches_box = UI.vbox(4)
	rv.add_child(matches_box)
	content.add_child(result_panel)

	server_label = UI.label("Checking for the MarianNMT translator...", 15, UI.INK_SOFT, true)
	content.add_child(server_label)
	content.add_child(UI.heading("Grammar tips", UI.RED, 24))
	tips_box = UI.vbox(6)
	content.add_child(tips_box)
	_show_tips()
	_check_server()


func _current_lang() -> String:
	return lang_codes[lang_picker.selected] if not lang_codes.is_empty() else ""


func _check_server() -> void:
	var ok: bool = await Spirit.check_server()
	if not is_inside_tree():
		return
	if ok:
		server_label.text = "MarianNMT translator connected (%s)." % ", ".join(Spirit.server_pairs)
	else:
		server_label.text = "MarianNMT translator not running: using the built-in dictionary."


func _show_tips() -> void:
	for c in tips_box.get_children():
		c.queue_free()
	for t in DB.get_tips(_current_lang()):
		tips_box.add_child(UI.label("• " + t.tip, 18, UI.INK, true))


func _translate() -> void:
	var direction := "to_english" if direction_picker.selected == 0 else "from_english"
	result_label.text = "..."
	source_label.text = ""
	var res: Dictionary = await Spirit.translate(_current_lang(), input.text, direction)
	if not is_inside_tree():
		return
	result_label.text = res.text if res.text != "" else "(no translation found)"
	source_label.text = Spirit.source_label(res.source)
	for c in matches_box.get_children():
		c.queue_free()
	for m in res.matches.slice(0, 5):
		var line := "%s = %s" % [m.native, m.english]
		if str(m.get("note", "")) != "":
			line += "  (%s)" % m.note
		matches_box.add_child(UI.label(line, 17, UI.INK, true))
