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
var grammar_input: LineEdit
var grammar_box: VBoxContainer


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

	var say := UI.pill_button("PRONOUNCE", Color("6b3fa0"), _pronounce, 52, 18)
	say.name = "pronounce"
	content.add_child(say)

	content.add_child(UI.heading("Grammar checker", UI.RED, 24))
	content.add_child(UI.label("Write a sentence in the language above. I compare it with the sentences I know and tell you what to fix.", 16, UI.INK_SOFT, true))
	grammar_input = UI.line_edit("e.g. Gusto ko ng tubig")
	grammar_input.text_submitted.connect(func(_t): _check_grammar())
	content.add_child(grammar_input)
	content.add_child(UI.gem_button("CHECK GRAMMAR", "green", _check_grammar, 80, 28))
	grammar_box = UI.vbox(4)
	grammar_box.name = "grammar_result"
	content.add_child(grammar_box)

	server_label = UI.label("Checking for the MarianNMT translator...", 15, UI.INK_SOFT, true)
	content.add_child(server_label)
	content.add_child(UI.heading("Grammar tips", UI.RED, 24))
	tips_box = UI.vbox(6)
	content.add_child(tips_box)
	_show_tips()
	_check_server()
	GuidePages.maybe_show(self, "spirit")

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


## Pronunciation of the translation (or of what was typed, when it is in the language).
func _pronounce() -> void:
	var text := result_label.text if direction_picker.selected == 1 else input.text
	if text.strip_edges() == "" or text.begins_with("(") or text == "...":
		text = input.text
	var region: String = DB.get_language(_current_lang()).get("region_code", "luzon")
	Pronounce.show_panel(self, [text] if text.strip_edges() != "" else [], _current_lang(), region)


func _check_grammar() -> void:
	for c in grammar_box.get_children():
		grammar_box.remove_child(c)
		c.queue_free()
	var r := GrammarChecker.check_free(grammar_input.text, DB.get_sentences(_current_lang()), DB.get_tips(_current_lang()))
	if r.ok:
		grammar_box.add_child(UI.label("Correct! \"%s\" means \"%s\"." % [r.match.native, r.match.english], 20, UI.GREEN, true, UI.font_body_black))
	elif r.get("known", false):
		grammar_box.add_child(UI.label("Did you mean: %s (\"%s\")?" % [r.match.native, r.match.english], 19, UI.INK, true, UI.font_body_black))
	for line in r.issues + r.notes:
		grammar_box.add_child(UI.label("• " + line, 18, UI.RED if not r.ok else UI.INK_SOFT, true))
